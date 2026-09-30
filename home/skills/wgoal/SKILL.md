---
name: wgoal
description: Run /code on a tasks.yaml in a loop until `wtask verify` reports every task done, a round cap is hit, a task is blocked, or a retry repeats the same failure. Use when the user types /wgoal or wants /code to keep going after a verifier FAIL or PARTIAL.
argument-hint: <path-to-tasks-yaml> [--max-rounds N]
---

Wrap the `code` skill in a goal loop. The goal is fixed: `wtask <path> verify` exits 0. A skill cannot start the built-in `/goal` command, so this skill keeps the loop itself.

## Usage

```
/wgoal <path-to-tasks-yaml> [--max-rounds N]
```

- `path-to-tasks-yaml`: required. `wtask` renames the file to `tasks.progress.yaml` or `tasks.done.yaml` as status changes, and it accepts any of the three names. Pass the path unchanged every round.
- `--max-rounds`: default is 3.

Read the `done` count from `wtask <path> summary` every time this skill mentions a done count.

A task's `details` path is relative to the tasks file's directory, not the current directory. A task with no `details` has no file to annotate: skip the file edits for it and keep the evidence in your report.

## Loop

1. Run `wtask <path> summary`. Report total, done, progress, and open counts. If it fails, report the error and stop.
2. Recover leftovers. Run `wtask <path> list --status progress`. Tasks already in `progress` come from a crashed or stopped earlier run, and `code` only picks up `open` tasks. For each one:
   - Run `wtask <path> set <key> open`.
   - Apply the retry note from step 8 with the verdict `none recorded (earlier run)`.
3. Set `round = 1`, `previous_failures = none`.
4. Invoke the `code` skill with the Skill tool, args `<path>`. It loads `code`'s instructions into this turn and does not return control by itself. When those instructions say to stop, report, or "allow user to retry", do not end the turn. Go to step 5.
5. Run `wtask <path> verify`.
   - Exit 0: report "goal met after N rounds" with the `wtask <path> summary` output and stop.
   - Non-zero: go to step 6.
6. Collect the failures. Run `wtask <path> list --status progress`. For each task, note its key and this round's verifier verdict (`FAIL`, `BLOCKED`, `PARTIAL`, or `none recorded` when no verifier ran, for example because the implementer errored). Call this set `failures`.
7. Decide whether to continue. Stop and report when any of these is true, checking in this order:
   - Any verdict is `BLOCKED`. Stopped because: `blocked`. A retry cannot fix a missing credential or an open question.
   - `round` equals the round cap. Stopped because: `round cap`.
   - `failures` equals `previous_failures` (the same keys with the same verdicts) and the done count did not rise. Stopped because: `same failure twice`. Round 1 never triggers this, because `previous_failures` is empty.

   Tasks that stay `open` only because a dependency failed are not failures. They run once the dependency passes.
8. Prepare the retry. For each task in `failures`:
   - Run `wtask <path> set <key> open`.
   - In the task's detail file, insert a section `## Previous attempt (round N)` immediately before the handoff record section. It holds the verifier's verdict, its evidence, and the files the implementer changed. If the file has no handoff record section, append the section at the end.
   - Prefix the body of the handoff record with `Superseded: round N failed verification.` The earlier implementer filled it in, and it claims work that did not pass.
   - Change nothing else in the file.
9. Set `previous_failures = failures`, increase `round` by 1, and return to step 4.

## Stop report

When the loop stops without meeting the goal, print:

```
Goal not met after N rounds.
Stopped because: <blocked | round cap | same failure twice>
Not done:
  <key>: <verifier verdict> - <one-line evidence>
Next: <one concrete command>
```

The next command depends on the reason:

- `blocked`: the step that removes the blocker, named from the verifier's evidence.
- `round cap`: `/wgoal <path> --max-rounds <N + 2>`
- `same failure twice`: read the task's detail file, then fix the cause by hand before you run `/wgoal <path>` again.

## Rules

- Never mark a task `done` here. Only `code`, after a verifier PASS, does that.
- Never edit `tasks.yaml` by hand. Use `wtask`.
- Do not run `code` in parallel with itself.
