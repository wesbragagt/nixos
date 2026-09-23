---
name: schedules
description: Schedule a recurring shell command with cron using the `schedules` CLI, and watch it run in a tmux window. Use when the user wants a cron job, a recurring or periodic task, a nightly or hourly script, or asks to list, test, inspect, or remove scheduled jobs.
argument-hint: "[what to run, and how often]"
---

# Scheduled jobs

Register recurring shell commands with cron through the `schedules` CLI. Never
edit the crontab by hand, and never run `rebuild` for a job. Jobs take effect
at once.

## Commands

```bash
schedules add <name> --schedule "0 3 * * *" --command "./scripts/sync.sh" --cwd /path/to/project
schedules run <name>      # run now, with the environment cron uses
schedules logs <name>     # collected output
schedules list            # every job
schedules show <name>     # the job definition
schedules remove <name>
schedules sync            # rewrite the crontab from the job files
```

## Rules

1. Always run `schedules run <name>` after `add`. Report the job as done only
   when that run succeeds. Do not wait for the clock.
2. `--schedule` takes the 5 standard cron fields: minute, hour, day of month,
   month, day of week. The CLI rejects any other field count.
3. `--cwd` defaults to the current directory. Pass it when the command uses a
   relative path.
4. Use a clear job name. The name is the key, the tmux window name, and the log
   file name. `add` with an existing name replaces that job.
5. Do not put `cd`, absolute binary paths, or redirection in `--command`. The
   CLI supplies the working directory and collects the output.

## tmux mode

Add `--tmux` to run the job as a window named `<name>` inside one shared tmux
session called `schedules`.

```bash
schedules add backup --schedule "0 2 * * *" --command "./backup.sh" --cwd ~/work --tmux
tmux attach -t schedules
```

Each run replaces that job's window. Other jobs are untouched. Output still
reaches the log file, so a closed window loses nothing.

Use `--tmux` for a job the user wants to watch or interact with. Leave it off
for a quiet background job.

## Where things live

| Item | Path |
|---|---|
| Job definitions | `~/.local/state/schedules/jobs/<name>.json` |
| Logs | `~/.local/state/schedules/logs/<name>.log` |
| Crontab block | between `# BEGIN schedules` and `# END schedules` |

The CLI owns only that crontab block. Hand-written crontab lines survive a sync.

## Troubleshooting

- `crontab not found`: cron is off on this host. It is a NixOS setting in
  `modules/cron.nix`, and it needs a `rebuild`.
- `TMUX_TMPDIR ... is missing`: no user session is running. The host needs
  `users.users.<user>.linger = true`.
- A job does nothing at its time: run `schedules run <name>` and read the error.
  Then check `crontab -l` for the line.
