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
DAY_FILE = CACHE_DIR / "day-notified"
GCALCLI = os.environ.get("AGENDA_GCALCLI", "gcalcli")
NOTIFY_SEND = os.environ.get("AGENDA_NOTIFY_SEND", "notify-send")
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


def fetch_events(today, previous):
    if not oauth_exists():
        return [], "setup", "Run agenda-os auth once"
    tomorrow = today + dt.timedelta(days=1)
    command = [
        GCALCLI,
        "--nocolor",
        "agenda",
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
    changed = False
    for event in data["events"]:
        start = event_start(today, event)
        if start is None:
            continue
        minutes = int((start - now).total_seconds() // 60)
        if minutes < 0 or minutes > 15:
            continue
        key = "|".join([event["start"], event["title"], event["calendar"]])
        if key in seen:
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
    notify_upcoming(data, today)
    return data


def load_today():
    today = dt.date.today()
    data = read_json(CACHE_FILE, empty_data(today))
    if data.get("date") != today.isoformat():
        data = empty_data(today)
        data["tasks"] = fetch_tasks(today)
    return data


def event_label(event):
    start = event["start"] or "All day"
    if event["end"] and event["start"]:
        start = f"{start}–{event['end']}"
    return f"{start}  {event['title']}"


def agenda_lines(data, limit=12):
    lines = []
    for event in data["events"]:
        lines.append(event_label(event))
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
    for event in data["events"]:
        start = event_start(today, event)
        if start is None:
            continue
        end = start
        if event["end"]:
            end = dt.datetime.combine(today, dt.time.fromisoformat(event["end"]))
        if end >= now:
            return event
    return next((event for event in data["events"] if not event["start"]), None)


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
    elif event:
        prefix = event["start"] or "All day"
        title = event["title"]
        if len(title) > 24:
            title = title[:23] + "…"
        text = f"󰃭 {prefix} {title}"
        css_class = "busy"
        start = event_start(dt.date.today(), event)
        if start and 0 <= (start - dt.datetime.now()).total_seconds() <= 900:
            css_class = "soon"
    elif task_count:
        text = f"󰃭 {task_count} task{'s' if task_count != 1 else ''}"
        css_class = "tasks"
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
    tooltip = "<b>Today</b>\n" + "\n".join(html.escape(line) for line in lines)
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}, ensure_ascii=False))


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


def print_agenda():
    data = load_today()
    lines = agenda_lines(data, limit=1000)
    print("\n".join(lines) if lines else "Nothing scheduled or due today")


def auth(client_id):
    if not client_id:
        client_id = input("Google Desktop OAuth client ID: ").strip()
    if not client_id:
        raise SystemExit("usage: agenda-os auth GOOGLE_CLIENT_ID")
    os.execv(GCALCLI, [GCALCLI, f"--client-id={client_id}", "init"])


def main():
    parser = argparse.ArgumentParser(prog="agenda-os")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("update")
    subparsers.add_parser("waybar")
    subparsers.add_parser("show")
    subparsers.add_parser("day")
    subparsers.add_parser("print")
    auth_parser = subparsers.add_parser("auth")
    auth_parser.add_argument("client_id", nargs="?")
    arguments = parser.parse_args()
    if arguments.command == "update":
        update()
    elif arguments.command == "waybar":
        waybar()
    elif arguments.command == "show":
        show()
    elif arguments.command == "day":
        notify_day()
    elif arguments.command == "print":
        print_agenda()
    elif arguments.command == "auth":
        auth(arguments.client_id)


if __name__ == "__main__":
    main()
