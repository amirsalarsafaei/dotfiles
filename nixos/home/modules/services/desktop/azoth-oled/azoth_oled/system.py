import os
import socket
import sys
import threading
import time
from pathlib import Path


def boottime():
    return time.clock_gettime(time.CLOCK_BOOTTIME)


def runtime_dir():
    base = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    return Path(os.environ.get("RUNTIME_DIRECTORY", base / "azoth-oled"))


def watchdog(beat, limit):
    while True:
        time.sleep(limit / 6)
        stalled = time.monotonic() - beat[0]
        if stalled > limit:
            log("watchdog-expired", stalled=round(stalled, 1))
            os._exit(70)


class Log:
    def __init__(self):
        self.last = {}

    def __call__(self, event, **fields):
        detail = " ".join(f"{key}={value}" for key, value in fields.items())
        print(f"{event} {detail}".rstrip(), file=sys.stderr, flush=True)

    def forget(self, key):
        self.last.pop(key, None)

    def change(self, key, event, **fields):
        state = (event, tuple(fields.items()))
        if self.last.get(key) != state:
            self.last[key] = state
            self(event, **fields)


log = Log()


class Control:
    def __init__(self):
        self.running = True
        self.idle = False
        self.sleeping = False
        self.requests = []
        self.lock = threading.Lock()
        self.wake = threading.Event()
        self.dark = threading.Event()

    def poke(self):
        self.wake.set()

    def nap(self, seconds):
        if seconds > 0:
            self.wake.wait(seconds)
        self.wake.clear()

    def request(self, item):
        with self.lock:
            self.requests.append(item)
        self.poke()

    def take(self):
        with self.lock:
            items, self.requests = self.requests, []
        return items


def watch_sleep(control):
    try:
        from jeepney import DBusAddress, MatchRule, message_bus, new_method_call
        from jeepney.io.blocking import Proxy, open_dbus_connection
    except ImportError:
        return
    try:
        connection = open_dbus_connection(bus="SYSTEM", enable_fds=True)
        manager = DBusAddress("/org/freedesktop/login1", bus_name="org.freedesktop.login1",
                              interface="org.freedesktop.login1.Manager")
        signal = dict(type="signal", path="/org/freedesktop/login1",
                      interface="org.freedesktop.login1.Manager", member="PrepareForSleep")
        Proxy(message_bus, connection).AddMatch(MatchRule(sender="org.freedesktop.login1", **signal))

        def inhibit():
            call = new_method_call(manager, "Inhibit", "ssss",
                                   ("sleep", "azoth-oled", "Switch the keyboard display off", "delay"))
            return connection.send_and_get_reply(call).body[0]

        lock = inhibit()
        with connection.filter(MatchRule(**signal)) as queue:
            while control.running:
                sleeping = connection.recv_until_filtered(queue).body[0]
                control.dark.clear()
                control.sleeping = sleeping
                control.poke()
                if sleeping:
                    control.dark.wait(3)
                    lock.close()
                else:
                    lock = inhibit()
    except Exception as exc:
        log("sleep-watch-disabled", reason=repr(exc))


def serve_control(control, path):
    try:
        path.unlink(missing_ok=True)
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM | socket.SOCK_CLOEXEC)
        sock.bind(str(path))
        os.chmod(path, 0o600)
    except OSError as exc:
        log("control-disabled", path=path, reason=exc.strerror)
        return
    while control.running:
        try:
            data = sock.recv(4096)
        except OSError:
            continue
        words = data.decode(errors="replace").split()
        if words:
            control.request(words)


def send_control(path, words):
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM | socket.SOCK_CLOEXEC) as sock:
        sock.connect(str(path))
        sock.sendall(" ".join(words).encode())
