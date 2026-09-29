import json
import os
import random
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import anthropic


HOME = Path.home()
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "quip"
CURRENT_FILE = CACHE_DIR / "current.json"
HISTORY_FILE = CACHE_DIR / "history.json"
LYRICS_CACHE_DIR = Path(os.environ.get("QUIP_LYRICS_CACHE_DIR", CACHE_DIR.parent / "lyrics"))
AGENDA_FILE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "agenda-os/today.json"
NOTES_DIR = Path(os.environ.get("QUIP_NOTES_DIR", HOME / "Documents/amirsalar-vault/daily notes"))
NAME = os.environ.get("QUIP_NAME") or os.environ.get("USER", "").capitalize()
PROVIDERS = os.environ.get("QUIP_PROVIDERS", "anthropic deepseek").split()
ANTHROPIC_MODEL = os.environ.get("QUIP_ANTHROPIC_MODEL", "claude-opus-5")
DEEPSEEK_MODEL = os.environ.get("QUIP_DEEPSEEK_MODEL", "deepseek-chat")
KEY_FILES = {
    "anthropic": os.environ.get("QUIP_ANTHROPIC_KEY_FILE"),
    "deepseek": os.environ.get("QUIP_DEEPSEEK_KEY_FILE"),
}
SHARE_TITLES = os.environ.get("QUIP_SHARE_TITLES") == "1"
SHARE_SONGS = os.environ.get("QUIP_SHARE_SONGS", "1") == "1"
TIMEZONE = os.environ.get("QUIP_TIMEZONE")
PERSONA = [line.strip() for line in os.environ.get("QUIP_PERSONA", "").splitlines() if line.strip()]
PLAYERCTL = os.environ.get("QUIP_PLAYERCTL", "playerctl")
MIN_AGE = int(os.environ.get("QUIP_MIN_AGE", "3600"))
MAX_LENGTH = 110
HISTORY_SIZE = 60
PROMPT_HISTORY = 25
RECENT_SONGS = 15
REQUEST_TIMEOUT = 40

OPEN_TASK = re.compile(r"^\s*-\s+\[ \]\s+(\S.*)$")
DONE_TASK = re.compile(r"^\s*-\s+\[[xX]\]\s+\S")
SONG_NOISE = [
    re.compile(r"\s+-\s+.*$"),
    re.compile(r"\s*[(\[][^)\]]*[)\]]"),
]

ANGLES = [
    "a fake Nix evaluation error or warning",
    "a git commit message, subject line only",
    "a Knuth, Dijkstra or Brooks style aphorism",
    "a Persian proverb or a Hafez fal omen, remixed and rendered in English",
    "a one-line changelog entry or bug report about {name}'s life",
    "a --help or man page line for a command that does not exist yet",
    "a fortune(6) style one-liner",
    "an auth error or a ledger that refuses to balance",
    "a race condition, deadlock or scheduler log line",
    "a plain deadpan sentence with no tech jargon",
    "a mock compiler or linter diagnostic",
]
SONG_ANCHOR = "the songs in the recent queue and the mood swings between them."

SYSTEM = f"""You write the single line of text that greets {NAME} on the desktop lock screen and dashboard, in place of a generic "Good afternoon, {NAME}".

Write one short line, at most {MAX_LENGTH - 20} characters: a genuinely funny joke, a dry observation, or a playful jab. Make it personal: the line must hinge on something specific to {NAME} from the facts or songs you are given, and a line that could greet any engineer has failed. Speak to {NAME} as "you" or by name, never as {NAME} in the first person. Invent nothing about {NAME}'s life, job, people or belongings beyond what the prompt states. The line must make literal sense on a first read; if the joke needs decoding, pick a simpler one. Be clever rather than cheesy, warm rather than mean, and never motivational-poster sincere.

The context lists only signals that actually exist right now (time, calendar, daily note, music); anything not listed is simply unknown, so never joke about something being empty, missing or unwritten. Use a context line only when it makes the joke better.

Output only the line itself: no quotes, no preamble, no hashtags, at most one emoji."""

SYSTEM += f"""

Aim for the line {NAME} screenshots and sends to a friend. Vary the format, topic and rhythm from one line to the next, and never lean on the same signal (meetings, the time of day, the same fact) as the recent lines did. Wordplay, callbacks to the songs, and well-placed deadpan beat explaining the joke. Never start with the weekday or the clock time.

The line is cached and stays on screen for at least an hour, often up to four, so it must still be true and funny long after it is written. Never mention transient state that is likely to change within the hour: the exact clock time, the song playing right now, a meeting in progress, minutes until the next event. Treat those signals only as hints about the day's overall shape, such as a busy afternoon or a music mood, and write about the durable pattern instead."""


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


def part_of_day(hour):
    if hour < 5:
        return "late night"
    if hour < 12:
        return "morning"
    if hour < 17:
        return "afternoon"
    if hour < 21:
        return "evening"
    return "night"


def minutes(value):
    hours, mins = value.split(":")[:2]
    return int(hours) * 60 + int(mins)


def agenda_context(now):
    data = read_json(AGENDA_FILE, {})
    if data.get("date") != now.date().isoformat():
        return []
    current = now.hour * 60 + now.minute
    events = data.get("events") or []
    timed = [event for event in events if event.get("start")]
    remaining = [event for event in timed if minutes(event.get("end") or event["start"]) >= current]
    tasks = data.get("tasks") or []
    if not timed and not tasks:
        return []
    lines = [f"Calendar: {len(timed)} timed events today, {len(remaining)} still ahead."] if timed else []
    ongoing = [event for event in remaining if minutes(event["start"]) <= current]
    upcoming = [event for event in remaining if minutes(event["start"]) > current]
    if ongoing:
        lines.append("A meeting is supposed to be happening right now.")
    if upcoming:
        wait = minutes(upcoming[0]["start"]) - current
        lines.append(f"Next event starts in {wait} minutes.")
    if SHARE_TITLES:
        titles = [str(event.get("title", ""))[:60] for event in remaining[:4]]
        if titles:
            lines.append("Upcoming event titles: " + "; ".join(titles))
    if tasks:
        overdue = sum(1 for task in tasks if task.get("overdue"))
        lines.append(f"Tasks due: {len(tasks)}, of which {overdue} overdue.")
    return lines


def note_context(now):
    path = NOTES_DIR / f"{now.date().isoformat()}.md"
    try:
        text = path.read_text()
    except OSError:
        return []
    open_tasks = [match.group(1).strip() for line in text.splitlines() if (match := OPEN_TASK.match(line))]
    done = sum(1 for line in text.splitlines() if DONE_TASK.match(line))
    if not open_tasks and not done:
        return []
    lines = [f"Daily note checklist: {done} done, {len(open_tasks)} open."]
    if SHARE_TITLES and open_tasks:
        lines.append("Open items: " + "; ".join(task[:60] for task in open_tasks[:4]))
    return lines


def music_context():
    try:
        result = subprocess.run(
            [PLAYERCTL, "--player=playerctld", "metadata", "--format", "{{status}}\t{{title}}\t{{artist}}"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    status, _, rest = result.stdout.strip().partition("\t")
    title, _, artist = rest.partition("\t")
    if status != "Playing" or not title:
        return []
    return [f"Now playing: {title}" + (f" by {artist}" if artist else "")]


def plain_song(title):
    for pattern in SONG_NOISE:
        title = pattern.sub("", title)
    return title.strip()


def songs_context():
    if not SHARE_SONGS:
        return []
    songs = []
    for path in LYRICS_CACHE_DIR.glob("*.json"):
        entry = read_json(path, {})
        if not isinstance(entry, dict):
            continue
        title, _, rest = str(entry.get("key", "")).partition("\x1f")
        artist = rest.partition("\x1f")[0].strip()
        title = plain_song(title)
        if title and artist:
            songs.append((float(entry.get("fetched") or 0), f"{title} by {artist}"))
    recent = list(dict.fromkeys(song for _, song in sorted(songs, reverse=True)))[:RECENT_SONGS]
    if not recent:
        return []
    return [f"Songs {NAME} played recently, newest first: " + "; ".join(recent)]


def build_prompt(now, history):
    context = [
        f"It is {now.strftime('%A')} {part_of_day(now.hour)}, {now.strftime('%H:%M')}.",
        *agenda_context(now),
        *note_context(now),
        *music_context(),
    ]
    songs = songs_context()
    context.extend(songs)
    prompt = "Context:\n" + "\n".join(f"- {line}" for line in context)
    if PERSONA:
        prompt += f"\n\nWho {NAME} is, as background (never recite it):\n" + "\n".join(f"- {line}" for line in PERSONA)
    anchors = PERSONA + ([SONG_ANCHOR] if songs else [])
    if anchors:
        prompt += f"\n\nBuild this line around: {random.choice(anchors)}"
    prompt += f"\nSuggested format, which you may ignore for a better idea: {random.choice(ANGLES).format(name=NAME)}."
    if history:
        prompt += "\n\nLines already used recently, do not repeat their joke or structure:\n" + "\n".join(
            f"- {line}" for line in history
        )
    return prompt


def read_key(provider):
    path = KEY_FILES.get(provider)
    if not path:
        return None
    try:
        return Path(path).read_text().strip() or None
    except OSError:
        return None


def ask_anthropic(key, prompt):
    client = anthropic.Anthropic(api_key=key, timeout=REQUEST_TIMEOUT, max_retries=1)
    response = client.messages.create(
        model=ANTHROPIC_MODEL,
        max_tokens=4000,
        system=SYSTEM,
        messages=[{"role": "user", "content": prompt}],
        extra_headers={"anthropic-beta": "server-side-fallback-2026-07-01"},
        extra_body={"fallbacks": "default", "output_config": {"effort": "low"}},
    )
    if response.stop_reason == "refusal":
        return None
    return "".join(block.text for block in response.content if block.type == "text")


def ask_deepseek(key, prompt):
    body = json.dumps(
        {
            "model": DEEPSEEK_MODEL,
            "messages": [
                {"role": "system", "content": SYSTEM},
                {"role": "user", "content": prompt},
            ],
            "max_tokens": 120,
            "temperature": 1.0,
        }
    ).encode()
    request = urllib.request.Request(
        "https://api.deepseek.com/chat/completions",
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:
        data = json.load(response)
    return data["choices"][0]["message"]["content"]


ASK = {"anthropic": ask_anthropic, "deepseek": ask_deepseek}


def clean(text):
    if not text:
        return None
    line = next((part.strip() for part in text.strip().splitlines() if part.strip()), "")
    line = line.strip().strip('"“”').strip()
    if not line or len(line) > MAX_LENGTH:
        return None
    return line


def generate(prompt):
    for provider in PROVIDERS:
        key = read_key(provider)
        ask = ASK.get(provider)
        if not key or not ask:
            continue
        try:
            line = clean(ask(key, prompt))
        except (anthropic.APIError, urllib.error.URLError, OSError, KeyError, IndexError, ValueError) as error:
            print(f"quip: {provider} failed: {error}", file=sys.stderr)
            continue
        if line:
            return provider, line
    return None, None


def main():
    force = "--force" in sys.argv[1:]
    now = datetime.now(ZoneInfo(TIMEZONE)) if TIMEZONE else datetime.now()
    current = read_json(CURRENT_FILE, {})
    fresh = time.time() - float(current.get("generated") or 0) < MIN_AGE
    if fresh and not force:
        return 0
    history = read_json(HISTORY_FILE, [])
    if not isinstance(history, list):
        history = []
    provider, line = generate(build_prompt(now, history[-PROMPT_HISTORY:]))
    if not line:
        return 1
    write_json(
        CURRENT_FILE,
        {
            "text": line,
            "date": now.date().isoformat(),
            "part": part_of_day(now.hour),
            "generated": time.time(),
            "provider": provider,
        },
    )
    write_json(HISTORY_FILE, (history + [line])[-HISTORY_SIZE:])
    print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
