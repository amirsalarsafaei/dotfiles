import http.client
import json
import os
import random
import re
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
DECK_FILE = CACHE_DIR / "deck.json"
LYRICS_CACHE_DIR = Path(os.environ.get("QUIP_LYRICS_CACHE_DIR", CACHE_DIR.parent / "lyrics"))
AGENDA_FILE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "agenda-os/today.json"
NOTES_DIR = Path(os.environ.get("QUIP_NOTES_DIR", HOME / "Documents/amirsalar-vault/daily notes"))
NAME = os.environ.get("QUIP_NAME") or os.environ.get("USER", "").capitalize()
PROVIDERS = os.environ.get("QUIP_PROVIDERS", "anthropic deepseek").split()
ANTHROPIC_MODEL = os.environ.get("QUIP_ANTHROPIC_MODEL", "claude-opus-5")
DEEPSEEK_MODEL = os.environ.get("QUIP_DEEPSEEK_MODEL", "deepseek-flash")
DEEPSEEK_EFFORT = os.environ.get("QUIP_DEEPSEEK_EFFORT", "low")
KEY_FILES = {
    "anthropic": os.environ.get("QUIP_ANTHROPIC_KEY_FILE"),
    "deepseek": os.environ.get("QUIP_DEEPSEEK_KEY_FILE"),
}
SHARE_TITLES = os.environ.get("QUIP_SHARE_TITLES") == "1"
SHARE_SONGS = os.environ.get("QUIP_SHARE_SONGS", "1") == "1"
TIMEZONE = os.environ.get("QUIP_TIMEZONE")
PERSONA = [line.strip() for line in os.environ.get("QUIP_PERSONA", "").splitlines() if line.strip()]
ABOUT = os.environ.get("QUIP_ABOUT", "").strip()
MIN_AGE = int(os.environ.get("QUIP_MIN_AGE", "10800"))
MAX_LENGTH = 110
HISTORY_SIZE = 60
PROMPT_HISTORY = 12
RECENT_SONGS = 8
REQUEST_TIMEOUT = 180
ATTEMPTS = 2
RETRY_DELAY = 20
TODAY_CARD = "@today"
SONGS_CARD = "@songs"

OPEN_TASK = re.compile(r"^\s*-\s+\[ \]\s+(\S.*)$")
DONE_TASK = re.compile(r"^\s*-\s+\[[xX]\]\s+\S")
SONG_NOISE = [
    re.compile(r"\s+-\s+.*$"),
    re.compile(r"\s*[(\[][^)\]]*[)\]]"),
]

SYSTEM = f"""You write the one line that greets {NAME} on the lock screen and wallpaper, in place of a generic "Good afternoon, {NAME}". It stays up for hours, sometimes a day, so it must still be true tomorrow.

The goal is a line {NAME} laughs at out loud or screenshots for a friend. Work like a comedy writer: draft several candidates in different formats, cut every one that matches a failure below, and output the funniest survivor.

Each request gives one angle: a single true fact about {NAME}, or a snapshot of today's checklist or music. Build the joke on that angle alone.

What lands:
- One concrete, recognisable observation drawn from the angle, with the twist in the last few words.
- Exaggerating the fact is fine; inventing people, events, numbers, habits, opinions or personality traits is not. The facts given are all that is known about {NAME}.
- A roast or an earned brag; teasing and quiet respect both work.
- Address {NAME} as "you" or by name.
- Plain words that read instantly. If the joke needs decoding, it has failed.
- Deadpan and understatement in the dry spirit of Knuth, Dijkstra and Brooks. Short beats long.
- Formats to mix: a plain deadpan sentence, a git commit subject, a Nix or compiler warning, a man page line, a changelog entry, a fortune(6) one-liner, a remixed Persian proverb or Hafez line in English. A technical format works only when its content is itself funny and true to {NAME}.

What fails, and must be cut:
- Gluing the angle to an unrelated topic, and metaphor mash-ups such as "X is just Y" or "X is not Y, it is Z".
- Fortune-cookie lines that sound deep and mean nothing, and reciting the fact back.
- Lines built on "Somewhere...", "Your X has more/fewer Y than Z", or "even your X needs a Y".
- First person, questions, motivational sincerity, meanness, puns that only work in the model's head, explaining the joke.
- Anything that could greet any engineer.
- Anything that goes stale within the day: tonight, this morning, the clock, a song playing right now, a meeting in progress, minutes until an event.
- Claiming something is empty, missing or unwritten unless the angle says so.
- The joke, target or sentence shape of any recently shown line. Never start with the weekday.

The quality bar, for calibration only; never reuse these lines or their jokes:
- Your setup is 94% finished. It has been 94% finished since March.
- If your agents ever all agree, one of them is lying.
- Legend says you once closed a tab on purpose.
- chore: rice the bar again (no functional changes, as usual)

Output only the final line, at most {MAX_LENGTH - 20} characters: no quotes, no preamble, no label, at most one emoji."""


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


def angle(card, now):
    if card == TODAY_CARD:
        context = [*agenda_context(now), *note_context(now)]
        return [f"It is {now.strftime('%A')}.", *context] if context else []
    if card == SONGS_CARD:
        return songs_context()
    return [card]


def pick_angle(now, deck):
    cards = [*PERSONA, TODAY_CARD, SONGS_CARD]
    for candidates in ([card for card in deck if card in cards], random.sample(cards, len(cards))):
        for index, card in enumerate(candidates):
            lines = angle(card, now)
            if lines:
                return lines, candidates[index + 1 :]
    return [], []


def build_prompt(lines, history):
    prompt = f"Background on {NAME}, not the topic: {ABOUT}\n\n" if ABOUT else ""
    prompt += "Angle:\n" + "\n".join(f"- {line}" for line in lines or [f"{NAME} is at the computer."])
    if history:
        prompt += "\n\nRecent lines; do not reuse their joke, target or shape:\n" + "\n".join(
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
            "thinking": {"type": "enabled"},
            "reasoning_effort": DEEPSEEK_EFFORT,
            "max_tokens": 8000,
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
            print(f"quip: {provider} skipped: no readable key at {KEY_FILES.get(provider)}", file=sys.stderr)
            continue
        for attempt in range(ATTEMPTS):
            if attempt:
                time.sleep(RETRY_DELAY)
            try:
                text = ask(key, prompt)
            except (
                anthropic.APIError,
                http.client.HTTPException,
                urllib.error.URLError,
                OSError,
                KeyError,
                IndexError,
                ValueError,
            ) as error:
                print(f"quip: {provider} failed: {error!r}", file=sys.stderr)
                continue
            line = clean(text)
            if line:
                return provider, line
            print(f"quip: {provider} reply rejected: {text!r}", file=sys.stderr)
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
    deck = read_json(DECK_FILE, [])
    lines, deck = pick_angle(now, deck if isinstance(deck, list) else [])
    provider, line = generate(build_prompt(lines, history[-PROMPT_HISTORY:]))
    if not line:
        return 1
    write_json(DECK_FILE, deck)
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
