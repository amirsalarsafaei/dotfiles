import json
import os
import re
import select
import socket
import subprocess
import threading
import time
from pathlib import Path

from .hid import VENDOR, PRODUCTS
from .lights import hex_rgb
from .system import log

KEYPOS = {0x29: (0, 0), 0x35: (0, 1), 0x2D: (11, 1), 0x2E: (12, 1), 0x2A: (13, 1), 0x49: (14, 1),
          0x2B: (0, 2), 0x2F: (11, 2), 0x30: (12, 2), 0x31: (13, 2), 0x4C: (14, 2),
          0x39: (0, 3), 0x33: (10, 3), 0x34: (11, 3), 0x28: (12, 3), 0x4B: (14, 3),
          0xE1: (0, 4), 0x36: (9, 4), 0x37: (10, 4), 0x38: (11, 4), 0xE5: (12, 4), 0x52: (13, 4), 0x4E: (14, 4),
          0xE0: (0, 5), 0xE3: (1, 5), 0xE2: (2, 5), 0x2C: (5, 5), 0xE6: (9, 5), 0xE7: (10, 5), 0xE4: (11, 5),
          0x50: (12, 5), 0x51: (13, 5), 0x4F: (14, 5)}
KEYPOS.update({0x3A + i: (1 + i, 0) for i in range(12)})
KEYPOS.update({0x1E + i: (1 + i, 1) for i in range(10)})
KEYPOS.update({code: (1 + i, 2) for i, code in enumerate((0x14, 0x1A, 0x08, 0x15, 0x17, 0x1C, 0x18, 0x0C, 0x12, 0x13))})
KEYPOS.update({code: (1 + i, 3) for i, code in enumerate((0x04, 0x16, 0x07, 0x09, 0x0A, 0x0B, 0x0D, 0x0E, 0x0F))})
KEYPOS.update({code: (2 + i, 4) for i, code in enumerate((0x1D, 0x1B, 0x06, 0x19, 0x05, 0x11, 0x10))})


class Topology:
    def __init__(self):
        root = Path("/sys/devices/system/cpu")
        performance = self._cpus("/sys/devices/cpu_core/cpus")
        efficient = self._cpus("/sys/devices/cpu_atom/cpus")
        threads = []
        for entry in sorted(root.glob("cpu[0-9]*"), key=lambda p: int(p.name[3:])):
            n = int(entry.name[3:])
            threads.append({
                "cpu": n,
                "core": (self._read_int(entry / "cache/index3/id", 0), self._read_int(entry / "topology/core_id", n)),
                "l2": self._read_int(entry / "cache/index2/id", -1),
                "l3": self._read_int(entry / "cache/index3/id", 0),
                "khz": self._read_int(entry / "cpufreq/cpuinfo_max_freq", 0),
                "kind": "p" if n in performance else "e" if n in efficient else "",
            })
        top = max((t["khz"] for t in threads), default=0)
        for t in threads:
            if not t["kind"]:
                t["kind"] = "e" if top and 0 < t["khz"] < 0.85 * top else "p"
        cores = {}
        for t in threads:
            cores.setdefault(t["core"], {"kind": t["kind"], "l2": t["l2"], "l3": t["l3"], "cpus": []})["cpus"].append(t["cpu"])
        groups = []
        index = {}
        for key in sorted(cores):
            core = cores[key]
            if core["kind"] == "p":
                group = ("p", core["l3"])
            else:
                shared = sum(1 for c in cores.values() if c["l2"] == core["l2"]) > 1
                group = ("l2", core["l2"]) if shared else ("l3", core["l3"])
            if group not in index:
                index[group] = len(groups)
                groups.append({"kind": core["kind"], "cores": []})
            groups[index[group]]["cores"].append(core)
        self.groups = groups

    @staticmethod
    def _cpus(path):
        try:
            text = Path(path).read_text().strip()
        except OSError:
            return set()
        out = set()
        for part in filter(None, text.split(",")):
            lo, _, hi = part.partition("-")
            out.update(range(int(lo), int(hi or lo) + 1))
        return out

    @staticmethod
    def _read_int(path, default):
        try:
            return int(Path(path).read_text().split()[0])
        except (OSError, ValueError, IndexError):
            return default


class Metrics:
    def __init__(self):
        self.topology = Topology()
        self.temp_path = self._thermal()
        self.gpu = self._gpu()
        self.disk = self._disk()
        self.prev = None
        self.prev_time = None

    @staticmethod
    def _hwmon(*names):
        for hw in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
            try:
                if hw.joinpath("name").read_text().strip() in names:
                    return hw
            except OSError:
                continue
        return None

    def _thermal(self):
        hw = self._hwmon("coretemp", "k10temp", "zenpower")
        if hw and hw.joinpath("temp1_input").exists():
            return hw / "temp1_input"
        for zone in sorted(Path("/sys/class/thermal").glob("thermal_zone*")):
            try:
                if zone.joinpath("type").read_text().strip() == "x86_pkg_temp":
                    return zone / "temp"
            except OSError:
                continue
        zone = Path("/sys/class/thermal/thermal_zone0/temp")
        return zone if zone.exists() else None

    @staticmethod
    def _gpu():
        for card in sorted(Path("/sys/class/drm").glob("card[0-9]")):
            busy = card / "device/gpu_busy_percent"
            if busy.exists():
                return {"busy": busy}
            for idle in (card / "gt/gt0/rc6_residency_ms", card / "device/tile0/gt0/gtidle/idle_residency_ms"):
                if idle.exists():
                    return {"idle": idle}
        return None

    @staticmethod
    def _disk():
        for pattern in ("nvme*", "sd*", "vd*", "mmcblk*"):
            for block in sorted(Path("/sys/block").glob(pattern)):
                if block.joinpath("device").exists():
                    return block.name
        return None

    @staticmethod
    def _int(path, default=0):
        try:
            return int(Path(path).read_text().split()[0])
        except (OSError, ValueError, IndexError, TypeError):
            return default

    def _counters(self):
        cpus = {}
        for line in Path("/proc/stat").read_text().splitlines():
            if not line.startswith("cpu"):
                break
            name, *values = line.split()
            values = [int(v) for v in values[:8]]
            cpus[name] = (sum(values), values[3] + values[4])
        net = 0
        for line in Path("/proc/net/dev").read_text().splitlines()[2:]:
            name, _, data = line.partition(":")
            if name.strip() == "lo":
                continue
            fields = data.split()
            net += int(fields[0]) + int(fields[8])
        disk = 0
        if self.disk:
            for line in Path("/proc/diskstats").read_text().splitlines():
                fields = line.split()
                if fields[2] == self.disk:
                    disk = (int(fields[5]) + int(fields[9])) * 512
        gpu_idle = self._int(self.gpu["idle"]) if self.gpu and "idle" in self.gpu else None
        return {"cpus": cpus, "net": net, "disk": disk, "gpu_idle": gpu_idle}

    def sample(self):
        now = time.monotonic()
        current = self._counters()
        prev, dt = self.prev, (now - self.prev_time) if self.prev_time else 0
        self.prev, self.prev_time = current, now
        out = {"temp": self._int(self.temp_path) / 1000 if self.temp_path else 0}
        load = {}
        for name, (total, idle) in current["cpus"].items():
            if prev and name in prev["cpus"] and total > prev["cpus"][name][0]:
                load[name] = max(0.0, min(1.0, 1 - (idle - prev["cpus"][name][1]) / (total - prev["cpus"][name][0])))
            else:
                load[name] = 0.0
        out["cpu"] = load.get("cpu", 0.0)
        out["threads"] = {int(k[3:]): v for k, v in load.items() if k != "cpu"}
        mem = {}
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, _, value = line.partition(":")
            mem[key] = int(value.split()[0])
        out["mem"] = 1 - mem.get("MemAvailable", 0) / max(1, mem.get("MemTotal", 1))
        for key in ("net", "disk"):
            out[key] = max(0.0, (current[key] - prev[key]) / dt) if prev and dt > 0 else 0.0
        out["gpu"] = 0.0
        if self.gpu and "busy" in self.gpu:
            out["gpu"] = self._int(self.gpu["busy"]) / 100
        elif self.gpu and prev and dt > 0 and current["gpu_idle"] is not None:
            out["gpu"] = max(0.0, min(1.0, 1 - (current["gpu_idle"] - prev["gpu_idle"]) / (dt * 1000)))
        return out


class Context:
    def __init__(self):
        self.runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
        self.agents = []
        self.music = None
        self.focus = None
        self.mood = None
        self.live = None
        self.live_keys = None
        self.live_checked = 0.0

    def _json(self, relative):
        try:
            return json.loads((self.runtime / relative).read_text())
        except (OSError, ValueError):
            return None

    def refresh(self):
        self.agents = self._agents()
        self.music = self._music()
        self.focus = self._focus()
        palette = self._json("mood/palette.json") or {}
        primary, secondary = palette.get("primary"), palette.get("secondary")
        self.mood = (hex_rgb(secondary, None), hex_rgb(primary, None)) if palette.get("active") and primary and secondary else None

    def _panes(self):
        zellij = os.environ.get("AZOTH_ZELLIJ")
        if not zellij:
            return None

        def run(*args):
            done = subprocess.run([zellij, *args], capture_output=True, text=True, timeout=3)
            if done.returncode and "No active zellij sessions" in done.stdout + done.stderr:
                return ""
            if done.returncode:
                raise subprocess.SubprocessError((done.stderr.strip().splitlines() or [f"exit {done.returncode}"])[-1])
            return done.stdout

        try:
            listing = run("list-sessions", "-n")
        except (OSError, subprocess.SubprocessError) as exc:
            log.change("zellij", "pane-check-unavailable", reason=repr(str(exc)))
            return None
        live = set()
        for line in listing.splitlines():
            if "[Created" not in line or "EXITED" in line:
                continue
            session = line.split()[0]
            try:
                panes = json.loads(run("-s", session, "action", "list-panes", "-j", "-a"))
            except (OSError, subprocess.SubprocessError, ValueError) as exc:
                log.change("zellij", "pane-check-unavailable", session=session, reason=repr(str(exc)))
                return None
            if not isinstance(panes, list):
                return None
            for pane in panes:
                if not pane.get("is_plugin") and not pane.get("exited") \
                        and re.search(r"/bin/claude( |$)", str(pane.get("pane_command") or "")):
                    live.add((session, str(pane.get("id"))))
        log.forget("zellij")
        return live

    def _agents(self):
        data = self._json("claude-agents/state.json")
        if not isinstance(data, dict):
            return []
        keys = frozenset(data)
        if keys != self.live_keys or time.monotonic() - self.live_checked > 30:
            self.live = self._panes()
            self.live_keys = keys
            self.live_checked = time.monotonic()
        now = time.time() * 1000
        out = []
        for key, s in data.items():
            if not isinstance(s, dict):
                continue
            pane = s.get("zellij") if isinstance(s.get("zellij"), dict) else {}
            if self.live is not None and pane.get("session") and pane.get("pane") is not None:
                if (str(pane["session"]), str(pane["pane"])) not in self.live:
                    continue
            elif now - (s.get("at") or 0) > 3600 * 1000:
                continue
            state = s.get("state")
            if state == "error":
                status = "error"
            elif state == "waiting":
                status = "asking"
            elif state == "working":
                status = "planning" if s.get("mode") == "plan" else "working"
            else:
                status = "done" if s.get("verb") == "done" else "ready"
            if status in ("done", "ready") and now - (s.get("at") or 0) > 2 * 3600 * 1000:
                continue
            variant = str(s.get("variant") or "")
            out.append({
                "id": key,
                "status": status,
                "name": str(s.get("project") or "claude"),
                "realm": s.get("realm"),
                "breed": "whale" if "deepseek" in variant else "antenna" if "glm" in variant else "",
                "since": s.get("since") or 0,
            })
        rank = {"asking": 0, "error": 1, "working": 2, "planning": 2, "ready": 3, "done": 4}
        out.sort(key=lambda a: (rank[a["status"]], -a["since"]))
        return out

    def _music(self):
        line = self._json("lyrics/line.json") or {}
        if line.get("class") not in ("playing", "paused"):
            return None
        track = self._json("lyrics/track.json") or {}
        tooltip = str(line.get("tooltip") or "")
        title, _, artist = tooltip.partition(" — ")
        return {
            "playing": line.get("class") == "playing",
            "title": title or str(track.get("title") or ""),
            "artist": artist or str(track.get("artist") or ""),
            "lyric": str(line.get("text") or "") if track.get("synced") else "",
        }

    def _query(self, path, command):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.3)
            sock.connect(str(path))
            sock.sendall(command)
            data = b""
            while chunk := sock.recv(65536):
                data += chunk
        return json.loads(data or b"{}")

    def _focus(self):
        sockets = sorted(self.runtime.glob("hypr/*/.socket.sock"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not sockets:
            return None
        try:
            window = self._query(sockets[0], b"j/activewindow")
            workspace = (window.get("workspace") or {}).get("id")
            if workspace is None:
                workspace = self._query(sockets[0], b"j/activeworkspace").get("id")
        except (OSError, ValueError):
            return None
        app = str(window.get("class") or "")
        app = app.rsplit(".", 1)[-1].removeprefix("google-").lower() or "desktop"
        return {"app": app, "title": str(window.get("title") or ""), "workspace": workspace}


class Refresher:
    SLOW = 2.0

    def __init__(self, context, period=1.0):
        self.context = context
        self.period = period
        self.ready = threading.Event()
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        while True:
            started = time.monotonic()
            try:
                self.context.refresh()
            except Exception as exc:
                log.change("context", "context-refresh-failed", reason=repr(exc))
            else:
                log.forget("context")
            took = time.monotonic() - started
            if took > self.SLOW:
                log("context-refresh-slow", seconds=round(took, 1))
            self.ready.set()
            time.sleep(max(0.2, self.period - took))


class Audio:
    def __init__(self):
        self.binary = os.environ.get("AZOTH_CAVA")
        self.config = os.environ.get("AZOTH_CAVA_CONFIG")
        self.process = None
        self.levels = []
        self.updated = 0.0

    def want(self, on):
        if on and self.process is None and self.binary and self.config:
            try:
                self.process = subprocess.Popen([self.binary, "-p", self.config], stdin=subprocess.DEVNULL,
                                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            except OSError as exc:
                log("cava-failed", reason=exc.strerror)
                self.binary = None
                return
            threading.Thread(target=self._read, args=(self.process,), daemon=True).start()
        elif not on and self.process is not None:
            self.stop()

    def stop(self):
        if self.process is not None:
            self.process.terminate()
            try:
                self.process.wait(1)
            except subprocess.TimeoutExpired:
                self.process.kill()
            self.process = None
            self.levels = []

    def _read(self, process):
        for line in process.stdout:
            values = [int(v) / 100 for v in line.strip().split(";") if v.isdigit()]
            if values:
                self.levels = values
                self.updated = time.monotonic()

    def bars(self, count):
        levels = self.levels
        if not levels or time.monotonic() - self.updated > 1:
            return None
        return [levels[min(len(levels) - 1, i * len(levels) // count)] for i in range(count)]


class Keys:
    def __init__(self):
        self.events = []
        self.lock = threading.Lock()
        threading.Thread(target=self._run, daemon=True).start()

    def take(self):
        with self.lock:
            events, self.events = self.events, []
        return events

    @staticmethod
    def _nodes():
        found = []
        for node in sorted(Path("/sys/class/hidraw").glob("hidraw*")):
            try:
                uevent = node.joinpath("device/uevent").read_text()
                descriptor = node.joinpath("device/report_descriptor").read_bytes()
            except OSError:
                continue
            hid_id = next((line.split("=", 1)[1] for line in uevent.splitlines() if line.startswith("HID_ID=")), "")
            parts = hid_id.split(":")
            if len(parts) == 3 and int(parts[1], 16) == VENDOR and int(parts[2], 16) in PRODUCTS \
                    and descriptor[:4] == b"\x05\x01\x09\x06" and b"\x85" not in descriptor:
                found.append((f"/dev/{node.name}", b"\x95\x78" in descriptor))
        return found

    @staticmethod
    def _decode(data, bitmap):
        down = set()
        if bitmap:
            for i, byte in enumerate(data[:15]):
                down.update(i * 8 + bit for bit in range(8) if byte >> bit & 1)
        elif len(data) >= 8:
            down.update(0xE0 + bit for bit in range(8) if data[0] >> bit & 1)
            down.update(code for code in data[2:8] if code > 3)
        return down

    def _run(self):
        while True:
            fds = {}
            for path, bitmap in self._nodes():
                try:
                    fds[os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)] = [bitmap, set()]
                except OSError:
                    continue
            try:
                while fds:
                    for fd in select.select(list(fds), [], [], 30)[0]:
                        data = os.read(fd, 64)
                        down = self._decode(data, fds[fd][0])
                        pressed = down - fds[fd][1]
                        fds[fd][1] = down
                        if pressed:
                            stamp = time.monotonic()
                            with self.lock:
                                self.events.extend((KEYPOS[code], stamp) for code in pressed if code in KEYPOS)
                                del self.events[:-16]
            except OSError:
                pass
            finally:
                for fd in fds:
                    os.close(fd)
            time.sleep(3)
