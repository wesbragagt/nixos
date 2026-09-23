"""schedules - register shell commands with cron and watch them in tmux.

One JSON file per job. The crontab only ever calls `schedules run <name>`,
so the command cron runs is the same command a user or agent tests by hand.
All environment knowledge (tmux socket, working directory, logging) lives in
`run`, never in the crontab line.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

BEGIN = "# BEGIN schedules (managed by the schedules CLI)"
END = "# END schedules"
SESSION = os.environ.get("SCHEDULES_SESSION", "schedules")


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or f"{Path.home()}/.local/state"
    return Path(base) / "schedules"


def jobs_dir() -> Path:
    d = state_dir() / "jobs"
    d.mkdir(parents=True, exist_ok=True)
    return d


def logs_dir() -> Path:
    d = state_dir() / "logs"
    d.mkdir(parents=True, exist_ok=True)
    return d


def die(message: str) -> None:
    print(f"schedules: {message}", file=sys.stderr)
    raise SystemExit(1)


def job_path(name: str) -> Path:
    return jobs_dir() / f"{name}.json"


def load_job(name: str) -> dict:
    path = job_path(name)
    if not path.is_file():
        die(f"no such job: {name}")
    return json.loads(path.read_text())


def crontab_bin() -> str:
    # The system crontab is setuid-wrapped. The plain binary cannot write the
    # spool, so prefer the wrapper when NixOS provides it.
    wrapper = "/run/wrappers/bin/crontab"
    if os.access(wrapper, os.X_OK):
        return wrapper
    found = shutil.which("crontab")
    if not found:
        die("crontab not found; is services.cron enabled?")
    return found


def self_path() -> str:
    # Stable across rebuilds, unlike a /nix/store path.
    return f"/etc/profiles/per-user/{os.environ.get('USER') or Path.home().name}/bin/schedules"


def read_crontab() -> list:
    result = subprocess.run(
        [crontab_bin(), "-l"], capture_output=True, text=True, check=False
    )
    return result.stdout.splitlines() if result.returncode == 0 else []


def sync() -> None:
    """Rewrite only the block we own. Hand-written crontab lines survive."""
    kept, skipping = [], False
    for line in read_crontab():
        if line.startswith(BEGIN):
            skipping = True
        elif line.startswith(END):
            skipping = False
        elif not skipping:
            kept.append(line)

    while kept and not kept[-1].strip():
        kept.pop()

    block = [BEGIN]
    for path in sorted(jobs_dir().glob("*.json")):
        job = json.loads(path.read_text())
        block.append(f"{job['schedule']} {self_path()} run {path.stem}")
    block.append(END)

    text = "\n".join(kept + block) + "\n"
    subprocess.run([crontab_bin(), "-"], input=text, text=True, check=True)


def tmux_env() -> dict:
    env = dict(os.environ)
    runtime = env.get("TMUX_TMPDIR") or f"/run/user/{os.getuid()}"
    if not Path(runtime).is_dir():
        die(f"TMUX_TMPDIR {runtime} is missing; is the user session running?")
    env["TMUX_TMPDIR"] = runtime
    return env


def tmux(args: list, env: dict, check: bool = True):
    return subprocess.run(["tmux", *args], env=env, check=check, capture_output=True)


def dispatch_tmux(name: str, job: dict, log: Path) -> None:
    """Put the job in a window of the shared session, one window per job."""
    env = tmux_env()
    body = (
        f'{{ echo "[schedules {name}] $(date -Is)"; {job["command"]}; '
        f'echo "[schedules {name}] exit $?"; }} 2>&1 | tee -a {log}; exec $SHELL'
    )
    has = tmux(["has-session", "-t", f"={SESSION}"], env, check=False)
    if has.returncode == 0:
        tmux(["kill-window", "-t", f"={SESSION}:={name}"], env, check=False)
        tmux(["new-window", "-d", "-t", f"={SESSION}:", "-n", name, "-c", job["cwd"], body], env)
    else:
        tmux(["new-session", "-d", "-s", SESSION, "-n", name, "-c", job["cwd"], body], env)
    print(f"started tmux window {SESSION}:{name}")


def run_inline(name: str, job: dict, log: Path) -> int:
    header = f"[schedules {name}] {datetime.now().astimezone().isoformat()}"
    result = subprocess.run(
        job["command"], shell=True, cwd=job["cwd"],
        capture_output=True, text=True,
    )
    output = f"{header}\n{result.stdout}{result.stderr}[schedules {name}] exit {result.returncode}\n"
    with log.open("a") as handle:
        handle.write(output)
    print(output, end="")
    return result.returncode


def cmd_add(args) -> None:
    if len(args.schedule.split()) != 5:
        die(f"--schedule needs 5 fields, got: {args.schedule}")
    cwd = Path(args.cwd).resolve()
    if not cwd.is_dir():
        die(f"--cwd is not a directory: {cwd}")

    job_path(args.name).write_text(json.dumps({
        "schedule": args.schedule,
        "command": args.command,
        "cwd": str(cwd),
        "tmux": args.tmux,
    }, indent=2) + "\n")
    sync()
    print(f"added {args.name}: {args.schedule} -> {args.command} (cwd {cwd}, tmux {args.tmux})")


def cmd_remove(args) -> None:
    load_job(args.name)
    job_path(args.name).unlink()
    sync()
    print(f"removed {args.name}")


def cmd_list(args) -> None:
    paths = sorted(jobs_dir().glob("*.json"))
    if not paths:
        print("no jobs")
        return
    for path in paths:
        job = json.loads(path.read_text())
        print(f"{path.stem}\t{job['schedule']}\t{job['command']}\t"
              f"[cwd {job['cwd']}]\t[tmux {job['tmux']}]")


def cmd_show(args) -> None:
    print(json.dumps(load_job(args.name), indent=2))


def cmd_logs(args) -> None:
    log = logs_dir() / f"{args.name}.log"
    load_job(args.name)
    if not log.is_file():
        die(f"no log yet for {args.name}; run: schedules run {args.name}")
    print(log.read_text(), end="")


def cmd_run(args) -> None:
    job = load_job(args.name)
    log = logs_dir() / f"{args.name}.log"
    if job["tmux"]:
        dispatch_tmux(args.name, job, log)
    else:
        raise SystemExit(run_inline(args.name, job, log))


def cmd_sync(args) -> None:
    sync()
    print("crontab synced")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="schedules",
        description="Schedule a shell command with cron and watch it in tmux.",
    )
    sub = parser.add_subparsers(dest="action", required=True)

    add = sub.add_parser("add", help="create or replace a job")
    add.add_argument("name")
    add.add_argument("--schedule", required=True, metavar='"m h dom mon dow"')
    add.add_argument("--command", required=True)
    add.add_argument("--cwd", default=os.getcwd())
    add.add_argument("--tmux", action="store_true",
                     help=f"run as a window in the shared '{SESSION}' tmux session")
    add.set_defaults(func=cmd_add)

    for name, func, help_text in [
        ("run", cmd_run, "run the job now, exactly as cron will"),
        ("show", cmd_show, "print the job definition"),
        ("logs", cmd_logs, "print collected output"),
        ("remove", cmd_remove, "delete the job"),
    ]:
        item = sub.add_parser(name, help=help_text)
        item.add_argument("name")
        item.set_defaults(func=func)

    sub.add_parser("list", help="list every job").set_defaults(func=cmd_list)
    sub.add_parser("sync", help="rewrite the crontab from the job files").set_defaults(func=cmd_sync)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
