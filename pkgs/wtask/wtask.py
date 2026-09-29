"""
Manage tasks.yaml task sets.

Usage:
  wtask <path> summary
  wtask <path> list [--status open|done|progress]
  wtask <path> get <key>
  wtask <path> set <key> <status>
  wtask <path> ready
  wtask <path> verify
"""

import argparse
import os
import sys

import yaml

RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"
DIM = "\033[2m"

STATUS_COLOR = {"done": GREEN, "progress": YELLOW, "open": CYAN}

STATUS_SUFFIXES = {
    "done": ".done.yaml",
    "progress": ".progress.yaml",
    "open": ".yaml",
}


def base_name(path: str) -> str:
    """Strip a known status suffix, returning the bare 'tasks' base path."""
    for suffix in (".done.yaml", ".progress.yaml", ".yaml"):
        if path.endswith(suffix):
            return path[: -len(suffix)]
    return path


def resolve(path: str) -> str:
    """Find the actual tasks file on disk, trying each status suffix."""
    base = base_name(path)
    for suffix in (".yaml", ".progress.yaml", ".done.yaml"):
        candidate = base + suffix
        if os.path.exists(candidate):
            return candidate
    return path


def overall_status(data: dict) -> str:
    tasks = data.get("tasks", [])
    statuses = {t.get("status", "open") for t in tasks}
    if tasks and statuses == {"done"}:
        return "done"
    if statuses & {"progress", "done"}:
        return "progress"
    return "open"


def load(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def save(path: str, data: dict) -> str:
    """Write data, renaming the file to match the task set's overall status.

    Returns the path the data now lives at.
    """
    target = base_name(path) + STATUS_SUFFIXES[overall_status(data)]
    tmp = target + ".tmp"
    with open(tmp, "w") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
    os.replace(tmp, target)
    if target != path and os.path.exists(path):
        os.remove(path)
    return target


def color_status(status: str) -> str:
    c = STATUS_COLOR.get(status, RESET)
    return f"{c}{status}{RESET}"


def cmd_summary(data: dict) -> None:
    tasks = data.get("tasks", [])
    counts = {"done": 0, "progress": 0, "open": 0}
    for t in tasks:
        counts[t.get("status", "open")] = counts.get(t.get("status", "open"), 0) + 1
    total = len(tasks)
    print(f"{BOLD}Tasks: {total}{RESET}")
    print(f"  {GREEN}done:     {counts['done']}{RESET}")
    print(f"  {YELLOW}progress: {counts['progress']}{RESET}")
    print(f"  {CYAN}open:     {counts['open']}{RESET}")


def cmd_list(data: dict, status_filter: str | None) -> None:
    tasks = data.get("tasks", [])
    for t in tasks:
        s = t.get("status", "open")
        if status_filter and s != status_filter:
            continue
        deps = t.get("depends", [])
        dep_str = f"  {DIM}← {', '.join(deps)}{RESET}" if deps else ""
        print(f"  {color_status(s):20}  {BOLD}{t['key']}{RESET}  {DIM}{t.get('description', '')}{RESET}{dep_str}")


def cmd_get(data: dict, key: str) -> None:
    tasks = data.get("tasks", [])
    for t in tasks:
        if t["key"] == key:
            print(yaml.safe_dump(t, sort_keys=False).rstrip())
            return
    print(f"{RED}Task not found: {key}{RESET}", file=sys.stderr)
    sys.exit(1)


def cmd_set(path: str, data: dict, key: str, status: str) -> None:
    valid = {"open", "progress", "done"}
    if status not in valid:
        print(f"{RED}Invalid status '{status}'. Must be one of: {', '.join(sorted(valid))}{RESET}", file=sys.stderr)
        sys.exit(1)
    tasks = data.get("tasks", [])
    for t in tasks:
        if t["key"] == key:
            old = t.get("status", "open")
            t["status"] = status
            new_path = save(path, data)
            print(f"{BOLD}{key}{RESET}: {color_status(old)} → {color_status(status)}")
            if new_path != path:
                print(f"{DIM}{os.path.basename(path)} → {os.path.basename(new_path)}{RESET}")
            return
    print(f"{RED}Task not found: {key}{RESET}", file=sys.stderr)
    sys.exit(1)


def cmd_ready(data: dict) -> None:
    tasks = data.get("tasks", [])
    done_keys = {t["key"] for t in tasks if t.get("status") == "done"}
    ready = [t for t in tasks if t.get("status") == "open" and all(d in done_keys for d in t.get("depends", []))]
    if not ready:
        print(f"{DIM}No ready tasks{RESET}")
        return
    for t in ready:
        deps = t.get("depends", [])
        dep_str = f"  {DIM}← {', '.join(deps)}{RESET}" if deps else f"  {DIM}(no deps){RESET}"
        print(f"  {BOLD}{t['key']}{RESET}  {DIM}{t.get('description', '')}{RESET}{dep_str}")


def cmd_verify(data: dict) -> None:
    tasks = data.get("tasks", [])
    not_done = [t for t in tasks if t.get("status") != "done"]
    if not not_done:
        print(f"{GREEN}All {len(tasks)} tasks done.{RESET}")
        sys.exit(0)
    print(f"{RED}{len(not_done)} task(s) not done:{RESET}", file=sys.stderr)
    for t in not_done:
        print(f"  {color_status(t.get('status', 'open'))}  {t['key']}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(prog="wtask", description="Manage tasks.yaml task sets")
    parser.add_argument("path", help="Path to tasks.yaml (or tasks.progress.yaml / tasks.done.yaml)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("summary")

    ls = sub.add_parser("list")
    ls.add_argument("--status", choices=["open", "done", "progress"])

    g = sub.add_parser("get")
    g.add_argument("key")

    s = sub.add_parser("set")
    s.add_argument("key")
    s.add_argument("status")

    sub.add_parser("ready")
    sub.add_parser("verify")

    args = parser.parse_args()
    args.path = resolve(args.path)
    data = load(args.path)

    match args.cmd:
        case "summary":
            cmd_summary(data)
        case "list":
            cmd_list(data, args.status)
        case "get":
            cmd_get(data, args.key)
        case "set":
            cmd_set(args.path, data, args.key, args.status)
        case "ready":
            cmd_ready(data)
        case "verify":
            cmd_verify(data)


if __name__ == "__main__":
    main()
