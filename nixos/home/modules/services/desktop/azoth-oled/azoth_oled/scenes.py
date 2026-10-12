import math
import os
import random
import unicodedata
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from .hid import H, W

SEGMENTS = {
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
    "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g", " ": "",
    "A": "abcefg", "b": "cdefg", "C": "adef", "d": "bcdeg", "E": "adefg", "F": "aefg",
}

BODY = (
    "..#####..",
    ".#######.",
    "#########",
    "#########",
    "#########",
    "#########",
    ".#######.",
)

MONTHS = ("Farvardin", "Ordibehesht", "Khordad", "Tir", "Mordad", "Shahrivar",
          "Mehr", "Aban", "Azar", "Dey", "Bahman", "Esfand")


def level(value):
    return max(0, min(15, int(round(value)))) * 17


def clean(text):
    kept = "".join(ch for ch in str(text)
                   if ord(ch) < 0x100 or ch in "\u200c\u200d" or not unicodedata.category(ch).startswith(("S", "C")))
    return " ".join(kept.split())


def jalali(gy, gm, gd):
    offsets = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334)
    gy2 = gy + 1 if gm > 2 else gy
    days = 355666 + 365 * gy + (gy2 + 3) // 4 - (gy2 + 99) // 100 + (gy2 + 399) // 400 + gd + offsets[gm - 1]
    jy = -1595 + 33 * (days // 12053)
    days %= 12053
    jy += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        jy += (days - 1) // 365
        days = (days - 1) % 365
    if days < 186:
        return jy, 1 + days // 31, 1 + days % 31
    return jy, 7 + (days - 186) // 30, 1 + (days - 186) % 30


class Fonts:
    def __init__(self):
        root = Path(os.environ.get("AZOTH_FONTS", Path(__file__).parent.parent / "fonts"))
        self.small = ImageFont.load(str(root / "spleen-5x8.pil"))
        self.large = ImageFont.load(str(root / "spleen-6x12.pil"))
        fallback = os.environ.get("AZOTH_FALLBACK_FONT")
        self.fallback = {}
        if fallback and Path(fallback).exists():
            self.fallback = {"small": ImageFont.truetype(fallback, 9), "large": ImageFont.truetype(fallback, 12)}

    def pick(self, text, size):
        if any(ord(ch) > 0x7E for ch in text):
            if self.fallback:
                return self.fallback[size], True, text
            text = text.encode("ascii", "replace").decode("ascii")
        return (self.small if size == "small" else self.large), False, text


class Painter:
    def __init__(self, fonts):
        self.fonts = fonts
        self.image = Image.new("L", (W, H), 0)
        self.draw = ImageDraw.Draw(self.image)

    def rect(self, x0, y0, x1, y1, shade):
        if x1 >= x0 and y1 >= y0:
            self.draw.rectangle((x0, y0, x1, y1), fill=level(shade))

    def dot(self, x, y, shade):
        if 0 <= x < W and 0 <= y < H:
            self.image.putpixel((int(x), int(y)), level(shade))

    def block(self, x, y, shade, scale=2):
        self.rect(x, y, x + scale - 1, y + scale - 1, shade)

    def line(self, points, shade, width=1):
        self.draw.line(points, fill=level(shade), width=width)

    def circle(self, cx, cy, r, fill=None, outline=None):
        self.draw.ellipse((cx - r, cy - r, cx + r, cy + r),
                          fill=None if fill is None else level(fill),
                          outline=None if outline is None else level(outline))

    def part(self, x, y, w, h, front=3, top=4, rim=9):
        self.rect(x + 2, y + 2, x + w + 1, y + h + front + 1, 1)
        self.rect(x, y, x + w - 1, y + h - 1, top)
        self.rect(x, y + h, x + w - 1, y + h + front - 1, 2)
        self.rect(x, y, x + w - 1, y, top + 3)
        self.rect(x + w - 1, y, x + w - 1, y + h - 1, rim)
        self.dot(x + 2, y + 2, 13)
        self.dot(x + 3, y + 2, 9)
        self.dot(x + 2, y + 3, 9)

    def glass(self, x, y, w, h):
        self.rect(x, y, x + w - 1, y + h - 1, 0)
        self.rect(x, y + h - 1, x + w - 1, y + h - 1, 3)
        self.rect(x + w - 1, y, x + w - 1, y + h - 1, 2)

    def via(self, x, y):
        self.rect(x - 1, y - 1, x + 1, y + 1, 5)
        self.dot(x, y, 0)

    def digit(self, x, y, w, h, t, char, on, off=None):
        mid = y + (h - t) // 2
        boxes = {
            "a": (x + t, y, x + w - 1 - t, y + t - 1),
            "g": (x + t, mid, x + w - 1 - t, mid + t - 1),
            "d": (x + t, y + h - t, x + w - 1 - t, y + h - 1),
            "f": (x, y + t, x + t - 1, mid - 1),
            "b": (x + w - t, y + t, x + w - 1, mid - 1),
            "e": (x, mid + t, x + t - 1, y + h - t - 1),
            "c": (x + w - t, mid + t, x + w - 1, y + h - t - 1),
        }
        lit = SEGMENTS.get(char, "")
        for name, box in boxes.items():
            if name in lit:
                self.rect(*box, on)
            elif off is not None:
                self.rect(*box, off)

    def width(self, text, size="small"):
        font, _, text = self.fonts.pick(clean(text), size)
        return int(math.ceil(font.getlength(text)))

    def text(self, x, y, text, shade, size="small"):
        font, ttf, text = self.fonts.pick(clean(text), size)
        self.draw.text((x, y - (2 if ttf else 0)), text, font=font, fill=level(shade))

    def marquee(self, x, y, w, text, shade, tick, size="small", align="left"):
        font, ttf, text = self.fonts.pick(clean(text), size)
        if not text:
            return
        tw = int(math.ceil(font.getlength(text)))
        height = 14 if ttf else (12 if size == "large" else 8)
        strip = Image.new("L", (tw + 2, height + 4), 0)
        ImageDraw.Draw(strip).text((0, 0 if not ttf else -1), text, font=font, fill=level(shade))
        if tw <= w:
            offset = 0
            dx = x + (w - tw if align == "right" else (w - tw) // 2 if align == "center" else 0)
        else:
            travel = tw - w + 4
            steps = math.ceil(travel / 3)
            cycle = 8 + steps + 6
            phase = tick % cycle
            offset = 0 if phase < 8 else min(travel, (phase - 8) * 3)
            dx = x
        crop = strip.crop((offset, 0, offset + min(w, tw), strip.height))
        self.image.paste(crop, (dx, y - (2 if ttf else 0)), crop)


class Board:
    def __init__(self, topology):
        self.topology = topology
        self.fan = 0.0
        self.comet = 0.0
        self.pulses = [[], []]
        self.credit = [0.0, 0.0]
        self.random = random.Random(7)
        self.ray = None

    def step(self, m):
        if m["gpu"] >= 0.08:
            self.fan += math.radians(8 + 14 * min(1.0, m["gpu"] * 1.6))
            self.comet += 0.4 + 0.5 * m["gpu"]
        rates = [m["cpu"] * 2.5, min(2.5, math.log10(1 + (m["net"] + m["disk"]) / 4096))]
        for lane in range(2):
            self.credit[lane] += rates[lane]
            while self.credit[lane] >= 1:
                self.credit[lane] -= 1
                self.pulses[lane].append(float(self.random.randint(-14, 0)))
            speed = 10 + 6 * min(1.0, rates[lane] / 2.5)
            self.pulses[lane] = [x + speed for x in self.pulses[lane] if x + speed < W + 6][-6:]
        if self.ray is None and self.random.random() < 0.01:
            self.ray = [self.random.randrange(4), self.random.randrange(12), 0]
        elif self.ray is not None:
            self.ray[2] += 1
            if self.ray[2] > 6:
                self.ray = None

    def render(self, p, m, frame):
        for x in range(4, W, 8):
            for y in range(4, 58, 8):
                p.dot(x, y, 1)
        for points in (((58, 14), (62, 14)), ((58, 44), (60, 44), (62, 42), (70, 42)),
                       ((112, 18), (118, 18)), ((148, 30), (152, 30))):
            p.line(points, 2)
        p.via(70, 42)
        self._socket(p, m)
        self._qcode(p, m, frame)
        self._vrm(p, m, frame)
        self._dimms(p, m)
        self._fan(p, m)
        for lane, y in enumerate((60, 62)):
            p.line([(0, y), (W - 1, y)], 2)
            for head in self.pulses[lane]:
                for i, shade in enumerate((15, 11, 7, 4)):
                    p.dot(int(head) - i, y, shade)

    def _socket(self, p, m):
        x, y, w, h = 2, 2, 56, 50
        heat = max(0.0, min(1.0, (m["temp"] - 45) / 45))
        if m["temp"] >= 70:
            p.rect(x - 2, y - 2, x + w + 1, y + h + 4, 3 if m["temp"] < 85 else 5)
            p.rect(x - 1, y - 1, x + w, y + h + 3, 0)
        p.part(x, y, w, h, rim=6 + 9 * heat)
        p.glass(x + 4, y + 4, w - 8, h - 8)
        bars = []
        for group in self.topology.groups:
            bars.append(("gap", 2))
            for i, core in enumerate(group["cores"]):
                if i:
                    bars.append(("gap", 1))
                bars.append(("core", core))
        bars = [("igpu", None)] + bars
        weights = sum(2 if kind == "igpu" else (2 if item["kind"] == "p" else 1) for kind, item in bars if kind != "gap")
        gaps = sum(n for kind, n in bars if kind == "gap")
        inner = w - 12
        unit = max(1, (inner - gaps) // max(1, weights))
        total = gaps + unit * weights
        bx = x + 6 + (inner - total) // 2
        top, bottom = y + 7, y + h - 7
        span = bottom - top
        for kind, item in bars:
            if kind == "gap":
                bx += item
                continue
            if kind == "igpu":
                bw, load, lit, hatch = unit * 2, m["gpu"], 9, True
            else:
                bw = unit * (2 if item["kind"] == "p" else 1)
                load = max((m["threads"].get(c, 0.0) for c in item["cpus"]), default=0.0)
                lit, hatch = (15 if item["kind"] == "p" else 11), False
            p.rect(bx, top, bx + bw - 1, bottom, 1)
            fill = round(span * load)
            if fill:
                shade = 15 if load > 0.85 else lit
                p.rect(bx, bottom - fill + 1, bx + bw - 1, bottom, shade - 4)
                p.rect(bx, bottom - fill + 1, bx + bw - 1, bottom - fill + 1, shade)
            if hatch:
                for yy in range(top + 2, bottom, 3):
                    p.rect(bx, yy, bx + bw - 1, yy, 0)
            bx += bw

    def _qcode(self, p, m, frame):
        x, y, w, h = 64, 2, 46, 30
        p.part(x, y, w, h, front=2)
        p.glass(x + 3, y + 3, w - 6, h - 6)
        temp = int(round(m["temp"]))
        text = f"{min(99, temp):02d}" if temp > 0 else "--"
        on = 15 if temp < 90 or frame % 2 == 0 else 6
        for i, char in enumerate(text):
            p.digit(x + 6 + i * 17, y + 5, 14, 20, 3, char, on, 1)
        p.rect(x + 39, y + 5, x + 40, y + 6, 9)

    def _vrm(self, p, m, frame):
        lit = round(8 * m["cpu"])
        for i in range(8):
            cx = 64 + i * 6
            p.rect(cx, 40, cx + 3, 41, 15 if i < lit else 2)
        for i in range(4):
            cx = 64 + i * 12
            p.part(cx, 45, 9, 7, front=2, top=5, rim=8)
            p.rect(cx + 2, 47, cx + 6, 49, 3)

    def _dimms(self, p, m):
        segments = 12
        lit = round(segments * m["mem"])
        for i in range(4):
            x = 118 + i * 8
            y = 2
            p.part(x, y, 6, 51, front=2, top=3, rim=6)
            for s in range(segments):
                sy = y + 49 - 4 * (s + 1)
                hit = self.ray and self.ray[0] == i and abs(self.ray[1] - s) <= self.ray[2] // 2
                if s < lit or hit:
                    bright = 15 if hit else 8 + 5 * (s + 1) / max(1, lit)
                    p.rect(x + 1, sy, x + 4, sy + 2, bright)
                    p.rect(x + 1, sy + 2, x + 4, sy + 2, bright - 4)
                    if s == lit - 1:
                        p.rect(x + 1, sy, x + 4, sy, 15)
                else:
                    p.rect(x + 1, sy, x + 4, sy + 2, 1)

    def _fan(self, p, m):
        x, y, w, h = 152, 2, 54, 51
        gpu = m["gpu"]
        p.part(x, y, w, h, front=3, top=4, rim=10)
        cx, cy, r = x + 27, y + 26, 23
        p.circle(cx, cy, r + 1, fill=0, outline=4 + 8 * gpu)
        if gpu >= 0.08:
            for i in range(7):
                angle = self.comet - i * 0.1
                p.dot(round(cx + (r + 1) * math.cos(angle)), round(cy + (r + 1) * math.sin(angle)), 15 - i * 2)
        spinning = gpu >= 0.08
        for b in range(9):
            a = self.fan + b * 2 * math.pi / 9
            pts = [(cx + radius * math.cos(a + off), cy + radius * math.sin(a + off))
                   for radius, off in ((6, 0.0), (r - 2, 0.45), (r - 2, 0.78), (6, 0.42))]
            p.draw.polygon(pts, fill=level(6 if spinning else 4))
            p.line([(cx + 6 * math.cos(a + 0.42), cy + 6 * math.sin(a + 0.42)),
                    (cx + (r - 2) * math.cos(a + 0.78), cy + (r - 2) * math.sin(a + 0.78))], 10 if spinning else 5)
        p.circle(cx, cy, 6, fill=8, outline=11)
        p.circle(cx, cy, 2, fill=0)


class Agents:
    SHADE = {"working": 12, "planning": 11, "asking": 15, "ready": 9, "done": 6, "error": 13}

    def render(self, p, agents, frame):
        shown = agents[:6]
        n = max(1, len(shown))
        slot = W / n
        ground = 46
        for i, agent in enumerate(shown):
            cx = int(slot * (i + 0.5))
            self._critter(p, cx, ground, agent, frame + i * 3)
            name = agent["name"]
            limit = max(3, int(slot) // 5 - 1)
            if len(name) > limit:
                name = name[: limit - 1] + "…" if self._fits(p, name[: limit - 1] + "…") else name[:limit]
            shade = self.SHADE[agent["status"]]
            if agent["status"] in ("asking", "error") and frame % 2:
                shade = 7
            p.text(cx - p.width(name) // 2, 1, name, shade)
        p.rect(0, ground, W - 1, ground, 9)
        p.rect(0, ground + 1, W - 1, ground + 4, 4)
        for x in range(-12, W, 12):
            sx = x + (frame * 3) % 12
            p.rect(sx, ground + 2, sx + 5, ground + 2, 12)
        p.rect(0, ground + 5, W - 1, ground + 6, 2)
        counts = {}
        for agent in agents:
            counts[agent["status"]] = counts.get(agent["status"], 0) + 1
        parts = [f"{counts[k]} {k}" for k in ("asking", "error", "working", "planning", "ready", "done") if counts.get(k)]
        summary = "  ".join(parts[:3])
        p.text((W - p.width(summary)) // 2, 54, summary, 8)

    @staticmethod
    def _fits(p, text):
        return all(ord(ch) < 0x2000 for ch in text)

    def _critter(self, p, cx, ground, agent, frame):
        status = agent["status"]
        shade = self.SHADE[status]
        bob = 0
        if status == "working":
            bob = frame % 2
        elif status == "asking":
            bob = -3 if frame % 6 in (0, 1) else 0
        elif status == "ready":
            bob = 1 if (frame // 4) % 2 else 0
        x0 = cx - 9
        y0 = ground - 16 + bob
        if status != "asking" or bob == 0:
            for lx in (2, 6):
                p.block(x0 + lx * 2, ground - 2, shade - 3)
        for r, row in enumerate(BODY):
            for c, ch in enumerate(row):
                if ch == "#":
                    p.block(x0 + c * 2, y0 + r * 2, shade)
        p.block(x0 + 4, y0 + 2, 15, 1)
        p.block(x0 + 2, y0 + 4, 15 if shade < 15 else 10, 1)
        cheek = 7 if agent.get("realm") != "personal" else 9
        p.block(x0 + 2, y0 + 10, min(shade, cheek))
        p.block(x0 + 14, y0 + 10, min(shade, cheek))
        for ex in (4, 12):
            if status == "done":
                p.rect(x0 + ex, y0 + 8, x0 + ex + 1, y0 + 8, 0)
            elif status == "error":
                p.rect(x0 + ex, y0 + 6, x0 + ex + 1, y0 + 9, 0 if frame % 2 else 15)
            elif status == "ready" and frame % 12 == 5:
                p.rect(x0 + ex + 1, y0 + 6, x0 + ex + 2, y0 + 9, 0)
            else:
                p.rect(x0 + ex, y0 + 6, x0 + ex + 1, y0 + 9, 0)
        if status == "asking":
            p.rect(x0 + 8, y0 + 10, x0 + 9, y0 + 11, 0)
        if agent.get("realm") == "work":
            p.rect(x0 + 8, y0 + 9, x0 + 9, y0 + 9, 2)
            p.rect(x0 + 8, y0 + 10, x0 + 9, y0 + 12, 3)
        elif agent.get("realm") == "personal":
            p.rect(x0 + 2, y0 - 2, x0 + 15, y0 - 2, 7)
            p.rect(x0 - 1, y0 + 4, x0 + 1, y0 + 9, 9)
            p.rect(x0 + 16, y0 + 4, x0 + 18, y0 + 9, 9)
        if agent["breed"] == "antenna":
            p.rect(x0 + 8, y0 - 5, x0 + 9, y0 - 1, 6)
            p.block(x0 + 8, y0 - 7, 15 if status in ("working", "asking") else 8)
        elif agent["breed"] == "whale":
            flap = frame % 2 if status in ("working", "asking") else 0
            p.block(x0 + 18, y0 + 8, shade)
            p.block(x0 + 20, y0 + 6 - flap * 2, shade)
            p.block(x0 + 20, y0 + 10 + flap * 2, shade)
        if status == "working":
            p.block(x0 - 2, y0 + 8 + frame % 2 * 2, shade)
            p.block(x0 + 18, y0 + 10 - frame % 2 * 2, shade)
            for k in range(3):
                rise = (frame + k * 2) % 6
                p.block(cx - 5 + k * 4, y0 - 3 - rise * 2, 12 - rise * 2)
        elif status == "planning":
            for k in range(3):
                p.block(cx - 5 + k * 4, y0 - 5, 13 if k <= frame % 4 - 1 else 3)
        elif status == "asking":
            p.block(x0 + 18, y0 + 2 - frame % 2 * 2, shade)
            p.block(x0 + 20, y0 - frame % 2 * 2, shade)
            q = 15 if frame % 2 == 0 else 9
            for dx, dy in ((0, 0), (2, 0), (4, 0), (4, 2), (2, 4), (2, 8)):
                p.block(cx - 3 + dx, y0 - 14 + dy, q)
        elif status == "done":
            for k in range(2):
                rise = (frame + k * 3) % 6
                zx, zy = cx + 4 + k * 5 + rise, y0 - 3 - rise * 2
                p.rect(zx, zy, zx + 3, zy, 10 - rise)
                p.dot(zx + 2, zy + 1, 10 - rise)
                p.dot(zx + 1, zy + 2, 10 - rise)
                p.rect(zx, zy + 3, zx + 3, zy + 3, 10 - rise)
        elif status == "error":
            for dy in (0, 2, 4, 8):
                p.block(cx - 1, y0 - 14 + dy, 15 if frame % 2 == 0 else 6)


class Music:
    def __init__(self):
        self.spin = 0.0
        self.bars = [0.0] * 20
        self.random = random.Random(3)

    def render(self, p, music, frame, tick, levels=None):
        playing = music["playing"]
        if playing:
            self.spin += math.radians(47)
        cx, cy, r = 31, 32, 29
        p.circle(cx, cy, r, fill=2)
        for angle in (-0.9, 2.24):
            p.draw.pieslice((cx - r, cy - r, cx + r, cy + r), math.degrees(angle) - 9, math.degrees(angle) + 9, fill=level(5))
        for gr in range(13, r, 3):
            p.circle(cx, cy, gr, outline=1)
        p.circle(cx, cy, 10, fill=10)
        for k in range(2):
            a = self.spin + k * math.pi
            p.line([(cx + 3 * math.cos(a), cy + 3 * math.sin(a)), (cx + 9 * math.cos(a), cy + 9 * math.sin(a))], 4, 2)
        p.circle(cx, cy, 1, fill=0)
        tip = (47, 27) if playing else (62, 40)
        p.circle(60, 5, 3, fill=8, outline=12)
        p.line([(60, 5), tip], 7, 2)
        p.rect(tip[0] - 2, tip[1] - 1, tip[0] + 2, tip[1] + 2, 11)
        x, w = 68, W - 70
        p.marquee(x, 3, w, music["title"] or "untitled", 15, tick, size="large")
        p.marquee(x, 19, w, music["artist"], 8, tick)
        lyric = music["lyric"]
        if lyric:
            p.rect(x, 33, x + 1, 37, 6)
            p.marquee(x + 5, 31, w - 5, lyric, 13, tick)
        for i in range(len(self.bars)):
            if playing and levels:
                target = levels[i]
            elif playing:
                target = 0.2 + 0.8 * abs(math.sin(frame * 0.9 + i * 0.7)) * (0.5 + 0.5 * self.random.random()) + (0.25 if i < 5 else 0)
            else:
                target = 0.05
            self.bars[i] += (min(1.0, target) - self.bars[i]) * 0.6
            height = max(1, round(self.bars[i] * 9))
            bx = x + i * 7
            for s in range(height):
                sy = 62 - s * 2
                p.rect(bx, sy, bx + 4, sy, 15 if s == height - 1 else 7)


class Focus:
    def render(self, p, focus, frame, tick):
        now = datetime.now()
        jy, jm, jd = jalali(now.year, now.month, now.day)
        x, y, w, h = 4, 4, 38, 42
        p.rect(x + 2, y + 2, x + w + 1, y + h + 5, 1)
        p.rect(x, y, x + w - 1, y + 10, 6)
        p.rect(x, y + 11, x + w - 1, y + h - 1, 12)
        p.rect(x + w - 1, y + 11, x + w - 1, y + h - 1, 15)
        p.rect(x, y + h, x + w - 1, y + h + 3, 5)
        for rx in (x + 8, x + w - 10):
            p.rect(rx, y - 2, rx + 1, y + 2, 13)
        month = MONTHS[jm - 1]
        if p.width(month) > w - 4:
            month = month[:5]
        p.text(x + (w - p.width(month)) // 2, y + 2, month, 15)
        day = str(jd)
        glyphs = Image.new("L", (p.width(day, "large") + 1, 12), 0)
        ImageDraw.Draw(glyphs).text((0, 0), day, font=p.fonts.large, fill=255)
        glyphs = glyphs.resize((glyphs.width * 2, 24), Image.NEAREST)
        p.image.paste(0, (x + (w - glyphs.width) // 2 + 1, y + 15), glyphs)
        tx, tw = 50, W - 52
        app = focus["app"] if focus else "desktop"
        p.marquee(tx, 4, tw, app, 15, tick, size="large")
        if focus and focus["title"]:
            p.marquee(tx, 19, tw, focus["title"], 7, tick)
        workspace = focus.get("workspace") if focus else None
        p.text(tx, 42, now.strftime("%a"), 10)
        if workspace is not None:
            p.text(tx, 52, f"ws {workspace}", 6)
        clock = now.strftime("%H:%M" if now.second % 2 == 0 else "%H %M")
        glyphs = Image.new("L", (p.width(clock, "large") + 1, 12), 0)
        ImageDraw.Draw(glyphs).text((0, 0), clock, font=p.fonts.large, fill=255)
        glyphs = glyphs.resize((glyphs.width * 2, 24), Image.NEAREST)
        p.image.paste(level(15), (W - 3 - glyphs.width, 37), glyphs)
        span = glyphs.width
        filled = round(span * (now.second + now.microsecond / 1e6) / 60)
        p.rect(W - 3 - span, 62, W - 4, 62, 2)
        p.rect(W - 3 - span, 62, W - 4 - span + filled, 62, 12)
        p.dot(W - 4 - span + filled, 61, 15)
        sweep = (frame * 6) % (x + w + 40)
        for i, shade in enumerate((15, 9, 5, 2)):
            if 0 <= sweep - i * 2 < x + w:
                p.rect(sweep - i * 2, 62, sweep - i * 2 + 1, 62, shade)
