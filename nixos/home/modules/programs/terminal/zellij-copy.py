import glob
import os
import re
import sys
import time

URL = re.compile(r"(?:https?|ftp)://[^\s\"\\<>]+")
BROKEN = re.compile(r"://[^\s]*(?:\s{2,}|\n)[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]")
EDGE = ".,;:!?)]}`\"'"
FILES = 8
TAIL = 262144
MAX_AGE = 604800


def transcript_files():
    patterns = (
        os.path.expanduser("~/.config/*claude*/projects/*/*.jsonl"),
        os.path.expanduser("~/.claude/projects/*/*.jsonl"),
    )
    found = {}
    now = time.time()
    for pattern in patterns:
        for path in glob.glob(pattern, recursive=True):
            try:
                stamp = os.stat(path).st_mtime
            except OSError:
                continue
            if now - stamp > MAX_AGE:
                continue
            real = os.path.realpath(path)
            if real not in found or stamp > found[real][0]:
                found[real] = (stamp, path)
    return [path for _, path in sorted(found.values(), reverse=True)[:FILES]]


def dump_tails():
    tails = []
    for path in transcript_files():
        try:
            with open(path, "rb") as handle:
                handle.seek(0, os.SEEK_END)
                size = handle.tell()
                handle.seek(max(0, size - TAIL))
                data = handle.read().decode("utf-8", "replace")
        except OSError:
            continue
        tails.append(data.replace("\\/", "/"))
    return tails


def known_urls():
    urls = []
    seen = set()
    for tail in dump_tails():
        for match in URL.finditer(tail):
            raw = match.group(0)
            for candidate in (raw, raw.rstrip(EDGE)):
                if len(candidate) < 16 or candidate in seen:
                    continue
                seen.add(candidate)
                urls.append(candidate)
    urls.sort(key=len, reverse=True)
    return urls


def repair(text, urls):
    compact = re.sub(r"\s+", "", text)
    for url in urls:
        if url not in compact:
            continue
        pattern = re.compile(r"\s*".join(re.escape(char) for char in url))

        def replace(match, clean=url):
            span = match.group(0)
            if "\n" in span or re.search(r"\s{2,}", span):
                return clean
            return span

        text = pattern.sub(replace, text)
    return text


def main():
    text = sys.stdin.read()
    text = "\n".join(line.rstrip() for line in text.split("\n"))
    if BROKEN.search(text):
        text = repair(text, known_urls())
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
