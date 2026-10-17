import errno
import fcntl
import os
import select
import time
from dataclasses import dataclass, field
from pathlib import Path

VENDOR = 0x0B05
PRODUCTS = {0x1A83}
REPORT = 64
CHUNK = REPORT - 4
W, H = 208, 64

GONE = {errno.ENODEV, errno.ENOENT, errno.ENXIO, errno.ESHUTDOWN, errno.EIO, errno.EBADF}


class Busy(Exception):
    pass


@dataclass
class Counters:
    frames: int = 0
    failed: int = 0
    naks: int = 0
    timeouts: int = 0
    stray: int = 0
    lights: int = 0
    errors: dict = field(default_factory=dict)

    def error(self, exc):
        name = errno.errorcode.get(exc.errno, str(exc.errno))
        self.errors[name] = self.errors.get(name, 0) + 1
        return name


def _hid_id(node):
    try:
        uevent = node.joinpath("device/uevent").read_text()
        descriptor = node.joinpath("device/report_descriptor").read_bytes()
    except OSError:
        return None, b""
    hid_id = next((line.split("=", 1)[1] for line in uevent.splitlines() if line.startswith("HID_ID=")), "")
    parts = hid_id.split(":")
    if len(parts) != 3:
        return None, b""
    return (int(parts[1], 16), int(parts[2], 16)), descriptor


def nodes(prefix):
    found = []
    for node in sorted(Path("/sys/class/hidraw").glob("hidraw*")):
        ident, descriptor = _hid_id(node)
        if ident and ident[0] == VENDOR and ident[1] in PRODUCTS \
                and descriptor.startswith(prefix) and b"\x85" not in descriptor:
            found.append((f"/dev/{node.name}", descriptor))
    return found


def usb_device(path):
    current = (Path("/sys/class/hidraw") / Path(path).name / "device").resolve()
    while current != current.parent:
        if (current / "busnum").exists() and (current / "devnum").exists():
            return current
        current = current.parent
    return None


class Link:
    def __init__(self, path):
        self.path = path
        self.counters = Counters()
        self.fd = os.open(path, os.O_RDWR | os.O_NONBLOCK | os.O_CLOEXEC)
        try:
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(self.fd)
            raise Busy(path) from None
        usb = usb_device(path)
        self.usb = usb
        self.identity = None
        if usb:
            try:
                self.identity = ":".join((usb / name).read_text().strip()
                                         for name in ("busnum", "devnum", "serial") if (usb / name).exists())
            except OSError:
                pass

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def _read(self, timeout):
        if not select.select([self.fd], [], [], max(0.0, timeout))[0]:
            return b""
        try:
            return os.read(self.fd, 256)
        except BlockingIOError:
            return b""

    def foreign(self, seconds):
        deadline = time.monotonic() + seconds
        while (left := deadline - time.monotonic()) > 0:
            if self._read(left):
                return True
        return False

    def command(self, *body, payload=b"", echo=2, wait=0.25, expect=None):
        report = bytes(body) + payload
        report += bytes(REPORT - len(report))
        expect = expect or report[:echo]
        while self._read(0):
            self.counters.stray += 1
        os.write(self.fd, report)
        deadline = time.monotonic() + wait
        while (left := deadline - time.monotonic()) > 0:
            reply = self._read(left)
            if reply[:len(expect)] == expect:
                return True
            if reply[:2] == b"\xff\xaa":
                self.counters.naks += 1
                return False
            if reply:
                self.counters.stray += 1
        self.counters.timeouts += 1
        return False

    def upload(self, frame, between=None):
        total = (len(frame) + CHUNK - 1) // CHUNK
        ok = self.command(0x67, 0x00, 0x00, 0x00, 0x00, 0x00, total & 0xFF, total >> 8, W & 0xFF, W >> 8, H & 0xFF, H >> 8)
        for sent in range(total) if ok else ():
            left = total - 1 - sent
            if between:
                between(left)
            index = left.to_bytes(2, "little")
            if not self.command(0x67, 0x01, *index, payload=frame[sent * CHUNK:(sent + 1) * CHUNK], echo=4):
                ok = False
                break
        if ok:
            self.counters.frames += 1
        else:
            self.counters.failed += 1
        return ok

    def lights(self, chunks):
        for chunk in chunks:
            payload = b"".join(bytes((led, *color)) for led, color in chunk)
            if self.command(0xC0, 0x81, len(chunk), 0x00, payload=payload, expect=b"\xc0\x82"):
                self.counters.lights += 1

    def power(self, on):
        return self.command(0x69, 0x00, 0x00, 0x00, 1 if on else 0)

    def reset(self):
        if not self.usb:
            raise OSError(errno.ENODEV, "no USB parent for", self.path)
        node = f"/dev/bus/usb/{int((self.usb / 'busnum').read_text()):03d}/{int((self.usb / 'devnum').read_text()):03d}"
        fd = os.open(node, os.O_WRONLY | os.O_CLOEXEC)
        try:
            fcntl.ioctl(fd, 0x5514, 0)
        finally:
            os.close(fd)


LOW = bytes(v >> 4 for v in range(256))
HIGH = bytes(v & 0xF0 for v in range(256))


def pack(image):
    data = image.tobytes()
    left = int.from_bytes(data[0::2].translate(LOW), "big")
    right = int.from_bytes(data[1::2].translate(HIGH), "big")
    return (left | right).to_bytes(len(data) // 2, "big")
