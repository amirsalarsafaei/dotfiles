import colorsys
import json
import math
import os
import random
import time


LEDS = (
    (0, 0, 0), (8, 1, 0), (16, 2, 0), (24, 3, 0), (32, 4, 0), (40, 5, 0), (48, 6, 0), (56, 7, 0),
    (64, 8, 0), (72, 9, 0), (80, 10, 0), (88, 11, 0), (96, 12, 0),
    (1, 0, 1), (9, 1, 1), (17, 2, 1), (25, 3, 1), (33, 4, 1), (41, 5, 1), (49, 6, 1), (57, 7, 1),
    (65, 8, 1), (73, 9, 1), (81, 10, 1), (89, 11, 1), (97, 12, 1), (105, 13, 1), (121, 14, 1),
    (2, 0, 2), (10, 1, 2), (18, 2, 2), (26, 3, 2), (34, 4, 2), (42, 5, 2), (50, 6, 2), (58, 7, 2),
    (66, 8, 2), (74, 9, 2), (82, 10, 2), (90, 11, 2), (98, 12, 2), (107, 13, 2), (122, 14, 2),
    (3, 0, 3), (11, 1, 3), (19, 2, 3), (27, 3, 3), (35, 4, 3), (43, 5, 3), (51, 6, 3), (59, 7, 3),
    (67, 8, 3), (75, 9, 3), (83, 10, 3), (91, 11, 3), (99, 12, 3), (123, 14, 3),
    (4, 0, 4), (12, 1, 4), (20, 2, 4), (28, 3, 4), (36, 4, 4), (44, 5, 4), (52, 6, 4), (60, 7, 4),
    (68, 8, 4), (76, 9, 4), (84, 10, 4), (92, 11, 4), (100, 12, 4), (116, 13, 4), (124, 14, 4),
    (5, 0, 5), (13, 1, 5), (21, 2, 5), (53, 5, 5), (85, 9, 5), (93, 10, 5), (101, 11, 5), (109, 12, 5),
    (117, 13, 5), (125, 14, 5),
)

CENTERS = (
    (0.5, 1.75, 2.75, 3.75, 4.75, 6.0, 7.0, 8.0, 9.0, 10.25, 11.25, 12.25, 13.25),
    (0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 14.0, 15.5),
    (0.75, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.25, 15.5),
    (0.875, 2.25, 3.25, 4.25, 5.25, 6.25, 7.25, 8.25, 9.25, 10.25, 11.25, 12.25, 13.875, 13.875, 15.5),
    (1.125, 1.75, 2.75, 3.75, 4.75, 5.75, 6.75, 7.75, 8.75, 9.75, 10.75, 11.75, 13.125, 14.5, 15.5),
    (0.625, 1.875, 3.125, 3.75, 5.0, 6.875, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 15.5),
)
COLUMNS = 16
ROWS = 6
WHITE = (1.0, 1.0, 1.0)


def mix(a, b, f):
    return tuple(x + (y - x) * f for x, y in zip(a, b))


def scale(color, f):
    return tuple(c * f for c in color)


def hex_rgb(value, default):
    try:
        value = str(value).lstrip("#")
        return tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    except ValueError:
        return default


def vivid(color, fallback):
    if color is None:
        return fallback
    hue, saturation, value = colorsys.rgb_to_hsv(*color)
    if saturation < 0.15 or value < 0.1:
        return fallback
    return colorsys.hsv_to_rgb(hue, 1.0, 1.0)


def ramp(lo, hi, f):
    start = colorsys.rgb_to_hsv(*lo)[0]
    turn = (colorsys.rgb_to_hsv(*hi)[0] - start + 0.5) % 1 - 0.5
    return colorsys.hsv_to_rgb((start + turn * f) % 1, 1.0, 1.0)


def sample(values, position):
    position = max(0.0, min(len(values) - 1.0, position - 0.5))
    i = min(len(values) - 2, int(position))
    return values[i] + (values[i + 1] - values[i]) * (position - i)


class Lights:
    def __init__(self):
        try:
            theme = json.loads(os.environ.get("AZOTH_THEME") or "{}")
        except ValueError:
            theme = {}
        self.blue = hex_rgb(theme.get("blue"), (0.36, 0.61, 0.96))
        self.cyan = hex_rgb(theme.get("cyan"), (0.31, 0.76, 0.97))
        self.heat = hex_rgb(theme.get("heat"), (0.79, 0.46, 0.25))
        self.warm = hex_rgb(theme.get("warm"), (1.0, 0.71, 0.25))
        self.danger = hex_rgb(theme.get("danger"), (1.0, 0.42, 0.42))
        self.brightness = float(os.environ.get("AZOTH_RGB_BRIGHTNESS") or 0.8)
        self.comets = []
        self.ripples = []
        self.random = random.Random(11)
        self.sent = {}
        self.refreshed = 0.0
        self.last = 0.0
        self.start = time.monotonic()
        self.envelope = [0.15] * COLUMNS
        self.level = [0.0] * COLUMNS
        self.peak = [0.0] * COLUMNS
        self.held = [0.0] * COLUMNS
        self.bass = 0.0
        self.kick = 0.0
        self.kicked = 0.0

    def _spectrum(self, bars, now, dt):
        fade = math.exp(-dt / 4)
        for i, value in enumerate(bars):
            self.envelope[i] = max(value, self.envelope[i] * fade, 0.15)
            target = max(0.0, min(1.0, (value / self.envelope[i] / 1.05 - 0.4) / 0.6))
            self.level[i] = max(target, self.level[i] - dt * 2.5)
            if self.level[i] >= self.peak[i]:
                self.peak[i] = self.level[i]
                self.held[i] = now + 0.15
            elif now > self.held[i]:
                self.peak[i] = max(self.level[i], self.peak[i] - dt * 1.8)
        bass = sum(bars[:3]) / 3
        if bass > 0.3 and bass > self.bass + 0.12 and now - self.kicked > 0.18:
            self.kick = 1.0
            self.kicked = now
        else:
            self.kick *= math.exp(-dt * 7)
        self.bass += (bass - self.bass) * min(1.0, dt * 4)

    def _bar(self, x, y, shades, floor):
        position = CENTERS[y][x]
        rise = ROWS - 1 - y
        height = sample(self.level, position) * ROWS
        fill = max(0.0, min(1.0, height - rise))
        color = tuple(max(c * fill * fill, f) for c, f in zip(shades[rise], floor))
        top = sample(self.peak, position) * ROWS
        if top > max(1.0, height + 0.3) and rise == min(ROWS - 1, int(top)):
            color = mix(shades[rise], WHITE, 0.55)
        return color

    def frame(self, now, m, context, audio, events):
        t = now - self.start
        dt = min(0.2, now - self.last) if self.last else 0.04
        self.last = now
        cpu = m["cpu"] if m else 0.0
        temp = m["temp"] if m else 0.0
        self.ripples = [r for r in self.ripples + [(x, y, stamp) for (x, y), stamp in events] if now - r[2] < 1.0][-12:]
        if self.random.random() < (0.03 + 0.3 * cpu) * dt * 25:
            self.comets.append([self.random.randrange(6), -1.0, 7 + 12 * cpu + 4 * self.random.random()])
        for comet in self.comets:
            comet[1] += comet[2] * dt
        self.comets = [c for c in self.comets if c[1] < 18][-8:]
        music = context.music
        bars = audio.bars(COLUMNS) if audio and music and music["playing"] else None
        lo, hi = context.mood if music and context.mood else (self.blue, self.cyan)
        gain = self.brightness
        if bars is not None:
            self._spectrum(bars, now, dt)
            lo, hi = vivid(lo, vivid(self.blue, self.blue)), vivid(hi, vivid(self.cyan, self.cyan))
            shades = [ramp(lo, hi, rise / (ROWS - 1)) for rise in range(ROWS)]
            floor = scale(lo, 0.015 + 0.1 * self.kick)
            gain = 1.0
        spark = mix(hi, WHITE, 0.35)
        warmth = max(0.0, min(1.0, (temp - 80) / 15))
        alert = None
        if any(a["status"] == "error" for a in context.agents):
            alert = self.danger
        elif any(a["status"] == "asking" for a in context.agents):
            alert = self.warm
        colors = {}
        for led, x, y in LEDS:
            if bars is None:
                wave = 0.5 + 0.5 * math.sin(x * 0.45 + y * 0.7 - t * 1.3)
                color = mix(scale(lo, 0.4), scale(hi, 0.9), wave)
                if warmth:
                    color = mix(color, mix(self.heat, self.warm, wave * 0.5), warmth * (0.45 + 0.1 * y))
                for row, head, _ in self.comets:
                    if row == y and 0 <= head - x < 3:
                        color = mix(color, spark, (1 - (head - x) / 3) ** 2)
            else:
                color = self._bar(x, y, shades, floor)
            for rx, ry, stamp in self.ripples:
                age = now - stamp
                dist = math.hypot(x - rx, (y - ry) * 1.15)
                strength = math.exp(-((dist - age * 13) ** 2) / 0.9) * (1 - age)
                if dist < 0.6:
                    strength = max(strength, 1 - age * 3)
                if strength > 0.02:
                    color = mix(color, spark, min(1.0, strength))
            if alert and (x, y) == (0, 0):
                color = mix(color, alert, 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 6)))
            colors[led] = tuple(max(0, min(255, round(c * 255 * gain))) for c in color)
        return colors

    def dark(self):
        return {led: (0, 0, 0) for led, _, _ in LEDS}

    def packets(self, colors, now):
        if now - self.refreshed > 3:
            self.sent = {}
            self.refreshed = now
        changed = [(led, color) for led, color in colors.items() if self.sent.get(led) != color]
        self.sent.update(changed)
        return [changed[i:i + 15] for i in range(0, len(changed), 15)]
