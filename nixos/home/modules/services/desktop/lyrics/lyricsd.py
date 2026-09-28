import asyncio
import hashlib
import json
import os
import re
import signal
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from dbus_next import BusType, Message, MessageType, Variant
from dbus_next.aio import MessageBus


HOME = Path.home()
STATE_DIR = Path(os.environ["XDG_RUNTIME_DIR"]) / os.environ.get("LYRICS_STATE_DIR", "lyrics")
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "lyrics"
TRACK_FILE = STATE_DIR / "track.json"
LINE_FILE = STATE_DIR / "line.json"
WAYBAR_SIGNAL = int(os.environ.get("LYRICS_WAYBAR_SIGNAL", "10"))
WAYBAR_NAMES = {"waybar", ".waybar-wrapped"}
LEAD = float(os.environ.get("LYRICS_LEAD", "0.3"))

API = "https://lrclib.net/api/"
CLIENT = "lyricsd/1.0"
REQUEST_TIMEOUT = 10
MIN_GAP = 2.0
BACKOFF_START = 30.0
BACKOFF_MAX = 600.0
DEBOUNCE = 1.5
MISSING_TTL = 7 * 86400

DBUS = "org.freedesktop.DBus"
PROPERTIES = "org.freedesktop.DBus.Properties"
MPRIS_PATH = "/org/mpris/MediaPlayer2"
MPRIS_PREFIX = "org.mpris.MediaPlayer2."
PLAYER = "org.mpris.MediaPlayer2.Player"
IGNORED = {"org.mpris.MediaPlayer2.playerctld"}
DRIFT_CHECK = 5.0
CALL_TIMEOUT = 2.0

STAMP = re.compile(r"^\[(\d+):(\d+(?:\.\d+)?)\]")
LOOSE = [
    re.compile(r"\s+-\s+.*$"),
    re.compile(r"\s*[(\[](feat|with|ft)\.?[^)\]]*[)\]]", re.IGNORECASE),
]


class Offline(Exception):
    pass


class RateLimited(Exception):
    def __init__(self, retry_after):
        super().__init__(retry_after)
        self.retry_after = retry_after


def plain(value):
    if isinstance(value, Variant):
        return plain(value.value)
    if isinstance(value, dict):
        return {key: plain(item) for key, item in value.items()}
    if isinstance(value, list):
        return [plain(item) for item in value]
    return value


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".new")
    temporary.write_text(json.dumps(value, ensure_ascii=False) + "\n")
    temporary.replace(path)


def signal_waybar():
    number = signal.SIGRTMIN + WAYBAR_SIGNAL
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if (entry / "comm").read_text().strip() in WAYBAR_NAMES:
                os.kill(int(entry.name), number)
        except (OSError, ValueError):
            continue


def parse(text):
    lines = []
    for raw in text.splitlines():
        times = []
        match = STAMP.match(raw)
        while match:
            times.append(int(match.group(1)) * 60 + float(match.group(2)))
            raw = raw[match.end():]
            match = STAMP.match(raw)
        words = raw.strip() or "♪"
        lines.extend([stamp, words] for stamp in times)
    return sorted(lines, key=lambda line: line[0])


def request(endpoint, params):
    query = urllib.parse.urlencode({key: value for key, value in params.items() if value})
    message = urllib.request.Request(
        API + endpoint + "?" + query,
        headers={"Lrclib-Client": CLIENT, "User-Agent": CLIENT},
    )
    try:
        with urllib.request.urlopen(message, timeout=REQUEST_TIMEOUT) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code in (400, 404):
            return None
        if error.code == 429:
            try:
                retry_after = float(error.headers.get("Retry-After") or 0)
            except ValueError:
                retry_after = 0.0
            raise RateLimited(retry_after) from error
        raise Offline(str(error)) from error
    except (OSError, ValueError) as error:
        raise Offline(str(error)) from error


def pick(results, length):
    if not isinstance(results, list):
        return None
    synced = [entry for entry in results if entry.get("syncedLyrics")]
    close = [entry for entry in synced if length <= 0 or abs((entry.get("duration") or 0) - length) <= 4]
    return (close or synced or [None])[0]


def loose_title(title):
    for pattern in LOOSE:
        title = pattern.sub("", title)
    return title.strip()


def lookup(track):
    length = round(track["length"])
    entry = request(
        "get",
        {
            "track_name": track["title"],
            "artist_name": track["artist"],
            "album_name": track["album"],
            "duration": str(length) if length > 0 else "",
        },
    )
    if not (entry and entry.get("syncedLyrics")):
        time.sleep(MIN_GAP)
        found = pick(request("search", {"track_name": loose_title(track["title"]), "artist_name": track["artist"]}), length)
        entry = found or entry
    synced = parse(entry.get("syncedLyrics") or "") if entry else []
    plain_text = (entry.get("plainLyrics") or "") if entry else ""
    return {
        "status": "found" if synced or plain_text else "missing",
        "synced": synced,
        "plain": plain_text,
        "fetched": time.time(),
    }


def cache_path(key):
    return CACHE_DIR / (hashlib.sha1(key.encode()).hexdigest() + ".json")


def cache_read(key):
    try:
        entry = json.loads(cache_path(key).read_text())
    except (OSError, ValueError):
        return None
    if entry.get("key") != key:
        return None
    if entry.get("status") == "missing" and time.time() - entry.get("fetched", 0) > MISSING_TTL:
        return None
    return entry


def cache_write(key, entry):
    write_json(cache_path(key), dict(entry, key=key))


class Player:
    def __init__(self, name, owner):
        self.name = name
        self.owner = owner
        self.status = "Stopped"
        self.metadata = {}
        self.rate = 1.0
        self.anchor = 0.0
        self.anchored_at = time.monotonic()
        self.checked_at = 0.0
        self.played_at = 0.0

    @property
    def playing(self):
        return self.status == "Playing"

    def position(self):
        if not self.playing:
            return self.anchor
        return self.anchor + (time.monotonic() - self.anchored_at) * self.rate

    def anchor_to(self, microseconds):
        self.anchor = microseconds / 1e6
        self.anchored_at = time.monotonic()
        self.checked_at = self.anchored_at

    def track(self):
        title = str(self.metadata.get("xesam:title") or "")
        if not title:
            return None
        artist = self.metadata.get("xesam:artist") or []
        if isinstance(artist, str):
            artist = [artist]
        track = {
            "title": title,
            "artist": ", ".join(str(item) for item in artist),
            "album": str(self.metadata.get("xesam:album") or ""),
            "length": int(self.metadata.get("mpris:length") or 0) / 1e6,
        }
        track["key"] = "\x1f".join([track["title"], track["artist"], track["album"], str(round(track["length"]))])
        return track


class Daemon:
    def __init__(self, bus):
        self.bus = bus
        self.players = {}
        self.owners = {}
        self.tasks = set()
        self.wake = asyncio.Event()
        self.fetch_wanted = asyncio.Event()
        self.track = None
        self.lyrics = None
        self.fetch_due = 0.0
        self.next_request = 0.0
        self.backoff = 0.0
        self.line = None

    def spawn(self, coroutine):
        task = asyncio.get_running_loop().create_task(coroutine)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)

    async def call(self, destination, path, interface, member, signature="", body=None):
        try:
            reply = await asyncio.wait_for(
                self.bus.call(
                    Message(
                        destination=destination,
                        path=path,
                        interface=interface,
                        member=member,
                        signature=signature,
                        body=body or [],
                    )
                ),
                CALL_TIMEOUT,
            )
        except asyncio.TimeoutError:
            return None
        if reply is None or reply.message_type == MessageType.ERROR:
            return None
        return reply.body

    async def match(self, rule):
        await self.call(DBUS, "/org/freedesktop/DBus", DBUS, "AddMatch", "s", [rule])

    async def start(self):
        self.bus.add_message_handler(self.on_message)
        await self.match(f"type='signal',sender='{DBUS}',interface='{DBUS}',member='NameOwnerChanged',arg0namespace='org.mpris.MediaPlayer2'")
        await self.match(f"type='signal',interface='{PROPERTIES}',member='PropertiesChanged',path='{MPRIS_PATH}'")
        await self.match(f"type='signal',interface='{PLAYER}',member='Seeked',path='{MPRIS_PATH}'")
        names = await self.call(DBUS, "/org/freedesktop/DBus", DBUS, "ListNames")
        for name in names[0] if names else []:
            if name.startswith(MPRIS_PREFIX) and name not in IGNORED:
                owner = await self.call(DBUS, "/org/freedesktop/DBus", DBUS, "GetNameOwner", "s", [name])
                if owner:
                    await self.add_player(name, owner[0])

    async def add_player(self, name, owner):
        player = Player(name, owner)
        props = await self.call(name, MPRIS_PATH, PROPERTIES, "GetAll", "s", [PLAYER])
        if props:
            values = plain(props[0])
            player.status = values.get("PlaybackStatus", "Stopped")
            if player.playing:
                player.played_at = time.monotonic()
            player.metadata = values.get("Metadata", {})
            player.rate = float(values.get("Rate", 1.0) or 1.0)
            player.anchor_to(int(values.get("Position", 0) or 0))
        self.players[name] = player
        self.owners[owner] = name
        self.wake.set()

    def remove_player(self, name):
        player = self.players.pop(name, None)
        if player:
            self.owners.pop(player.owner, None)
        self.wake.set()

    async def refresh_position(self, player):
        reply = await self.call(player.name, MPRIS_PATH, PROPERTIES, "Get", "ss", [PLAYER, "Position"])
        if reply:
            player.anchor_to(int(plain(reply[0]) or 0))
        else:
            player.checked_at = time.monotonic()
        self.wake.set()

    def on_message(self, message):
        if message.message_type != MessageType.SIGNAL:
            return False
        if message.member == "NameOwnerChanged":
            name, old, new = message.body
            if not name.startswith(MPRIS_PREFIX) or name in IGNORED:
                return False
            if old:
                self.remove_player(name)
            if new:
                self.spawn(self.add_player(name, new))
            return False
        player = self.players.get(self.owners.get(message.sender))
        if player is None:
            return False
        if message.member == "Seeked":
            player.anchor_to(message.body[0])
            self.wake.set()
        elif message.member == "PropertiesChanged" and message.body[0] == PLAYER:
            changed = plain(message.body[1])
            current = player.position()
            if "PlaybackStatus" in changed:
                player.status = changed["PlaybackStatus"]
                if player.playing:
                    player.played_at = time.monotonic()
            if "Metadata" in changed:
                player.metadata = changed["Metadata"]
            if "Rate" in changed:
                player.rate = float(changed["Rate"] or 1.0)
            player.anchor = current
            player.anchored_at = time.monotonic()
            self.spawn(self.refresh_position(player))
            self.wake.set()
        return False

    def active(self):
        players = [player for player in self.players.values() if player.track()]
        if not players:
            return None
        return next((player for player in players if player.playing), max(players, key=lambda player: player.played_at))

    def publish_track(self):
        track = self.track
        lyrics = self.lyrics
        if track is None:
            status = "none"
        elif lyrics is None:
            status = "loading"
        else:
            status = lyrics["status"]
        if lyrics and lyrics["synced"]:
            lines = [{"time": stamp, "text": text} for stamp, text in lyrics["synced"]]
        elif lyrics and lyrics["plain"]:
            lines = [{"time": 0, "text": text.strip() or " "} for text in lyrics["plain"].splitlines()]
        else:
            lines = []
        write_json(
            TRACK_FILE,
            {
                "status": status,
                "title": track["title"] if track else "",
                "artist": track["artist"] if track else "",
                "album": track["album"] if track else "",
                "synced": bool(lyrics and lyrics["synced"]),
                "lead": LEAD,
                "lines": lines,
            },
        )

    def publish_line(self, text, tooltip):
        line = {"text": text, "tooltip": tooltip, "class": "playing" if text else "idle"}
        if line == self.line:
            return
        self.line = line
        write_json(LINE_FILE, line)
        signal_waybar()

    def on_track(self, track):
        self.track = track
        self.lyrics = cache_read(track["key"]) if track else None
        self.publish_track()
        if track and self.lyrics is None:
            self.fetch_due = time.monotonic() + DEBOUNCE
            self.fetch_wanted.set()

    async def sync_loop(self):
        first = True
        while True:
            player = self.active()
            track = player.track() if player else None
            if first or (track or {}).get("key") != (self.track or {}).get("key"):
                first = False
                self.on_track(track)
            timeout = None
            synced = self.lyrics["synced"] if self.lyrics else []
            if player and player.playing and synced:
                if time.monotonic() - player.checked_at >= DRIFT_CHECK:
                    await self.refresh_position(player)
                position = player.position() + LEAD
                upcoming = [stamp for stamp, _ in synced if stamp > position]
                text = next((words for stamp, words in reversed(synced) if stamp <= position), "♪")
                self.publish_line(text, track["title"] + " — " + track["artist"])
                until_line = (upcoming[0] - position) / max(player.rate, 0.01) + 0.02 if upcoming else DRIFT_CHECK
                until_check = DRIFT_CHECK - (time.monotonic() - player.checked_at)
                timeout = max(0.02, min(until_line, until_check))
            else:
                self.publish_line("", "")
            try:
                await asyncio.wait_for(self.wake.wait(), timeout)
            except asyncio.TimeoutError:
                pass
            self.wake.clear()

    async def fetch_loop(self):
        while True:
            await self.fetch_wanted.wait()
            track = self.track
            if track is None or self.lyrics is not None:
                self.fetch_wanted.clear()
                continue
            delay = max(self.fetch_due, self.next_request) - time.monotonic()
            if delay > 0:
                await asyncio.sleep(delay)
                continue
            try:
                result = await asyncio.to_thread(lookup, track)
            except (Offline, RateLimited) as error:
                self.backoff = min(max(BACKOFF_START, self.backoff * 2), BACKOFF_MAX)
                wait = max(self.backoff, getattr(error, "retry_after", 0.0))
                self.next_request = time.monotonic() + wait
                print(f"lyrics lookup failed ({error!r}), retrying in {wait:.0f}s", flush=True)
                continue
            self.backoff = 0.0
            self.next_request = time.monotonic() + MIN_GAP
            cache_write(track["key"], result)
            if self.track and self.track["key"] == track["key"]:
                self.lyrics = result
                self.publish_track()
                self.wake.set()


def cleanup():
    for path in (TRACK_FILE, LINE_FILE):
        try:
            path.unlink()
        except OSError:
            pass
    signal_waybar()


async def main():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    daemon = Daemon(bus)
    await daemon.start()
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for number in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(number, stop.set)
    workers = [loop.create_task(daemon.sync_loop()), loop.create_task(daemon.fetch_loop())]
    await stop.wait()
    for worker in workers:
        worker.cancel()
    cleanup()


asyncio.run(main())
