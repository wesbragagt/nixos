---
name: tasks
description: "Manage a spec.md + tasks.yaml task set: create it via the to-spec skill when missing, then list, inspect, and update task status. Use when given a spec path, PRD path, or feature description that needs task tracking."
---

# Task Breakdown and Tracking

Manage a `tasks.yaml` task set. Create it via the `to-spec` skill when one does not exist yet, then track status with the `wtask` CLI.

## Usage

The user provides either:
1. A **path** to an existing `spec.md`/`tasks.yaml` directory (or a legacy `prd.md`).
2. A **description string** for a new feature.

Optional: `--name <feature-name>` to override the auto-generated feature name.

If no name is provided, generate one from the first 4 words of the description, lowercase and hyphenated.

Example: "Build user authentication system" → `build-user-auth-system`

## Output Location

Specs live under `.specs/<feature-name>/`, resolved to the main checkout root when the current work is in a git worktree. See the `to-spec` skill for the exact resolution rule.

## File Naming

The task file is renamed automatically to reflect overall progress, so `ls` shows status at a glance:

- `tasks.yaml` — all tasks open
- `tasks.progress.yaml` — at least one task in progress or done (but not all done)
- `tasks.done.yaml` — all tasks done

Every `wtask` subcommand accepts any of the three filenames for a given task set and resolves to whichever actually exists on disk — you don't need to track the current name yourself.

## Task YAML Spec

```yaml
tasks:
  - key: task-name          # unique kebab-case identifier
    description: Brief description of the task
    details: ./task-name.md # path to detail file with implementation notes
    status: open            # open, progress, or done
    depends: []             # list of task keys this depends on
    requirements: []        # requirement IDs from spec.md
    acceptance: []          # acceptance IDs from spec.md
```

## Execution

### Phase 1: Locate or create the spec

- Path given and it contains `spec.md` and `tasks.yaml`: use it as-is, skip to Phase 2.
- Path given but only a legacy `prd.md` exists: treat it as input context for the `to-spec` skill and let it produce `spec.md`/`tasks.yaml` alongside it.
- No existing spec: invoke the `to-spec` skill with the feature name and description to produce `spec.md`, `tasks.yaml`, and the task packets.

**Delegation requirement:** do not draft the spec or task breakdown directly in this skill. Delegate spec and task creation to `to-spec`.

### Phase 2: Validate

```bash
wtask <output-dir>/tasks.yaml summary
```

Newly created task sets should show only `open` tasks.

## Task Management

```bash
# Summary of task statuses
wtask <path>/tasks.yaml summary

# List tasks (optionally filter by status)
wtask <path>/tasks.yaml list
wtask <path>/tasks.yaml list --status open

# View a single task
wtask <path>/tasks.yaml get <key>

# Update task status
wtask <path>/tasks.yaml set <key> progress
wtask <path>/tasks.yaml set <key> done

# Show tasks whose dependencies are all done
wtask <path>/tasks.yaml ready

# Verify all tasks are done (exit 0) or list incomplete (exit 1)
wtask <path>/tasks.yaml verify
```

## Output Format

```
✓ Tasks: .specs/<feature-name>/
  - spec.md
  - tasks.yaml (X tasks)
  - {X} task packets

Tasks:
  1. task-name-1 (no deps)
  2. task-name-2 (depends: task-name-1)
  ...

Next: /skill:code .specs/<feature-name>/tasks.yaml
```
