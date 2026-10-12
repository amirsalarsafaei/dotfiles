import argparse
import json
import os
import signal
import sys
import time

from .system import runtime_dir, send_control


def preview(path, frames, scale, pages):
    from PIL import Image

    from .director import Director
    from .hid import H, W
    from .scenes import Fonts
    from .sources import Context, Metrics

    context = Context()
    context.refresh()
    director = Director(Metrics(), Fonts(), context)
    director.next_frame()
    director._choose = lambda now, image: None
    images = []
    for page in pages:
        director.page = page
        director.slide = 0
        for _ in range(frames):
            images.append(director.next_frame())
            time.sleep(0.34)
    sheet = Image.new("L", (W * scale, (H * scale + 8) * len(images)), 40)
    for i, image in enumerate(images):
        quantized = image.point(lambda v: (v >> 4) * 17)
        sheet.paste(quantized.resize((W * scale, H * scale), Image.NEAREST), (0, i * (H * scale + 8)))
    sheet.save(path)


def status():
    try:
        data = json.loads((runtime_dir() / "status.json").read_text())
    except (OSError, ValueError) as exc:
        print(f"no status: {exc}", file=sys.stderr)
        return 1
    age = time.time() - data.pop("updated", 0)
    for key, value in data.items():
        print(f"{key:>11}  {value}")
    print(f"{'age':>11}  {age:.1f}s")
    return 0 if age < 10 else 1


def control(words):
    try:
        send_control(runtime_dir() / "control", words)
    except OSError as exc:
        print(f"azoth-oled is not listening: {exc.strerror}", file=sys.stderr)
        return 1
    return 0


def run(args):
    from .engine import Engine

    engine = Engine(args.fps, os.environ.get("AZOTH_RGB", "1") == "1",
                    os.environ.get("AZOTH_RIPPLES", "1") == "1", args.rearm or None)
    signal.signal(signal.SIGTERM, lambda *_: engine.stop())
    signal.signal(signal.SIGINT, lambda *_: engine.stop())
    signal.signal(signal.SIGUSR1, lambda *_: engine.idle(True))
    signal.signal(signal.SIGUSR2, lambda *_: engine.idle(False))
    engine.run()
    return 0


def main():
    parser = argparse.ArgumentParser(prog="azoth-oled")
    commands = parser.add_subparsers(dest="command")
    daemon = commands.add_parser("run", help="drive the OLED and backlight")
    daemon.add_argument("--fps", type=float, default=float(os.environ.get("AZOTH_FPS") or 3.0))
    daemon.add_argument("--rearm", type=float, default=float(os.environ.get("AZOTH_REARM") or 0))
    shot = commands.add_parser("preview", help="render pages to a PNG contact sheet")
    shot.add_argument("png")
    shot.add_argument("--frames", type=int, default=2)
    shot.add_argument("--scale", type=int, default=4)
    shot.add_argument("--pages", default="board,agents,music,focus")
    commands.add_parser("status", help="print the running daemon's status")
    ctl = commands.add_parser("ctl", help="send a request: idle on|off, page NAME [SECONDS], rearm")
    ctl.add_argument("words", nargs="+")
    args = parser.parse_args()
    if args.command == "preview":
        preview(args.png, args.frames, args.scale, args.pages.split(","))
        return 0
    if args.command == "status":
        return status()
    if args.command == "ctl":
        return control(args.words)
    if args.command is None:
        args = parser.parse_args(["run", *sys.argv[1:]])
    return run(args)


sys.exit(main())
