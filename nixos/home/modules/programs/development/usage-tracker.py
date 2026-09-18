#!/usr/bin/env python3
# usage-tracker — whole-usage tracker for a Claude Code provider variant
# (glm-claude, deepseek-claude, ...). Parametrized by --price-prefix so one
# script backs every variant instead of duplicating the transcript parsing.
#
# Reads every session transcript under the variant's projects/ dir and adds
# up token usage per assistant turn (message.usage). Two modes:
#   usage-tracker <prefix> report       -> all-time report (totals, by
#                                           day/project/model)
#   usage-tracker <prefix> statusline   -> compact "$X/wk $Y/mo" for the
#                                           Claude Code statusline (week
#                                           starts Saturday), cached + a
#                                           non-blocking background refresh
#                                           so the ~300ms statusline cadence
#                                           never stalls on the transcript scan.
#
# The transcripts are the source of truth — a provider's own stats-cache.json
# (when it has one) tends to be stale, report costUSD: 0, and double-count (it
# sums every logged copy of a response), so we parse + dedup the raw JSONL.
#
# Prices are Nix-configured per model: <PREFIX>_PRICES is a JSON object
# {model-name-or-prefix: {input, output, cache_read, cache_create, and
# optionally input_offpeak/output_offpeak/cache_read_offpeak/
# cache_create_offpeak}} in USD per 1M tokens. A record's model is matched
# against the longest key it starts with. When a model's entry carries
# *_offpeak fields, <PREFIX>_PEAK_UTC_HOURS ("1-4,6-10") and
# <PREFIX>_PEAK_WEEKDAYS ("0-4", Mon=0) pick peak vs. off-peak pricing from
# the turn's UTC timestamp; otherwise the base fields apply to every hour.
# The billing-month window start day comes from <PREFIX>_BILLING_DAY.
import argparse
import calendar
import json
import os
import subprocess
import sys
import time
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path


def find_config_dir(cli_dir, config_env_var, default_config_dir):
    if cli_dir:
        return Path(cli_dir).expanduser()
    for var in (config_env_var, "CLAUDE_CONFIG_DIR"):
        val = os.environ.get(var)
        if val:
            return Path(val).expanduser()
    return Path(default_config_dir).expanduser()


def cache_dir(label):
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return Path(base) / f"usage-tracker-{label}"


def parse_day(ts):
    """Local-date YYYY-MM-DD for an ISO-8601 timestamp (records store UTC)."""
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%d")
    except ValueError:
        return None


def parse_utc(ts):
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def iter_usage_records(projects_dir, min_mtime=None):
    """Yield one dict per assistant turn that carries token usage.

    min_mtime (epoch seconds) skips transcripts last modified before that
    moment — safe for recent-window sums since a transcript holding a record
    from day D must have been written on/after D. Keeps the statusline scan
    O(recent) instead of O(all history).
    """
    if not projects_dir.is_dir():
        return
    # Dedup: some providers log each assistant response several times under
    # one requestId — identical usage, milliseconds apart (a streaming/commit
    # artifact, not separate billed API calls). Summing every copy inflates
    # totals, so count each requestId once. Fall back to message.id, then
    # uuid, when requestId is absent.
    seen = set()
    for transcript in sorted(projects_dir.glob("*/*.jsonl")):
        if min_mtime is not None:
            try:
                if transcript.stat().st_mtime < min_mtime:
                    continue
            except OSError:
                continue
        project = transcript.parent.name
        try:
            with transcript.open("r", encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        rec = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if rec.get("type") != "assistant":
                        continue
                    msg = rec.get("message") or {}
                    usage = msg.get("usage")
                    if not usage:
                        continue
                    inp = usage.get("input_tokens", 0)
                    out = usage.get("output_tokens", 0)
                    cr = usage.get("cache_read_input_tokens", 0)
                    cc = usage.get("cache_creation_input_tokens", 0)
                    # Skip synthetic no-op turns (e.g. "<synthetic>" title
                    # generation) that carry zero tokens.
                    if not (inp or out or cr or cc):
                        continue
                    key = rec.get("requestId") or msg.get("id") or rec.get("uuid")
                    if key is not None:
                        if key in seen:
                            continue
                        seen.add(key)
                    ts = rec.get("timestamp")
                    stu = usage.get("server_tool_use") or {}
                    yield {
                        "day": parse_day(ts),
                        "ts": ts,
                        "model": msg.get("model", "unknown"),
                        "project": rec.get("cwd") or project,
                        "project_dir": project,
                        "session": rec.get("sessionId") or rec.get("session_id"),
                        "input": inp,
                        "output": out,
                        "cache_read": cr,
                        "cache_create": cc,
                        "web_search": int(stu.get("web_search_requests", 0) or 0)
                        + int(stu.get("web_fetch_requests", 0) or 0),
                    }
        except OSError:
            continue


def human(n):
    n = float(n)
    for unit in ("", "K", "M", "B", "T"):
        if abs(n) < 1000:
            return f"{n:.1f}{unit}".replace(".0", "", 1) if unit else f"{int(n)}"
        n /= 1000
    return f"{n:.1f}P"


def comma(n):
    return f"{n:,}"


def bar(value, max_value, width=24):
    if max_value <= 0:
        return ""
    filled = round(width * value / max_value)
    return "▇" * filled + "░" * (width - filled)


def pct(num, denom):
    if denom <= 0:
        return "0.0%"
    return f"{100.0 * num / denom:.1f}%"


def get_prices(price_prefix):
    """Per-model USD-per-1M-token price table from <PREFIX>_PRICES; None if unset/invalid."""
    raw = os.environ.get(f"{price_prefix}_PRICES")
    if not raw:
        return None
    try:
        table = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        print(f"usage-tracker: ignoring non-JSON {price_prefix}_PRICES", file=sys.stderr)
        return None
    return table if isinstance(table, dict) and table else None


def parse_hour_ranges(s):
    ranges = []
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        try:
            a, b = part.split("-")
            ranges.append((int(a), int(b)))
        except ValueError:
            continue
    return ranges


def parse_weekdays(s):
    days = set()
    for part in (s or "").split(","):
        part = part.strip()
        if not part:
            continue
        try:
            if "-" in part:
                a, b = part.split("-")
                days.update(range(int(a), int(b) + 1))
            else:
                days.add(int(part))
        except ValueError:
            continue
    return days


def get_peak_schedule(price_prefix):
    ranges = parse_hour_ranges(os.environ.get(f"{price_prefix}_PEAK_UTC_HOURS", ""))
    weekdays = parse_weekdays(os.environ.get(f"{price_prefix}_PEAK_WEEKDAYS", "0-6"))
    return ranges, weekdays


def is_peak(dt_utc, ranges, weekdays):
    if not ranges:
        return True
    if dt_utc is None:
        return True
    if weekdays and dt_utc.weekday() not in weekdays:
        return False
    return any(a <= dt_utc.hour < b for a, b in ranges)


def model_entry(prices, model):
    if not prices:
        return None
    if model in prices:
        return prices[model]
    best = None
    for key, entry in prices.items():
        if model.startswith(key) and (best is None or len(key) > len(best[0])):
            best = (key, entry)
    if best:
        return best[1]
    if len(prices) == 1:
        return next(iter(prices.values()))
    return None


def unit_price(entry, field, peak):
    if not peak:
        off = entry.get(f"{field}_offpeak")
        if off is not None:
            return off
    return entry.get(field, 0.0) or 0.0


def record_cost(r, prices, peak_ranges, peak_weekdays):
    entry = model_entry(prices, r["model"])
    if entry is None:
        return 0.0
    peak = is_peak(parse_utc(r["ts"]), peak_ranges, peak_weekdays)
    return (
        r["input"] * unit_price(entry, "input", peak) / 1_000_000
        + r["output"] * unit_price(entry, "output", peak) / 1_000_000
        + r["cache_read"] * unit_price(entry, "cache_read", peak) / 1_000_000
        + r["cache_create"] * unit_price(entry, "cache_create", peak) / 1_000_000
    )


def empty_totals():
    return defaultdict(float)


def add_totals(acc, r, prices, peak_ranges, peak_weekdays):
    for k in ("input", "output", "cache_read", "cache_create", "web_search"):
        acc[k] += r[k]
    acc["turns"] += 1
    if prices is not None:
        acc["cost"] += record_cost(r, prices, peak_ranges, peak_weekdays)


# ---------------------------------------------------------------------------
# report mode
# ---------------------------------------------------------------------------

def render_report(args, records, label, prices, peak_ranges, peak_weekdays):
    keep = []
    for r in records:
        day = r["day"]
        if args.since and (day is None or day < args.since):
            continue
        if args.until and (day is None or day > args.until):
            continue
        keep.append(r)
    if not keep:
        print("No usage records found in the selected window.")
        return

    totals = empty_totals()
    by_day = defaultdict(lambda: defaultdict(float))
    by_project = defaultdict(lambda: defaultdict(float))
    by_model = defaultdict(lambda: defaultdict(float))
    sessions, days = set(), set()
    first_day = last_day = None

    for r in keep:
        add_totals(totals, r, prices, peak_ranges, peak_weekdays)
        if r["day"]:
            days.add(r["day"])
            first_day = r["day"] if first_day is None else min(first_day, r["day"])
            last_day = r["day"] if last_day is None else max(last_day, r["day"])
            for k in ("input", "output", "cache_read", "cache_create"):
                by_day[r["day"]][k] += r[k]
        proj = r["project"] if args.project_cwd else r["project_dir"]
        for k in ("input", "output", "cache_read", "cache_create"):
            by_project[proj][k] += r[k]
        by_project[proj]["turns"] += 1
        for k in ("input", "output", "cache_read", "cache_create"):
            by_model[r["model"]][k] += r[k]
        by_model[r["model"]]["turns"] += 1
        if prices is not None:
            by_model[r["model"]]["cost"] += record_cost(r, prices, peak_ranges, peak_weekdays)
        if r["session"]:
            sessions.add(r["session"])

    totals["total"] = totals["input"] + totals["output"] + totals["cache_read"] + totals["cache_create"]
    input_side = totals["input"] + totals["cache_read"] + totals["cache_create"]

    if args.json:
        print(json.dumps({
            "totals": dict(totals),
            "cache_hit_ratio": (totals["cache_read"] / input_side) if input_side else 0,
            "sessions": len(sessions),
            "projects": len(by_project),
            "days": sorted(days),
            "by_day": {d: dict(v) for d, v in sorted(by_day.items())},
            "by_project": {p: dict(v) for p, v in by_project.items()},
            "by_model": {m: dict(v) for m, v in by_model.items()},
        }, indent=2))
        return

    span = f"{first_day} → {last_day}" if first_day else "(no timestamps)"
    print(f"\n  {label} usage   {span}")
    print(f"  {len(keep):,} assistant turns · {len(sessions)} sessions · {len(by_project)} projects\n")
    print("  TOTAL")
    print(f"    input        {human(totals['input']):>10}   {comma(int(totals['input']))}")
    print(f"    output       {human(totals['output']):>10}   {comma(int(totals['output']))}")
    print(f"    cache read   {human(totals['cache_read']):>10}   {comma(int(totals['cache_read']))}")
    print(f"    cache create {human(totals['cache_create']):>10}   {comma(int(totals['cache_create']))}")
    print(f"    {'─' * 44}")
    print(f"    total        {human(totals['total']):>10}   {comma(int(totals['total']))}")
    print(f"    cache hit    {pct(totals['cache_read'], input_side):>10}")
    if totals["web_search"]:
        print(f"    web searches {human(totals['web_search']):>10}")
    if prices is not None:
        print(f"    est. cost    ${totals['cost']:>9.2f}   (env {args.price_prefix}_PRICES)")
    else:
        print(f"    est. cost    (set {args.price_prefix}_PRICES to enable)")

    day_items = sorted(by_day.items())
    show_days = day_items if args.all_days else day_items[-args.days:]
    if show_days:
        print("\n  BY DAY" + ("" if args.all_days else f"  (last {len(show_days)}, --all-days for all)"))
        day_totals = [sum(v[k] for k in ("input", "output", "cache_read", "cache_create")) for _, v in show_days]
        mx = max(day_totals) if day_totals else 0
        for (day, v), dtotal in zip(show_days, day_totals):
            print(f"    {day}  {bar(dtotal, mx)}  {human(dtotal):>8}")

    proj_rows = sorted(
        by_project.items(),
        key=lambda kv: sum(kv[1][k] for k in ("input", "output", "cache_read", "cache_create")),
        reverse=True,
    )[: args.top]
    if proj_rows:
        print(f"\n  BY PROJECT  (top {len(proj_rows)}, --top N)")
        for proj, v in proj_rows:
            t = sum(v[k] for k in ("input", "output", "cache_read", "cache_create"))
            print(f"    {human(t):>8}  {int(v['turns']):>5} turns  {proj}")

    if len(by_model) > 1 or args.model:
        model_rows = sorted(
            by_model.items(),
            key=lambda kv: sum(kv[1][k] for k in ("input", "output", "cache_read", "cache_create")),
            reverse=True,
        )
        print("\n  BY MODEL")
        for model, v in model_rows:
            t = sum(v[k] for k in ("input", "output", "cache_read", "cache_create"))
            cost_suffix = f"  ${v['cost']:.2f}" if prices is not None else ""
            print(f"    {human(t):>8}  {int(v['turns']):>5} turns  {model}{cost_suffix}")
    print()


# ---------------------------------------------------------------------------
# statusline mode (Saturday-start week + billing-month, cached)
# ---------------------------------------------------------------------------

def get_billing_day(price_prefix):
    try:
        d = int(os.environ.get(f"{price_prefix}_BILLING_DAY", "1"))
        return d if 1 <= d <= 31 else 1
    except ValueError:
        return 1


def billing_month_start(today, day):
    """Most recent billing-cycle start: the `day`-th of the month on/before today.

    The billing month runs day-of-month → (day-1) of next month. `day` is
    clamped to the month's last day when it doesn't exist (e.g. 31 in Feb), and
    if this month's billing day hasn't arrived yet we roll back to last month's.
    """
    def clamp(y, m):
        last = calendar.monthrange(y, m)[1]
        return date(y, m, min(day, last))
    cand = clamp(today.year, today.month)
    if cand <= today:
        return cand
    py, pm = (today.year - 1, 12) if today.month == 1 else (today.year, today.month - 1)
    return clamp(py, pm)


def current_boundaries(billing_day):
    """(week_start_str, month_start_str, month_start_epoch) in local time.

    Week starts Saturday: shift back so the week's first day is the most recent
    Saturday (Saturday itself is day 0 of its week). Month starts on the
    configured billing day (<PREFIX>_BILLING_DAY).
    """
    today = date.today()
    days_since_sat = (today.weekday() - 5) % 7  # Mon=0..Sun=6, Sat=5
    week_start = today - timedelta(days=days_since_sat)
    month_start = billing_month_start(today, billing_day)
    month_epoch = datetime.combine(month_start, datetime.min.time()).timestamp()
    return week_start.strftime("%Y-%m-%d"), month_start.strftime("%Y-%m-%d"), month_epoch


def compute_window(projects_dir, billing_day, prices, peak_ranges, peak_weekdays):
    """Token+cost sums for the current week and current billing month."""
    week_start, month_start, month_epoch = current_boundaries(billing_day)
    week_epoch = datetime.strptime(week_start, "%Y-%m-%d").timestamp()
    # Scan transcripts modified since the EARLIER of the two window starts
    # (the week can begin before the billing month, e.g. week=Sat Aug 1 while
    # the billing month starts Aug 5). 1-day buffer for TZ skew vs the records'
    # UTC stamps.
    min_mtime = min(week_epoch, month_epoch) - 86400
    week = empty_totals()
    month = empty_totals()
    for r in iter_usage_records(projects_dir, min_mtime=min_mtime):
        d = r["day"]
        # Week and month are independent windows: the billing month can start
        # AFTER the Saturday week-start, so neither is a subset of the other —
        # sum them separately, not nested.
        if d and d >= week_start:
            add_totals(week, r, prices, peak_ranges, peak_weekdays)
        if d and d >= month_start:
            add_totals(month, r, prices, peak_ranges, peak_weekdays)
    return {
        "ts": time.time(),
        "week_start": week_start,
        "month_start": month_start,
        "week": dict(week),
        "month": dict(month),
    }


def read_cache(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def write_cache(path, data):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))
    except OSError:
        pass


def spawn_refresh(label, price_prefix):
    """Detach a background recompute so the statusline never blocks.

    A lockfile prevents pile-up if the statusline fires several times while a
    refresh is already running; the child removes it on completion.
    """
    lock = cache_dir(label) / ".refresh.lock"
    # Reclaim a lock abandoned by a refresh that crashed mid-scan.
    try:
        if time.time() - lock.stat().st_mtime > 60:
            os.unlink(lock)
    except OSError:
        pass
    try:
        fd = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.close(fd)
    except FileExistsError:
        return
    script = os.path.abspath(__file__)
    try:
        subprocess.Popen(
            [sys.executable, script, price_prefix, "statusline", "--refresh"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
            env=os.environ.copy(),
        )
    except OSError:
        try:
            os.unlink(lock)
        except OSError:
            pass


def fmt_window(totals, prices):
    if prices is not None:
        return f"${totals.get('cost', 0.0):.2f}"
    t = totals["input"] + totals["output"] + totals["cache_read"] + totals["cache_create"]
    return human(t)


def render_statusline(args, projects_dir, label, price_prefix, prices, peak_ranges, peak_weekdays):
    path = cache_dir(label) / "statusline.json"
    billing_day = get_billing_day(price_prefix)
    week_start, month_start, _ = current_boundaries(billing_day)

    if args.refresh:
        lock = cache_dir(label) / ".refresh.lock"
        try:
            data = compute_window(projects_dir, billing_day, prices, peak_ranges, peak_weekdays)
            write_cache(path, data)
            print(f"wk {fmt_window(data['week'], prices)} mo {fmt_window(data['month'], prices)}")
        finally:
            # Release the lock the parent acquired in spawn_refresh(). Best-effort:
            # a manual `--refresh` (no lock) just no-ops here.
            try:
                os.unlink(lock)
            except OSError:
                pass
        return

    cache = read_cache(path)
    fresh = (
        cache is not None
        and (time.time() - cache.get("ts", 0)) < args.ttl
        and cache.get("week_start") == week_start
        and cache.get("month_start") == month_start
    )
    if cache and fresh:
        print(f"wk {fmt_window(cache['week'], prices)} mo {fmt_window(cache['month'], prices)}")
        return
    if cache:
        # Stale but present: show it now, refresh in the background.
        print(f"wk {fmt_window(cache['week'], prices)} mo {fmt_window(cache['month'], prices)}")
        spawn_refresh(label, price_prefix)
        return
    # No cache yet: compute once synchronously (first ever run).
    data = compute_window(projects_dir, billing_day, prices, peak_ranges, peak_weekdays)
    write_cache(path, data)
    print(f"wk {fmt_window(data['week'], prices)} mo {fmt_window(data['month'], prices)}")


def main():
    ap = argparse.ArgumentParser(
        prog="usage-tracker",
        description="Track whole token usage for a Claude Code provider variant (parses session transcripts).",
    )
    ap.add_argument("price_prefix", help="env var prefix, e.g. GLM or DEEPSEEK (reads <PREFIX>_PRICES etc.)")
    ap.add_argument("command", nargs="?", choices=["report", "statusline"], default="report",
                    help="report (default) or statusline")
    ap.add_argument("--label", default=None, help="display label (default: price_prefix lowercased)")
    ap.add_argument("--config-env-var", default=None, help="env var naming the config dir (falls back to CLAUDE_CONFIG_DIR)")
    ap.add_argument("--default-config-dir", default="~/.claude", help="config dir if no env var is set")
    ap.add_argument("--config-dir", help="override the config dir directly")
    # report options
    ap.add_argument("--since", help="start date YYYY-MM-DD (inclusive)")
    ap.add_argument("--until", help="end date YYYY-MM-DD (inclusive)")
    ap.add_argument("--days", type=int, default=14, help="days to show in BY DAY (default 14)")
    ap.add_argument("--all-days", action="store_true", help="show every day in BY DAY")
    ap.add_argument("--top", type=int, default=10, help="projects to list (default 10)")
    ap.add_argument("--model", action="store_true", help="always show BY MODEL section")
    ap.add_argument("--project-cwd", action="store_true", help="label projects by cwd instead of dir name")
    ap.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    # statusline options
    ap.add_argument("--refresh", action="store_true", help="statusline: force a synchronous recompute")
    ap.add_argument("--ttl", type=int, default=300, help="statusline cache TTL seconds (default 300)")
    args = ap.parse_args()

    label = args.label or args.price_prefix.lower()
    config_env_var = args.config_env_var or f"{args.price_prefix}_CLAUDE_CONFIG_DIR"
    cfg = find_config_dir(args.config_dir, config_env_var, args.default_config_dir)
    projects_dir = cfg / "projects"
    prices = get_prices(args.price_prefix)
    peak_ranges, peak_weekdays = get_peak_schedule(args.price_prefix)

    if not projects_dir.is_dir():
        if args.command == "statusline":
            # A missing projects dir (fresh machine) is not worth a stderr
            # banner on every statusline tick — just stay silent.
            return
        print(f"usage-tracker: no projects/ dir at {projects_dir}", file=sys.stderr)
        sys.exit(1)

    try:
        if args.command == "statusline":
            render_statusline(args, projects_dir, label, args.price_prefix, prices, peak_ranges, peak_weekdays)
        else:
            records = list(iter_usage_records(projects_dir))
            render_report(args, records, label, prices, peak_ranges, peak_weekdays)
    except Exception:  # statusline must never spew a traceback
        if args.command == "statusline":
            return
        raise


if __name__ == "__main__":
    main()
