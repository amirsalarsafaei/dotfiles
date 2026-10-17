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

    def box(self, x0, y0, x1, y1, shade):
        if x1 >= x0 and y1 >= y0:
            self.draw.rectangle((x0, y0, x1, y1), outline=level(shade))

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
    HISTORY = 96
    TOP = 11
    BASE = 62
    RIGHT = 146
    EDGE = 205

    def __init__(self, topology):
        self.topology = topology
        self.history = []
        self.seen = None

    def step(self, m):
        if m is not self.seen:
            self.seen = m
            self.history = (self.history + [m["cpu"]])[-self.HISTORY:]

    def render(self, p, m, frame):
        p.text(0, 0, "cpu", 6)
        p.text(p.width("cpu") + 4, 0, f"{round(100 * m['cpu'])}%", 15)
        self._history(p)
        self._die(p, m, self.HISTORY + 4, 42)
        p.rect(0, self.BASE, self.HISTORY - 1, self.BASE, 2)
        self._temp(p, m, frame)
        self._meter(p, 30, "gpu", m["gpu"])
        self._meter(p, 47, "ram", m["mem"])

    def _history(self, p):
        span = self.BASE - self.TOP
        for gx in range(0, self.HISTORY, 4):
            p.dot(gx, self.TOP + span // 2, 2)
        previous = None
        for i, load in enumerate(self.history):
            hx = self.HISTORY - len(self.history) + i
            top = self.BASE - round(span * load)
            if top < self.BASE:
                p.rect(hx, top + 1, hx, self.BASE - 1, 2)
            reach = top if previous is None else previous
            p.rect(hx, min(top, reach), hx, max(top, reach), 10)
            previous = top

    @staticmethod
    def _cells(x, y, w, h, cols, rows, gap):
        return [(x + c * (w + gap) // cols, y + r * (h + gap) // rows,
                 x + (c + 1) * (w + gap) // cols - gap - 1, y + (r + 1) * (h + gap) // rows - gap - 1)
                for r in range(rows) for c in range(cols)]

    def _die(self, p, m, x, w):
        y, h = self.TOP, self.BASE - self.TOP
        groups = self.topology.groups
        big = [core for group in groups if group["kind"] == "p" for core in group["cores"]]
        clusters = [group["cores"] for group in groups if group["kind"] != "p"]
        split = (h - 4) // 2 if big and clusters else h
        tiles = []
        if big:
            cols = min(len(big), 4)
            tiles += zip(self._cells(x, y, w, split, cols, math.ceil(len(big) / cols), 4), big)
        if clusters:
            top = y + split + 4 if big else y
            for box, cores in zip(self._cells(x, top, w, y + h - top, len(clusters), 1, 4), clusters):
                x0, y0, x1, y1 = box
                tiles += zip(self._cells(x0, y0, x1 - x0 + 1, y1 - y0 + 1, 2, math.ceil(len(cores) / 2), 1), cores)
        for (x0, y0, x1, y1), core in tiles:
            threads = core["cpus"]
            for (tx0, ty0, tx1, ty1), cpu in zip(self._cells(x0, y0, x1 - x0 + 1, y1 - y0 + 1, len(threads), 1, 1), threads):
                load = m["threads"].get(cpu, 0.0)
                p.rect(tx0, ty0, tx1, ty1, 1)
                fill = round((ty1 - ty0 + 1) * load)
                if fill:
                    p.rect(tx0, ty1 - fill + 1, tx1, ty1, 14 if load > 0.85 else 5 + round(7 * load))
                    p.rect(tx0, ty1 - fill + 1, tx1, ty1 - fill + 1, 15)

    def _temp(self, p, m, frame):
        temp = int(round(m["temp"]))
        p.text(self.RIGHT, 0, "temp", 15 if temp >= 85 else 6)
        text = f"{min(99, temp):02d}" if temp > 0 else "--"
        on = 15 if temp < 90 or frame % 2 == 0 else 6
        for i, char in enumerate(text):
            p.digit(self.EDGE - 35 + i * 18, 0, 14, 24, 3, char, on, 1)
        p.box(self.EDGE - 2, 0, self.EDGE, 2, 9)

    def _meter(self, p, y, name, value):
        p.text(self.RIGHT, y, name, 6)
        text = f"{round(100 * value)}%"
        p.text(self.EDGE + 1 - p.width(text), y, text, 15)
        segments = (self.EDGE - self.RIGHT + 1) // 3
        lit = round(segments * value)
        for s in range(segments):
            sx = self.RIGHT + s * 3
            p.rect(sx, y + 10, sx + 1, y + 12, 15 if s == lit - 1 else 10 if s < lit else 1)


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
