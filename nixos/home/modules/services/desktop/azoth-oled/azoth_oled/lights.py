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
        bars = audio.bars(15) if audio and music and music["playing"] else None
        lo, hi = context.mood if music and context.mood else (self.blue, self.cyan)
        spark = mix(hi, (1.0, 1.0, 1.0), 0.35)
        warmth = max(0.0, min(1.0, (temp - 80) / 15))
        alert = None
        if any(a["status"] == "error" for a in context.agents):
            alert = self.danger
        elif any(a["status"] == "asking" for a in context.agents):
            alert = self.warm
        colors = {}
        for led, x, y in LEDS:
            wave = 0.5 + 0.5 * math.sin(x * 0.45 + y * 0.7 - t * 1.3)
            color = mix(scale(lo, 0.4), scale(hi, 0.9), wave)
            if warmth:
                color = mix(color, mix(self.heat, self.warm, wave * 0.5), warmth * (0.45 + 0.1 * y))
            if bars is not None:
                height = bars[min(14, x)] * 6.5
                rise = 5 - y
                color = scale(lo, 0.1)
                if rise < height:
                    lit = mix(lo, hi, rise / 5)
                    color = mix(lit, (1.0, 1.0, 1.0), 0.25) if rise >= height - 1 else scale(lit, 0.75)
            for row, head, _ in self.comets:
                if row == y and 0 <= head - x < 3:
                    color = mix(color, spark, (1 - (head - x) / 3) ** 2)
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
            colors[led] = tuple(max(0, min(255, round(c * 255 * self.brightness))) for c in color)
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
