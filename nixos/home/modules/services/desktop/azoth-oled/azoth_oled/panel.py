import json

from .system import boottime, log

SETTLE = 2.5
HOLD = 0.9
LAPSE = 1.0


class Handover:
    def __init__(self, path):
        self.path = path

    def load(self):
        try:
            data = json.loads(self.path.read_text())
        except (OSError, ValueError):
            return {}
        return data if isinstance(data, dict) else {}

    def save(self, **fields):
        data = self.load()
        data.update(fields)
        tmp = self.path.with_name(self.path.name + ".tmp")
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            tmp.write_text(json.dumps(data))
            tmp.replace(self.path)
        except OSError:
            pass


class Panel:
    def __init__(self, link, handover, rearm=None):
        self.link = link
        self.handover = handover
        self.rearm = rearm
        self.state = "home"
        self.changed = 0.0
        self.armed = 0.0
        self.shown = 0.0
        self.saved = 0.0
        self.arms = 0
        self.not_before = 0.0

    def adopt(self):
        prior = self.handover.load()
        now = boottime()
        if prior.get("identity") != self.link.identity:
            self.not_before = now + SETTLE
            return "fresh"
        state = prior.get("panel")
        changed = float(prior.get("changed") or 0.0)
        shown = float(prior.get("shown") or 0.0)
        if state == "dark":
            self.state, self.changed = "dark", changed
            return "dark"
        if state == "lit" and 0 <= now - shown < HOLD:
            self.state, self.changed, self.shown = "lit", changed, shown
            self.armed = float(prior.get("armed") or changed)
            return "seamless"
        return "lapsed"

    def settle(self, now):
        wait = self.not_before - now
        if self.state == "dark":
            wait = max(wait, self.changed + SETTLE - now)
        return max(0.0, wait)

    def due(self, now):
        if self.state != "lit":
            return "wake" if self.state == "dark" else "home"
        if self.shown and now - self.shown > LAPSE:
            return "lapse"
        if self.rearm and now - self.armed > self.rearm:
            return "refresh"
        return None

    def arm(self, now, reason):
        if not self.link.power(True):
            return False
        self.state, self.changed, self.armed = "lit", now, now
        self.shown = 0.0
        self.arms += 1
        log("panel-armed", reason=reason)
        self._save(now)
        return True

    def dark(self, now, reason):
        ok = self.link.power(False)
        self.state, self.changed = "dark", now
        log("panel-dark", reason=reason, acked=ok)
        self._save(now)
        return ok

    def frame(self, now):
        self.shown = now
        if now - self.saved >= 0.5:
            self._save(now)

    def release(self, now):
        self._save(now)

    def _save(self, now):
        self.saved = now
        self.handover.save(identity=self.link.identity, panel="dark" if self.state == "dark" else "lit",
                           changed=self.changed, armed=self.armed, shown=self.shown)
