import errno
import json
import os
import threading
import time

from . import hid
from .director import Director
from .lights import Lights
from .panel import Handover, Panel
from .scenes import Fonts
from .sources import Audio, Context, Keys, Metrics, Refresher
from .system import Control, boottime, log, runtime_dir, serve_control, watch_sleep, watchdog

GAP = 0.1
QUIET = 0.06
LIGHTS_HZ = 20
STATS_EVERY = 600
RESET_EVERY = 60
WATCHDOG = 30


class Engine:
    def __init__(self, fps, lighting, ripples, rearm):
        self.period = 1 / fps
        self.rearm = rearm
        self.control = Control()
        self.runtime = runtime_dir()
        try:
            self.runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
        except OSError:
            pass
        self.handover = Handover(self.runtime / "handover.json")
        self.status_path = self.runtime / "status.json"
        self.audio = Audio()
        self.lights = Lights() if lighting else None
        self.keys = Keys() if self.lights and ripples else None
        self.context = Context()
        self.refresher = Refresher(self.context)
        self.director = Director(Metrics(), Fonts(), self.context, self.audio, page=self.handover.load().get("page"))
        self.link = None
        self.panel = None
        self.lit_at = 0.0
        self.failures = 0
        self.reopened = False
        self.reset_at = -RESET_EVERY
        self.faults = []
        self.counts = {"connects": 0, "resets": 0, "drops": 0}
        self.last_error = None
        self.stats_at = time.monotonic()
        self.status_at = 0.0
        self.started = time.monotonic()
        self.shown = 0
        self.fps = 0.0
        self.beat = [time.monotonic()]

    def run(self):
        threading.Thread(target=watch_sleep, args=(self.control,), daemon=True).start()
        threading.Thread(target=serve_control, args=(self.control, self.runtime / "control"), daemon=True).start()
        threading.Thread(target=watchdog, args=(self.beat, WATCHDOG), daemon=True).start()
        self.refresher.ready.wait(0.3)
        log("started", fps=round(1 / self.period, 2), rearm=self.rearm or "off")
        while self.control.running:
            self.beat[0] = time.monotonic()
            self._requests()
            try:
                if self.link is None:
                    self._connect()
                else:
                    self._tick()
            except OSError as exc:
                self._fault(exc)
            self._report()
        self._stop()

    def stop(self):
        self.control.running = False
        self.control.poke()

    def idle(self, on):
        self.control.idle = on
        self.control.poke()

    def _requests(self):
        for words in self.control.take():
            verb, args = words[0], words[1:]
            if verb == "idle" and args in (["on"], ["off"]):
                self.idle(args[0] == "on")
            elif verb == "page" and args:
                seconds = float(args[1]) if len(args) > 1 and args[1].replace(".", "", 1).isdigit() else 60.0
                if not self.director.pin(args[0], seconds):
                    log("control-rejected", request=" ".join(words))
            elif verb == "rearm" and self.panel:
                self.panel.state = "home"
            else:
                log("control-rejected", request=" ".join(words))

    def _connect(self):
        found = hid.nodes(b"\x06\x00\xff")
        if not found:
            log.change("link", "waiting", reason="no wired ROG Azoth")
            self.control.nap(2)
            return
        path = found[0][0]
        try:
            link = hid.Link(path)
        except hid.Busy:
            log.change("link", "waiting", reason="another azoth-oled holds", device=path)
            self.control.nap(5)
            return
        if link.foreign(0.3):
            link.close()
            log.change("link", "waiting", reason="another program is writing to", device=path)
            self.control.nap(5)
            return
        self.link = link
        self.panel = Panel(link, self.handover, self.rearm)
        adopted = self.panel.adopt()
        self.failures = 0
        self.reopened = False
        self.counts["connects"] += 1
        log.change("link", "connected", device=path, usb=link.identity, panel=adopted)
        if self.lights:
            self.lights.sent = {}

    def _drop(self, reason, reset=False):
        if self.link is None:
            return
        if reset:
            now = time.monotonic()
            if now - self.reset_at >= RESET_EVERY:
                self.reset_at = now
                self.counts["resets"] += 1
                self.handover.save(identity=None)
                try:
                    self.link.reset()
                    log("usb-reset", device=self.link.path, reason=reason)
                except OSError as exc:
                    log("usb-reset-failed", device=self.link.path, reason=exc.strerror or reason)
            else:
                log("usb-reset-skipped", reason=reason, wait=round(RESET_EVERY - (now - self.reset_at)))
        if self.panel and not reset:
            self.panel.release(boottime())
        self.link.close()
        self.link = None
        self.panel = None
        self.counts["drops"] += 1
        log.forget("link")
        log("disconnected", reason=reason)

    def _fault(self, exc):
        name = self.link.counters.error(exc) if self.link else errno.errorcode.get(exc.errno, str(exc.errno))
        self.last_error = f"{name}: {exc.strerror}"
        log.change("fault", "io-error", error=name, detail=repr(exc.strerror), device=self.link.path if self.link else None)
        now = time.monotonic()
        self.faults = [t for t in self.faults if now - t < 60] + [now]
        if exc.errno in hid.GONE:
            self._drop(f"device gone ({name})")
            self.control.nap(0.5)
        elif exc.errno == errno.EPIPE or len(self.faults) >= 3:
            self._drop(f"{name}, {len(self.faults)} faults in 60 s", reset=True)
            self.control.nap(2)
        else:
            self._drop(name)
            self.control.nap(1)

    def _tick(self):
        now = boottime()
        if self.control.idle or self.control.sleeping:
            self._dark(now)
            return
        wait = self.panel.settle(now)
        if wait:
            self._light_step()
            self.control.nap(min(0.1, wait))
            return
        due = self.panel.due(now)
        if due and not self.panel.arm(now, due):
            self._failed("arm")
            return
        self.audio.want(bool(self.context.music and self.context.music["playing"]))
        start = time.monotonic()
        frame = hid.pack(self.director.next_frame())
        if self.link.upload(frame, self._light_step):
            self.panel.frame(boottime())
            log.forget("fault")
            self._recovered()
            self.shown += 1
        else:
            self._failed("frame")
        end = time.monotonic()
        next_at = max(start + self.period, end + GAP)
        while self.control.running and (left := next_at - time.monotonic()) > 0:
            if time.monotonic() - end >= QUIET:
                self._light_step()
            self.control.nap(min(0.02, left))

    def _failed(self, what):
        self.failures += 1
        log.change("upload", "upload-failing", what=what)
        if self.failures >= 12 and self.reopened:
            self._drop(f"{self.failures} failed uploads after reopen", reset=True)
            self.control.nap(2)
        elif self.failures >= 6 and not self.reopened:
            self._drop(f"{self.failures} failed uploads")
            self.control.nap(0.5)
            self._connect()
            if self.link:
                self.reopened = True
                self.failures = 6
                self.panel.state = "home"
        else:
            self.control.nap(0.15)

    def _recovered(self):
        if self.failures:
            log("upload-recovered", after=self.failures)
        log.forget("upload")
        self.failures = 0
        self.reopened = False

    def _dark(self, now):
        if self.panel.state != "dark":
            self.panel.dark(now, "sleep" if self.control.sleeping else "idle")
            if self.lights:
                self.lights.sent = {}
                self.link.lights(self.lights.packets(self.lights.dark(), time.monotonic()))
        self.audio.stop()
        if self.keys:
            self.keys.take()
        self.control.dark.set()
        self.control.nap(5)

    def _light_step(self):
        if self.lights is None or self.link is None:
            return
        now = time.monotonic()
        if now - self.lit_at < 1 / LIGHTS_HZ:
            return
        self.lit_at = now
        events = self.keys.take() if self.keys else []
        colors = self.lights.frame(now, self.director.m, self.context, self.audio, events)
        self.link.lights(self.lights.packets(colors, now))

    def _report(self):
        now = time.monotonic()
        if now - self.status_at >= 2:
            elapsed = now - self.status_at if self.status_at else now - self.started
            self.fps = round(self.shown / elapsed, 2) if elapsed > 0 else 0.0
            self.shown = 0
            self.status_at = now
            self._status()
        if now - self.stats_at >= STATS_EVERY:
            self.stats_at = now
            counters = self.link.counters if self.link else hid.Counters()
            log("stats", fps=self.fps, frames=counters.frames, failed=counters.failed, naks=counters.naks,
                timeouts=counters.timeouts, stray=counters.stray, arms=self.panel.arms if self.panel else 0,
                connects=self.counts["connects"], drops=self.counts["drops"], resets=self.counts["resets"])

    def _status(self):
        counters = self.link.counters if self.link else hid.Counters()
        status = {
            "pid": os.getpid(),
            "state": "dark" if self.panel and self.panel.state == "dark" else "streaming" if self.link else "waiting",
            "device": self.link.path if self.link else None,
            "usb": self.link.identity if self.link else None,
            "page": self.director.page,
            "fps": self.fps,
            "frames": counters.frames,
            "failed": counters.failed,
            "naks": counters.naks,
            "timeouts": counters.timeouts,
            "stray": counters.stray,
            "errors": counters.errors,
            "arms": self.panel.arms if self.panel else 0,
            "connects": self.counts["connects"],
            "drops": self.counts["drops"],
            "resets": self.counts["resets"],
            "last_error": self.last_error,
            "updated": time.time(),
        }
        tmp = self.status_path.with_name("status.json.tmp")
        try:
            tmp.write_text(json.dumps(status, indent=1))
            tmp.replace(self.status_path)
        except OSError:
            pass
        self.handover.save(page=self.director.page)

    def _stop(self):
        self.audio.stop()
        if self.link:
            if self.panel:
                self.panel.release(boottime())
            self.link.close()
        log("stopped")
