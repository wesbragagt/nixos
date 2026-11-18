---
name: to-spec
description: "Create an implementation-ready specification and task set that preserve requirements when agents receive only one task file. Use when the user wants to specify, plan, write requirements, or break a feature into tasks."
argument-hint: <feature-name> --description "<description>" [--context "<context>"] [--quick]
---

# To-spec

Create a durable specification for a feature. The files must let an implementation agent complete any assigned task without lost context.

## Inputs

Parse these values from the user request:

- `feature-name`: required kebab-case identifier.
- `description`: required feature request.
- `context`: optional constraints, decisions, and known facts.
- `--quick`: skip external research. Still inspect relevant repository patterns.

Ask only for a decision that changes user-visible behavior or scope. Record the decision before task breakdown.

## Output location

Run `git rev-parse --git-common-dir` and `git rev-parse --show-toplevel`.

- Not in a worktree (common dir resolves under the current checkout): write specs under `./.specs/<feature-name>/` in the current repository root.
- In a linked worktree (common dir resolves to a different, main checkout): write specs under `<main-checkout-root>/.specs/<feature-name>/`, not inside the worktree. Find the main checkout root from the common dir's parent. Create `.specs/` there if missing.

State the resolved output path to the user before writing files.

Write:

- `spec.md`: agreed high-level specification, at most 500 words total.
- `tasks.yaml`: ordered implementation tasks.
- `<task-key>.md`: a standalone implementation packet for each task.

Do not overwrite an existing specification without user permission.

## Workflow

### 1. Gather evidence

Inspect the repository for affected behavior, existing conventions, public interfaces, tests, and migration constraints. Research external behavior when the request depends on it. Separate verified facts from assumptions.

When `--quick` is set, do not use external research. Repository inspection remains required when a repository exists.

### 2. Resolve ambiguity early

List material ambiguities. A material ambiguity changes the scope, interface, user behavior, compatibility, security, data retention, or acceptance check.

Resolve it from user input or repository evidence. Ask the user only when evidence cannot resolve it. Do not hide a material ambiguity in a task.

### 3. Write `spec.md`

Write a high-level record of the agreed specification in **500 words or fewer total**. Count the entire file, including headings, tables, links and code blocks, using whitespace-separated words. The limit applies after every revision.

Use only the sections needed to cover these points:

- Problem, intended outcome and affected users.
- Agreed scope and observable requirements.
- Decisions, essential constraints and compatibility expectations.
- Concise acceptance criteria describing the intended outcome.
- Any unresolved questions, named owners and affected scope. Distinguish assumptions and proposals from agreed decisions.

State what must happen and why. Keep requirements testable and preserve every material agreement. Put implementation contracts, detailed behavior flows, repository findings, commands and full acceptance checks in the relevant task packets. Identify tasks by `key` and use `details` to locate their standalone packets.

After creating the task packets, add a `Task matrix` section to `spec.md`. Include one row per task with execution order, task key, complexity and a relative link to its detail file. Follow dependency order. Tasks that can run together share an order number. Keep the matrix consistent with `tasks.yaml` and include it in the 500-word total.

Condense repetition and move supporting detail into task packets until the file fits the limit. Keep agreed scope, decisions and high-level acceptance criteria in `spec.md`. Do not invent requirements or depend on the chat transcript.

### 4. Create self-contained task packets

Break the specification into minimal, dependency-ordered tasks. Each task file must be complete when read alone after the agent has lost all prior conversation context.

Every `<task-key>.md` must contain:

1. **Objective**: one clear outcome.
2. **Context snapshot**: the problem, domain terms, constraints, decisions, relevant current facts, and assumptions needed for this task.
3. **Dependencies**: required completed tasks, produced interfaces, and files or states they establish.
4. **Scope**: included work and explicit exclusions.
5. **Implementation contract**: required inputs, outputs, state changes, errors, compatibility rules, and integration boundaries.
6. **Repository guidance**: relevant paths and existing patterns, or an explicit statement that no pattern was found.
7. **Acceptance checks**: exact observable checks for the task outcome.
8. **Handoff record**: files changed, decisions made, interfaces produced, verification run, and remaining risks. The implementing agent must update it before marking the task done.

Repeat critical constraints in every affected task file. Do not use phrases such as "as described above", "see the previous task", or references to unavailable chat context. A task may link to `spec.md`, but the task packet must copy all information needed to act safely.

Use this YAML schema:

```yaml
tasks:
  - key: task-name
    description: Implement one observable outcome
    details: ./task-name.md
    status: open
    complexity: moderate
    depends: []
```

Before writing each task's complexity, use the shared `dx-router` skill on a concise summary of the completed task packet. Include its objective, constraints, affected components and acceptance checks. Set `complexity` to the returned `easy`, `moderate` or `hard` label. Repeat the label and a short explanation in the task packet's context snapshot so a standalone packet preserves it. Classify again if the task scope changes.

If the classifier is unavailable or rejects the input, record `moderate` as a provisional fallback and state the classification failure in the context snapshot and delivery. A fallback label must remain identifiable for later reclassification.

Task rules:

- A task has one clear completion state.
- Dependencies name only existing task keys.
- No task depends on an unstated chat decision.
- Use `key` and `details` to identify each task and its packet. Keep acceptance checks in the packet.
- Split a task when independent ownership, verification, or rollback is unclear.

### 5. Validate before delivery

Verify all of the following:

- `spec.md` records the agreed high-level specification and contains at most 500 words total.

- Every material user request appears in scope, a requirement, or a recorded non-goal.
- Task packets collectively cover the agreed scope and contain observable acceptance checks.
- Each task packet contains all eight required sections.
- Task packets repeat their required constraints and do not rely on prior chat context.
- All dependency keys and detail paths resolve.
- The task matrix matches task keys, complexity and detail paths in `tasks.yaml`, with dependency-safe execution order.
- Every task has `complexity: easy`, `complexity: moderate` or `complexity: hard`, repeated in its packet with the reason or provisional fallback status.
- Open questions have owners and affected scope.
- The resolved output path is under the main checkout's `.specs/` when the current work is in a worktree.

Run the word-count check and task summary:

```bash
python3 -c 'from pathlib import Path; import sys; count = len(Path(sys.argv[1]).read_text().split()); print(f"{count}/500 words"); sys.exit(count > 500)' <output-dir>/spec.md
wtask <output-dir>/tasks.yaml summary
```

The summary must show only `open` tasks.

### 6. Open for review

Open a new tmux window in the current session with nvim on the spec and tasks so the user can review them immediately:

```bash
tmux new-window -t "$(tmux display-message -p '#S')" -n review "nvim '<output-dir>/spec.md' '<output-dir>/tasks.yaml'"
```

Skip this step when not running inside tmux (`echo "$TMUX"` is empty).

## Delivery format

Report the resolved output path (noting when it was redirected to the main checkout), task count, unresolved questions, and the first ready task. Do not claim an assumption is a decision.

End with the exact commands to run the tasks, using the resolved absolute path to `tasks.yaml` (the main checkout path when redirected from a worktree). Offer both:

1. `/code <output-dir>/tasks.yaml` runs each task once, then stops.
2. `/wgoal <output-dir>/tasks.yaml` runs `/code` in a loop until `wtask` reports every task done. It retries failed tasks with the verifier's evidence, up to 3 rounds. Add `--max-rounds N` to change the cap. Add `-s` (or `--session`) to implement the tasks in the current session instead of dispatching subagents.

Recommend option 1 when the task count is 3 or fewer, and option 2 otherwise. Both commands are for Claude Code. OMP disables the `code` skill.

Example:

```text
Created: <main-checkout-root>/.specs/<feature-name>/ (redirected from worktree)
- spec.md
- tasks.yaml (4 open tasks)
- 4 standalone task packets

Open questions: none
First ready task: define-domain-model

Run the tasks (4 tasks, so use the loop form):
/wgoal /home/me/repo/.specs/<feature-name>/tasks.yaml
```
