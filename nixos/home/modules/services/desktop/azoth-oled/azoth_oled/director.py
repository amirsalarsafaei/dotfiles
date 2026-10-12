import time

from PIL import Image

from .hid import H, W
from .scenes import Agents, Board, Focus, Music, Painter


class Director:
    DWELL = 45
    URGENT_DWELL = 4
    GLANCE_AFTER = 90
    GLANCE = 60

    PAGES = ("board", "agents", "music", "focus")

    def __init__(self, metrics, fonts, context, audio=None, page=None):
        self.audio = audio
        self.metrics = metrics
        self.fonts = fonts
        self.context = context
        self.board = Board(metrics.topology)
        self.agents = Agents()
        self.music = Music()
        self.focus = Focus()
        self.page = page if page in self.PAGES else "focus"
        self.resumed = page in self.PAGES
        self.pinned = None
        self.since = time.monotonic()
        self.home = None
        self.tick = 0
        self.frame = 0
        self.previous = None
        self.slide = 0
        self.asking = None
        self.track = None
        self.boosts = {}
        self.busy = 0.0
        self.m = None
        self.sampled = 0.0

    def _scores(self, now):
        agents = self.context.agents
        music = self.context.music
        m = self.m or {"cpu": 0.0, "temp": 0.0}
        self.busy += (m["cpu"] - self.busy) * 0.15
        scores = {
            "focus": 40.0,
            "board": 45 + 60 * self.busy + (40 if m["temp"] >= 85 else 0),
            "agents": 0.0,
            "music": 0.0,
        }
        if any(a["status"] in ("asking", "error") for a in agents):
            scores["agents"] = 150
        elif any(a["status"] in ("working", "planning") for a in agents):
            scores["agents"] = 50
        elif agents:
            scores["agents"] = 15
        if music:
            scores["music"] = 60 if music["playing"] else 10
        for page, (until, extra) in list(self.boosts.items()):
            if now < until:
                scores[page] += extra
            else:
                del self.boosts[page]
        return scores

    def _events(self, now):
        asking = {a["id"] for a in self.context.agents if a["status"] in ("asking", "error")}
        if self.asking is not None and asking - self.asking:
            self.boosts["agents"] = (now + 30, 200)
        self.asking = asking
        music = self.context.music
        track = (music["title"], music["artist"]) if music else None
        if track and track != self.track and self.track is not None:
            self.boosts["music"] = (now + 20, 120)
        self.track = track

    def _switch(self, page, image, now):
        if page != self.page:
            self.previous = image
            self.slide = 3
            self.page = page
            self.tick = 0
            self.since = now

    def pin(self, page, seconds):
        if page in self.PAGES:
            self.pinned = (page, time.monotonic() + seconds)
            return True
        return False

    def _choose(self, now, image):
        if self.pinned and now < self.pinned[1]:
            self.home = None
            self._switch(self.pinned[0], image, now)
            return
        self.pinned = None
        scores = self._scores(now)
        ranked = sorted(scores, key=scores.get, reverse=True)
        best = ranked[0]
        dwell = now - self.since
        current = scores.get(self.page, 0)
        if self.home and self.page != self.home:
            if dwell >= self.GLANCE or scores[best] >= 100:
                target = best if scores[best] >= 100 else self.home
                self.home = None
                self._switch(target, image, now)
            return
        if current <= 0 or (scores[best] >= 100 and best != self.page and dwell >= self.URGENT_DWELL):
            self._switch(best, image, now)
        elif best != self.page and scores[best] > current + 15 and dwell >= self.DWELL:
            self._switch(best, image, now)
        elif dwell >= self.GLANCE_AFTER and scores[best] < 100:
            others = [page for page in ranked if page != self.page and scores[page] > 0]
            if others:
                self.home = self.page
                self._switch(others[0], image, now)

    def next_frame(self):
        now = time.monotonic()
        if self.m is None or now - self.sampled >= 1.0:
            self.m = self.metrics.sample()
            self.sampled = now
            self._events(now)
            if self.frame == 0 and not self.resumed:
                scores = self._scores(now)
                self.page = max(scores, key=scores.get)
        self.frame += 1
        self.tick += 1
        self.board.step(self.m)
        current = self._render(self.page)
        before = self.page
        self._choose(now, current)
        image = self._render(self.page) if self.page != before else current
        if self.slide and self.previous is not None:
            shift = W * self.slide // 4
            frame = Image.new("L", (W, H), 0)
            frame.paste(self.previous.crop((W - shift, 0, W, H)), (0, 0))
            frame.paste(image.crop((0, 0, W - shift, H)), (shift, 0))
            self.slide -= 1
            image = frame
        orbit = ((0, 0), (1, 0), (1, 1), (0, 1))
        dx, dy = orbit[(int(time.time()) // 120) % len(orbit)]
        if dx or dy:
            moved = Image.new("L", (W, H), 0)
            moved.paste(image, (dx, dy))
            image = moved
        return image

    def _render(self, page):
        p = Painter(self.fonts)
        if page == "board":
            self.board.render(p, self.m, self.frame)
        elif page == "agents":
            self.agents.render(p, self.context.agents, self.frame)
        elif page == "music" and self.context.music:
            self.music.render(p, self.context.music, self.frame, self.tick, self.audio.bars(20) if self.audio else None)
        else:
            self.focus.render(p, self.context.focus, self.frame, self.tick)
        return p.image
