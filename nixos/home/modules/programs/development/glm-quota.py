#!/usr/bin/env python3
"""Compact, cached GLM Coding Plan quota meters for the Claude statusline."""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


DEFAULT_URL = "https://api.z.ai/api/monitor/usage/quota/limit"
WINDOWS = {
    ("TOKENS_LIMIT", 3, 5): "five_hour",
    ("CREDIT_LIMIT", 3, 5): "five_hour",
    ("TOKENS_LIMIT", 6, 1): "weekly",
    ("CREDIT_LIMIT", 6, 1): "weekly",
}


def cache_path():
    root = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return Path(root) / "glm-quota" / "statusline.json"


def auth_token():
    token = os.environ.get("ANTHROPIC_AUTH_TOKEN", "").strip()
    if token:
        return token
    key_file = os.environ.get("GLM_KEY_FILE") or os.path.expanduser("~/glm-key")
    try:
        return Path(key_file).read_text().strip()
    except OSError:
        return ""


def team_context():
    organization = os.environ.get("GLM_TEAM_ORGANIZATION", "").strip()
    project = os.environ.get("GLM_TEAM_PROJECT", "").strip()
    if bool(organization) != bool(project):
        raise ValueError("GLM team quota requires both organization and project")
    return organization, project


def scope_key():
    organization, project = team_context()
    if not organization:
        return "personal"
    value = f"{organization}\0{project}".encode()
    return "team:" + hashlib.sha256(value).hexdigest()


def used_percentage(limit):
    """Prefer quota counts over the rounded percentage when both are present."""
    try:
        total = float(limit.get("usage"))
        candidates = []
        if limit.get("currentValue") is not None:
            candidates.append(float(limit["currentValue"]))
        if limit.get("remaining") is not None:
            candidates.append(total - float(limit["remaining"]))
        if total > 0 and candidates:
            return max(0.0, min(100.0, max(candidates) * 100.0 / total))
    except (TypeError, ValueError):
        pass
    try:
        return max(0.0, min(100.0, float(limit["percentage"])))
    except (KeyError, TypeError, ValueError):
        return None


def parse_quota(payload):
    """Extract only recognized subscription windows from a Z.ai response."""
    if not isinstance(payload, dict):
        return {}
    if payload.get("success") is not True or payload.get("code") != 200:
        return {}
    limits = (payload.get("data") or {}).get("limits")
    if not isinstance(limits, list):
        return {}

    quota = {}
    for limit in limits:
        if not isinstance(limit, dict):
            continue
        key = WINDOWS.get((limit.get("type"), limit.get("unit"), limit.get("number")))
        if key is None and (
            limit.get("type"), limit.get("unit"), limit.get("number")
        ) == ("TIME_LIMIT", 5, 1):
            key = "monthly_mcp"
        if key is None:
            continue
        pct = used_percentage(limit)
        if pct is not None:
            quota[key] = pct
    return quota


def fetch_quota(url, token):
    organization, project = team_context()

    headers = {
        "Accept": "application/json",
        "Accept-Language": "en-US,en",
        "Authorization": token,
        "Content-Type": "application/json",
    }
    if organization and project:
        parsed = urllib.parse.urlsplit(url)
        query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
        query = [(key, value) for key, value in query if key != "type"]
        query.append(("type", "2"))
        url = urllib.parse.urlunsplit(parsed._replace(query=urllib.parse.urlencode(query)))
        headers["Bigmodel-Organization"] = organization
        headers["Bigmodel-Project"] = project

    req = urllib.request.Request(
        url,
        headers=headers,
    )
    with urllib.request.urlopen(req, timeout=5) as response:
        payload = json.loads(response.read().decode("utf-8", "replace"))
    return parse_quota(payload)


def read_cache(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else None
    except (OSError, ValueError):
        return None


def write_cache(path, data):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))
    except OSError:
        pass


def format_meter(label, percentage):
    pct = max(0, min(100, int(percentage)))
    filled = pct * 5 // 100
    return f"{label} {'█' * filled}{'░' * (5 - filled)}{pct}%"


def format_statusline(quota):
    parts = []
    for key, label in (("five_hour", "5h"), ("weekly", "wk"), ("monthly_mcp", "mcp/mo")):
        if key in quota:
            parts.append(format_meter(label, quota[key]))
    return "  ".join(parts)


def refresh(path, url, token):
    scope = scope_key()
    previous = read_cache(path) or {}
    try:
        quota = fetch_quota(url, token)
    except (urllib.error.URLError, ValueError, OSError, TypeError, AttributeError):
        quota = previous.get("quota", {}) if previous.get("scope") == scope else {}
    data = {"ts": time.time(), "scope": scope, "quota": quota}
    write_cache(path, data)
    return data


def spawn_refresh(path):
    lock = path.with_suffix(".lock")
    try:
        if time.time() - lock.stat().st_mtime > 60:
            lock.unlink()
    except OSError:
        pass
    try:
        fd = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.close(fd)
    except FileExistsError:
        return
    try:
        subprocess.Popen(
            [sys.executable, os.path.abspath(__file__), "--refresh", "--lock", str(lock)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            env=os.environ.copy(),
        )
    except OSError:
        try:
            lock.unlink()
        except OSError:
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--lock")
    args = parser.parse_args()

    token = auth_token()
    if not token:
        return
    url = os.environ.get("GLM_QUOTA_URL", DEFAULT_URL)
    path = cache_path()
    scope = scope_key()

    if args.refresh:
        try:
            data = refresh(path, url, token)
            print(format_statusline(data.get("quota", {})))
        finally:
            if args.lock:
                try:
                    Path(args.lock).unlink()
                except OSError:
                    pass
        return

    data = read_cache(path)
    if data is None or data.get("scope") != scope:
        # Never make Claude wait on the network. Seed the cache so the lock's
        # parent exists, then let a detached refresh populate it.
        data = {"ts": 0, "scope": scope, "quota": {}}
        write_cache(path, data)
        spawn_refresh(path)
    elif time.time() - data.get("ts", 0) >= 300:
        spawn_refresh(path)
    print(format_statusline(data.get("quota", {})))


if __name__ == "__main__":
    main()
