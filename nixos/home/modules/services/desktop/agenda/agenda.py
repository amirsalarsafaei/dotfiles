import argparse
import csv
import datetime as dt
import html
import json
import os
import re
import subprocess
from pathlib import Path


HOME = Path.home()
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "agenda-os"
DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
CACHE_FILE = CACHE_DIR / "today.json"
REMINDER_FILE = CACHE_DIR / "reminders.json"
DONE_FILE = CACHE_DIR / "done.json"
DAY_FILE = CACHE_DIR / "day-notified"
GCALCLI = os.environ.get("AGENDA_GCALCLI", "gcalcli")
NOTIFY_SEND = os.environ.get("AGENDA_NOTIFY_SEND", "notify-send")
OAUTH_CLIENT = os.environ.get("AGENDA_OAUTH_CLIENT")
PKILL = os.environ.get("AGENDA_PKILL", "pkill")
TERMINAL = os.environ.get("AGENDA_TERMINAL", "ghostty")
WAYBAR_SIGNAL = 9
VAULT = HOME / "Documents/amirsalar-vault"
TASK_PATTERN = re.compile(r"^\s*-\s+\[ \]\s+(.+)$")
DATE_PATTERN = re.compile(r"(?:📅|🛫)\s*(\d{4}-\d{2}-\d{2})")
MARKER_PATTERN = re.compile(r"\s*(?:📅|🛫|➕|⏰)\s*\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2})?")


def empty_data(today):
    return {
        "date": today.isoformat(),
        "updated_at": None,
        "calendar_status": "setup",
        "calendar_error": None,
        "events": [],
        "tasks": [],
    }


def read_json(path, fallback):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return fallback


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".new")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def oauth_exists():
    return (DATA_DIR / "gcalcli/oauth").is_file()


def own_calendars():
    result = subprocess.run([GCALCLI, "--nocolor", "list"], capture_output=True, text=True, timeout=45)
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip().splitlines()
        raise OSError(message[-1] if message else "Calendar list failed")
    calendars = []
    for line in result.stdout.splitlines():
        access, _, title = line.strip().partition(" ")
        if access in ("owner", "writer") and title.strip():
            calendars.append(title.strip())
    return calendars


def fetch_events(today, previous):
    if not oauth_exists():
        return [], "setup", "Run agenda-os auth once"
    try:
        calendars = own_calendars()
    except (OSError, subprocess.TimeoutExpired) as error:
        return previous, "stale", str(error)
    if not calendars:
        return [], "ready", None
    tomorrow = today + dt.timedelta(days=1)
    command = [
        GCALCLI,
        "--nocolor",
        "agenda",
        *[f"--calendar={re.escape(name)}" for name in calendars],
        "--details=calendar",
        "--tsv",
        "--nodeclined",
        today.isoformat(),
        tomorrow.isoformat(),
    ]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=45)
    except (OSError, subprocess.TimeoutExpired) as error:
        return previous, "stale", str(error)
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip().splitlines()
        return previous, "stale", message[-1] if message else "Calendar refresh failed"
    rows = csv.DictReader(result.stdout.splitlines(), delimiter="\t")
    events = []
    for row in rows:
        if row.get("start_date") != today.isoformat():
            continue
        events.append(
            {
                "start": row.get("start_time", ""),
                "end": row.get("end_time", ""),
                "title": row.get("title", "(No title)"),
                "calendar": row.get("calendar", ""),
            }
        )
    events.sort(key=lambda event: (event["start"] != "", event["start"], event["title"].casefold()))
    return events, "ready", None


def clean_task(text):
    return MARKER_PATTERN.sub("", text).strip()


def fetch_tasks(today):
    tasks = []
    if not VAULT.is_dir():
        return tasks
    for root, directories, filenames in os.walk(VAULT):
        directories[:] = [name for name in directories if not name.startswith(".") and name != "Templates"]
        for filename in filenames:
            if not filename.endswith(".md"):
                continue
            path = Path(root) / filename
            try:
                lines = path.read_text(errors="replace").splitlines()
            except OSError:
                continue
            for number, line in enumerate(lines, 1):
                task_match = TASK_PATTERN.match(line)
                if not task_match:
                    continue
                dates = DATE_PATTERN.findall(task_match.group(1))
                if not dates:
                    continue
                task_date = min(dt.date.fromisoformat(value) for value in dates)
                if task_date > today:
                    continue
                tasks.append(
                    {
                        "title": clean_task(task_match.group(1)),
                        "date": task_date.isoformat(),
                        "overdue": task_date < today,
                        "path": str(path.relative_to(VAULT)),
                        "line": number,
                    }
                )
    tasks.sort(key=lambda task: (not task["overdue"], task["date"], task["title"].casefold()))
    return tasks


def event_key(event):
    return "|".join([event["start"], event["title"], event["calendar"]])


def done_keys(day):
    return read_json(DONE_FILE, {}).get(day.isoformat(), [])


def save_done(day, keys):
    write_json(DONE_FILE, {day.isoformat(): keys})


def data_done(data):
    return set(done_keys(dt.date.fromisoformat(data["date"])))


def event_start(today, event):
    if not event["start"]:
        return None
    return dt.datetime.combine(today, dt.time.fromisoformat(event["start"]))


def send_notification(summary, body, urgency="normal", replace="agenda"):
    command = [
        NOTIFY_SEND,
        "--app-name=Agenda",
        "--icon=x-office-calendar",
        f"--urgency={urgency}",
        "--expire-time=12000",
        "--hint",
        f"string:x-canonical-private-synchronous:{replace}",
        summary,
        body,
    ]
    return subprocess.run(command, check=False).returncode == 0


def notify_upcoming(data, today):
    if data["calendar_status"] != "ready":
        return
    now = dt.datetime.now()
    state = read_json(REMINDER_FILE, {})
    seen = set(state.get(today.isoformat(), []))
    done = data_done(data)
    changed = False
    for event in data["events"]:
        start = event_start(today, event)
        if start is None:
            continue
        minutes = int((start - now).total_seconds() // 60)
        if minutes < 0 or minutes > 15:
            continue
        key = event_key(event)
        if key in seen or key in done:
            continue
        when = "now" if minutes == 0 else f"in {minutes + 1} minutes"
        detail = event["calendar"] or "Google Calendar"
        if send_notification(
            html.escape(f"{event['title']} · {when}"),
            html.escape(detail),
            replace=f"agenda-{key}",
        ):
            seen.add(key)
            changed = True
    if changed:
        write_json(REMINDER_FILE, {today.isoformat(): sorted(seen)})


def update():
    today = dt.date.today()
    previous = read_json(CACHE_FILE, empty_data(today))
    old_events = previous.get("events", []) if previous.get("date") == today.isoformat() else []
    events, status, error = fetch_events(today, old_events)
    data = {
        "date": today.isoformat(),
        "updated_at": dt.datetime.now().isoformat(timespec="seconds"),
        "calendar_status": status,
        "calendar_error": error,
        "events": events,
        "tasks": fetch_tasks(today),
    }
    write_json(CACHE_FILE, data)
    refresh_waybar()
    return data


def remind():
    today = dt.date.today()
    data = read_json(CACHE_FILE, None)
    if data and data.get("date") == today.isoformat():
        notify_upcoming(data, today)


def refresh_waybar():
    try:
        subprocess.run([PKILL, f"-RTMIN+{WAYBAR_SIGNAL}", "waybar"], check=False, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        pass


def load_today():
    today = dt.date.today()
    data = read_json(CACHE_FILE, empty_data(today))
    if data.get("date") != today.isoformat():
        data = empty_data(today)
        data["tasks"] = fetch_tasks(today)
    if data["calendar_status"] == "setup" and oauth_exists():
        data["calendar_status"] = "loading"
    return data


def event_label(event):
    start = event["start"] or "All day"
    if event["end"] and event["start"]:
        start = f"{start}–{event['end']}"
    return f"{start}  {event['title']}"


def agenda_lines(data, limit=12):
    lines = []
    done = data_done(data)
    for event in data["events"]:
        label = event_label(event)
        lines.append(f"✓ {label}" if event_key(event) in done else label)
    for task in data["tasks"]:
        marker = "Overdue" if task["overdue"] else "Task"
        lines.append(f"{marker}  {task['title']}")
    hidden = len(lines) - limit
    if hidden > 0:
        lines = lines[:limit] + [f"…and {hidden} more"]
    return lines


def next_event(data):
    today = dt.date.today()
    now = dt.datetime.now()
    done = data_done(data)
    pending = [event for event in data["events"] if event_key(event) not in done]
    for event in pending:
        start = event_start(today, event)
        if start is None:
            continue
        end = start
        if event["end"]:
            end = dt.datetime.combine(today, dt.time.fromisoformat(event["end"]))
        if end >= now:
            return event
    return next((event for event in pending if not event["start"]), None)


def waybar():
    data = load_today()
    event = next_event(data)
    task_count = len(data["tasks"])
    status = data["calendar_status"]
    css_class = "clear"
    if status == "setup" and task_count:
        text = f"󰃭 {task_count} task{'s' if task_count != 1 else ''}"
        css_class = "tasks"
    elif status == "setup":
        text = "󰃭 Set up"
        css_class = "setup"
    elif status == "stale":
        text = "󰃭 Offline"
        css_class = "stale"
    elif status == "loading":
        text = "󰃭 Syncing"
        css_class = "stale"
    elif event:
        prefix = event["start"] or "All day"
        title = event["title"]
        if len(title) > 24:
            title = title[:23] + "…"
        text = f"󰃭 {prefix} {title}"
        css_class = "later"
        start = event_start(dt.date.today(), event)
        if start:
            seconds = (start - dt.datetime.now()).total_seconds()
            if seconds < 0:
                css_class = "now"
            elif seconds <= 900:
                css_class = "soon"
                text += f" · {int(seconds // 60) + 1}m"
            elif seconds <= 3600:
                css_class = "upcoming"
                text += f" · {int(seconds // 60) + 1}m"
    elif task_count:
        text = f"󰃭 {task_count} task{'s' if task_count != 1 else ''}"
        css_class = "overdue" if any(task["overdue"] for task in data["tasks"]) else "tasks"
    else:
        text = "󰃭 Clear"
    if event and task_count:
        text += f" · {task_count}"
    lines = agenda_lines(data)
    if not lines:
        lines = ["Nothing scheduled or due today"]
    if data.get("calendar_error") and status == "stale":
        lines.append("Calendar data may be stale")
    elif status == "setup":
        lines.append("Right-click to connect Google Calendar")
    elif event:
        lines.append("Middle-click to mark done · Right-click to refresh")
    else:
        lines.append("Right-click to refresh")
    tooltip = "<b>Today</b>\n" + "\n".join(html.escape(line) for line in lines)
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class, "status": status}, ensure_ascii=False))


def show():
    data = load_today()
    lines = agenda_lines(data, limit=8)
    if not lines:
        lines = ["Nothing scheduled or due today"]
    if data["calendar_status"] == "setup":
        lines.append("Run agenda-os auth to connect Google Calendar")
    send_notification("Today", "\n".join(html.escape(line) for line in lines), replace="agenda-overview")


def notify_day():
    data = update()
    today = dt.date.today().isoformat()
    if DAY_FILE.exists() and DAY_FILE.read_text().strip() == today:
        return
    lines = agenda_lines(data, limit=8)
    if not lines:
        lines = ["Nothing scheduled or due today"]
    if data["calendar_status"] == "setup":
        lines.append("Run agenda-os auth to connect Google Calendar")
    if send_notification("Today", "\n".join(html.escape(line) for line in lines), replace="agenda-day"):
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        DAY_FILE.write_text(today + "\n")


def mark_done():
    today = dt.date.today()
    data = load_today()
    event = next_event(data)
    if event is None:
        send_notification("Agenda", "No event left to mark done", replace="agenda-done")
        return
    keys = done_keys(today)
    keys.append(event_key(event))
    save_done(today, keys)
    refresh_waybar()
    following = next_event(data)
    body = f"Next: {event_label(following)}" if following else "Nothing else scheduled today"
    send_notification(
        html.escape(f"Done · {event['title']}"),
        html.escape(body + "\nRun agenda-os undo to restore"),
        replace="agenda-done",
    )


def undo_done():
    today = dt.date.today()
    keys = done_keys(today)
    if not keys:
        send_notification("Agenda", "Nothing to restore", replace="agenda-done")
        return
    title = keys.pop().partition("|")[2].rpartition("|")[0]
    save_done(today, keys)
    refresh_waybar()
    send_notification(html.escape(f"Restored · {title}"), "Back on today's agenda", replace="agenda-done")


def print_agenda():
    data = load_today()
    lines = agenda_lines(data, limit=1000)
    print("\n".join(lines) if lines else "Nothing scheduled or due today")


def auth():
    if not OAUTH_CLIENT:
        raise SystemExit("AGENDA_OAUTH_CLIENT is not set")
    try:
        client = json.loads(Path(OAUTH_CLIENT).read_text())["installed"]
    except (OSError, json.JSONDecodeError, KeyError) as error:
        raise SystemExit(f"Cannot read Google OAuth client from {OAUTH_CLIENT}: {error}")
    result = subprocess.run(
        [
            GCALCLI,
            f"--client-id={client['client_id']}",
            f"--client-secret={client['client_secret']}",
            "init",
        ],
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(result.returncode)
    update()


def connect():
    if oauth_exists():
        update()
        return
    os.execvp(TERMINAL, [TERMINAL, "-e", os.environ.get("AGENDA_SELF", "agenda-os"), "auth"])


def main():
    parser = argparse.ArgumentParser(prog="agenda-os")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("update")
    subparsers.add_parser("remind")
    subparsers.add_parser("waybar")
    subparsers.add_parser("show")
    subparsers.add_parser("day")
    subparsers.add_parser("print")
    subparsers.add_parser("done")
    subparsers.add_parser("undo")
    subparsers.add_parser("auth")
    subparsers.add_parser("connect")
    arguments = parser.parse_args()
    if arguments.command == "update":
        update()
    elif arguments.command == "remind":
        remind()
    elif arguments.command == "waybar":
        waybar()
    elif arguments.command == "show":
        show()
    elif arguments.command == "day":
        notify_day()
    elif arguments.command == "print":
        print_agenda()
    elif arguments.command == "done":
        mark_done()
    elif arguments.command == "undo":
        undo_done()
    elif arguments.command == "auth":
        auth()
    elif arguments.command == "connect":
        connect()


if __name__ == "__main__":
    main()
