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

- `spec.md`: source of truth for scope, behavior, and decisions.
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

Use the following structure. Keep each requirement atomic and assign a stable identifier such as `FR-01`, `NFR-01`, or `AC-01`.

1. **Problem and outcome**: user problem, affected users, and intended result.
2. **Scope**: included behavior and explicit non-goals.
3. **Definitions and actors**: terms, roles, states, and data concepts that have more than one possible meaning.
4. **Current facts**: repository or research facts with source paths or URLs. Mark unverified statements as assumptions.
5. **Requirements**: functional and non-functional requirements. State observable behavior, trigger, expected result, errors, and constraints.
6. **Behavior flows**: normal flow, failure flow, boundary cases, and state transitions.
7. **Compatibility and migration**: existing behavior, consumers, data, configuration, and removal requirements.
8. **Decisions and open questions**: decision, rationale, source, owner, and status. An open question must name the blocked requirement.
9. **Acceptance criteria**: observable pass/fail statements. Map every criterion to one or more requirement identifiers.
10. **Traceability matrix**: map each requirement to acceptance criteria and task keys.

Specification rules:

- State what must happen and why. Put implementation choices only where they constrain compatibility, safety, or required integration.
- Use testable language. Avoid vague words such as "fast", "easy", "robust", and "appropriate" without a measurable condition.
- Define default behavior, invalid input behavior, empty states, authorization, concurrency, retries, and rollback when they apply.
- Do not invent requirements. Keep assumptions visible until resolved.
- Keep decisions in this file. Do not depend on the chat transcript for decisions or constraints.

### 4. Create self-contained task packets

Break the specification into minimal, dependency-ordered tasks. Each task file must be complete when read alone after the agent has lost all prior conversation context.

Every `<task-key>.md` must contain:

1. **Objective**: one outcome and its requirement identifiers.
2. **Context snapshot**: the problem, domain terms, constraints, decisions, relevant current facts, and assumptions needed for this task.
3. **Dependencies**: required completed tasks, produced interfaces, and files or states they establish.
4. **Scope**: included work and explicit exclusions.
5. **Implementation contract**: required inputs, outputs, state changes, errors, compatibility rules, and integration boundaries.
6. **Repository guidance**: relevant paths and existing patterns, or an explicit statement that no pattern was found.
7. **Acceptance checks**: exact observable checks mapped to the specification acceptance criteria.
8. **Handoff record**: files changed, decisions made, interfaces produced, verification run, and remaining risks. The implementing agent must update it before marking the task done.

Repeat critical constraints in every affected task file. Do not use phrases such as "as described above", "see the previous task", or references to unavailable chat context. A task may link to `spec.md`, but the task packet must copy all information needed to act safely.

Use this YAML schema:

```yaml
tasks:
  - key: task-name
    description: Implement one observable outcome
    details: ./task-name.md
    status: open
    depends: []
    requirements: [FR-01]
    acceptance: [AC-01]
```

Task rules:

- A task has one clear completion state.
- Dependencies name only existing task keys.
- No task depends on an unstated chat decision.
- The `requirements` and `acceptance` lists must refer to identifiers in `spec.md`.
- Split a task when independent ownership, verification, or rollback is unclear.

### 5. Validate before delivery

Verify all of the following:

- Every material user request appears in scope, a requirement, or a recorded non-goal.
- Every requirement has at least one acceptance criterion and task.
- Every acceptance criterion maps to at least one requirement and task.
- Each task packet contains all eight required sections.
- Task packets repeat their required constraints and do not rely on prior chat context.
- All dependencies, requirement IDs, and acceptance IDs resolve.
- Open questions have owners and blocked requirements.
- The resolved output path is under the main checkout's `.specs/` when the current work is in a worktree.

Run:

```bash
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
