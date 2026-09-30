import hashlib
import json
import math
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image


HOME = Path.home()
STATE_DIR = Path(os.environ["XDG_RUNTIME_DIR"]) / os.environ.get("MOOD_STATE_DIR", "mood")
PALETTE_FILE = STATE_DIR / "palette.json"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "mood"
PLAYERCTL = os.environ.get("MOOD_PLAYERCTL", "playerctl")
REQUEST_TIMEOUT = 10
MIN_PIXEL_CHROMA = 0.04
MIN_PROPORTION = 0.01
HUE_BINS = 36
HUE_WINDOW = 1
ACCENT_LIGHTNESS = 0.76
MIN_ACCENT_CHROMA = 0.08
MAX_ACCENT_CHROMA = 0.17
BANNED_HUES = ((90, 135, 75, 150), (290, 335, 262, 355))
SEPARATOR = "\x1f"
MEMO_SIZE = 64


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".new")
    temporary.write_text(json.dumps(value, ensure_ascii=False) + "\n")
    temporary.replace(path)


def fetch_art(url):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme == "file":
        path = Path(urllib.parse.unquote(parsed.path))
        return path if path.is_file() else None
    if parsed.scheme not in ("http", "https"):
        return None
    target = CACHE_DIR / hashlib.sha1(url.encode()).hexdigest()
    if target.is_file():
        return target
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "moodd/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:
            data = response.read()
    except OSError:
        return None
    temporary = target.with_suffix(".new")
    temporary.write_bytes(data)
    temporary.replace(target)
    return target


def srgb_to_linear(channel):
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def linear_to_srgb(channel):
    return channel * 12.92 if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055


def rgb_to_oklch(red, green, blue):
    red, green, blue = (srgb_to_linear(channel / 255) for channel in (red, green, blue))
    long = (0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue) ** (1 / 3)
    medium = (0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue) ** (1 / 3)
    short = (0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue) ** (1 / 3)
    lightness = 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short
    a = 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short
    b = 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
    return lightness, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def oklch_to_rgb(lightness, chroma, hue):
    a = chroma * math.cos(math.radians(hue))
    b = chroma * math.sin(math.radians(hue))
    long = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3
    medium = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3
    short = (lightness - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (
        4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short,
        -1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short,
        -0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short,
    )


def hue_distance(a, b):
    delta = abs(a - b) % 360
    return min(delta, 360 - delta)


def allowed_hue(hue):
    for low, high, below, above in BANNED_HUES:
        if low <= hue <= high:
            return below if hue < (low + high) / 2 else above
    return hue


def tune(hue, chroma, lightness=ACCENT_LIGHTNESS):
    hue = allowed_hue(hue)
    chroma = min(max(chroma, MIN_ACCENT_CHROMA), MAX_ACCENT_CHROMA)
    while True:
        rgb = oklch_to_rgb(lightness, chroma, hue)
        if all(-0.0001 <= channel <= 1.0001 for channel in rgb) or chroma <= 0:
            break
        chroma -= 0.005
    red, green, blue = (round(min(max(linear_to_srgb(max(channel, 0)), 0), 1) * 255) for channel in rgb)
    return "#{:02x}{:02x}{:02x}".format(red, green, blue)


def extract(path):
    with Image.open(path) as source:
        source.draft("RGB", (128, 128))
        image = source.convert("RGB")
    image.thumbnail((64, 64))
    image = image.point(lambda value: value & 0xF8)
    colors = image.getcolors(64 * 64) or []
    pixels = [(count, *rgb_to_oklch(*rgb)) for count, rgb in colors]
    total = sum(count for count, *_ in pixels) or 1
    bins = [[0, 0.0, 0.0, 0.0, 0.0] for _ in range(HUE_BINS)]
    width = 360 / HUE_BINS
    for count, lightness, chroma, hue in pixels:
        if chroma < MIN_PIXEL_CHROMA or not 0.12 <= lightness <= 0.97:
            continue
        entry = bins[int(hue // width) % HUE_BINS]
        entry[0] += count
        entry[1] += count * chroma * math.cos(math.radians(hue))
        entry[2] += count * chroma * math.sin(math.radians(hue))
        entry[3] += count * chroma
        entry[4] += count * lightness
    swatches = []
    for index, (count, a, b, chroma, lightness) in enumerate(bins):
        if count == 0:
            continue
        spread = sum(bins[(index + offset) % HUE_BINS][0] for offset in range(-HUE_WINDOW, HUE_WINDOW + 1))
        proportion = spread / total
        if proportion < MIN_PROPORTION:
            continue
        chroma /= count
        swatches.append(
            {
                "hue": math.degrees(math.atan2(b, a)) % 360,
                "chroma": chroma,
                "lightness": lightness / count,
                "score": proportion * 0.7 + (chroma - 0.1) * (2.5 if chroma >= 0.1 else 0.5),
            }
        )
    if not swatches:
        return None
    swatches.sort(key=lambda swatch: swatch["score"], reverse=True)
    first = swatches[0]
    second = None
    for separation in (90, 60, 45, 30):
        second = next((swatch for swatch in swatches[1:] if hue_distance(swatch["hue"], first["hue"]) >= separation), None)
        if second is not None:
            break
    primary = tune(first["hue"], first["chroma"])
    if second is None:
        return {"primary": primary, "secondary": tune(first["hue"], first["chroma"] * 0.6, ACCENT_LIGHTNESS - 0.1)}
    return {"primary": primary, "secondary": tune(second["hue"], second["chroma"], ACCENT_LIGHTNESS - 0.04)}


class Mood:
    def __init__(self):
        self.art = None
        self.colors = None
        self.published = None
        self.memo = {}

    def publish(self, active):
        colors = self.colors if active else None
        payload = {
            "active": colors is not None,
            "primary": colors["primary"] if colors else None,
            "secondary": colors["secondary"] if colors else None,
            "art": self.art if colors else None,
        }
        if payload == self.published:
            return
        self.published = payload
        write_json(PALETTE_FILE, payload)

    def update(self, status, art):
        if art != self.art:
            self.art = art
            self.colors = None
            if art in self.memo:
                self.colors = self.memo[art]
            elif art:
                path = fetch_art(art)
                if path is not None:
                    try:
                        self.colors = extract(path)
                    except OSError:
                        self.colors = None
                    if len(self.memo) >= MEMO_SIZE:
                        self.memo.pop(next(iter(self.memo)))
                    self.memo[art] = self.colors
        self.publish(status in ("Playing", "Paused"))


def main():
    mood = Mood()
    mood.publish(False)
    command = [
        PLAYERCTL,
        "--player=playerctld",
        "--follow",
        "metadata",
        "--format",
        "{{status}}" + SEPARATOR + "{{mpris:artUrl}}",
    ]
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True) as process:
        for line in process.stdout:
            status, _, art = line.rstrip("\n").partition(SEPARATOR)
            mood.update(status.strip(), art.strip() or None)
    mood.art = None
    mood.publish(False)
    return process.returncode or 1


if __name__ == "__main__":
    sys.exit(main())
