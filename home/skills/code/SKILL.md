---
name: code
description: Execute tasks from a tasks.yaml by orchestrating code-writer agents. Use when the user has a tasks.yaml ready to run or says "run the tasks", "execute tasks.yaml".
argument-hint: <path-to-tasks-yaml> [--task <task-key>]
---

Execute tasks from a tasks.yaml file by orchestrating code-writer agents. Automatically handles dependency resolution, parallel execution, and status tracking.

## Usage

```
/code <path-to-tasks-yaml> [--task <task-key>]
```

## Parameters

- `path-to-tasks-yaml`: Path to tasks.yaml file (required)
- `--task`: Execute only a specific task key, skipping dependency resolution

## Examples

```
/code .specs/auth-feature/tasks.yaml
/code ./tasks.yaml --task setup-database
/code .specs/search/tasks.yaml
```

## Implementation

1. **Load and validate tasks.yaml**:
   ```bash
   wtask <path-to-tasks-yaml> summary
   ```
   Report task summary:
   - Total, done, in-progress, open counts

2. **If --task specified**: Jump directly to step 5 for that task.

3. **Find ready tasks** — tasks where ALL of the following are true:
   - `status == "open"`
   - All keys in `depends` have `status == "done"`

   ```bash
   wtask <path> ready
   ```

4. **If no ready tasks**:
   - All done → report completion and stop
   - Circular deps or all blocked → report which tasks are blocking and stop
   - Tasks in progress → report waiting state

5. **Determine execution strategy** for ready tasks:

   **Parallelize** (max 3 concurrent agents) when tasks touch completely separate files/domains.

   **Run sequentially** when tasks:
   - May modify the same file(s)
   - Share configuration or state files
   - Have overlapping file paths
   - When in doubt → sequential

6. **For each ready task**:

   a. **Mark in progress**:
   ```bash
   wtask <path> set <task-key> progress
   ```

   b. **Gather a standalone task packet**:
   - Read the spec file in the same directory (`spec.md`, or legacy `prd.md`) and extract the acceptance criteria relevant to this task
   - Read the task's detail file if `details` path is set
   - Collect the completed dependency handoff records, including each dependency's implementation summary and created or modified files
   - Scan codebase for relevant existing patterns

   c. **Choose agent type**:
   - Single file, simple change → `code-writer-simple`
   - Multi-file, architectural, or complex → `code-writer-complex`

   d. **Invoke the implementation agent** using the prompter skill with this structure:

   ```xml
   <delegation>
     <role>Senior software engineer specializing in {detected language/framework}</role>

     <context>
       <spec>{summary from spec.md}</spec>
       <dependencies>{completed dependency handoff records}</dependencies>
       <codebase>{relevant existing files, patterns, conventions}</codebase>
     </context>

     <task>
       <key>{task-key}</key>
       <description>{task.description}</description>
       <details>{contents of task detail file if exists}</details>
     </task>

     <constraints>
       - Follow existing codebase conventions
       - Ensure compatibility with completed dependent tasks
       - Write production-ready code
       - No new external dependencies without explicit approval
     </constraints>

     <verification>
       1. Code compiles/runs without errors
       2. Existing tests still pass
       3. Implementation matches task details
     </verification>

     <return>
       - Files created/modified with paths
       - Summary of implementation
       - Any issues or blockers encountered
     </return>
   </delegation>
   ```

   e. **Dispatch an independent `verifier` subagent after the implementation agent reports completion and before changing status**. The verifier must not be the implementation agent. Give it the standalone task packet and the implementation claim:

   ```xml
   <delegation>
     <role>Independent verifier</role>

     <task-packet>
       <key>{task-key}</key>
       <description>{task.description}</description>
       <details>{contents of task detail file if exists}</details>
       <acceptance-criteria>{relevant criteria from spec.md}</acceptance-criteria>
       <completed-dependency-handoffs>{completed dependency handoff records}</completed-dependency-handoffs>
     </task-packet>

     <implementation-claim>
       <summary>{implementation agent's claimed summary}</summary>
       <files>{implementation agent's claimed created/modified files}</files>
     </implementation-claim>

     <instructions>
       - Independently inspect the implementation and claimed files
       - Check every task requirement and supplied acceptance criterion
       - Check compatibility with the completed dependency handoffs
       - Return evidence for every conclusion
       - Return exactly one verdict: PASS, FAIL, BLOCKED, or PARTIAL
       - PASS only when the evidence shows the task is complete
     </instructions>
   </delegation>
   ```

   f. **Gate status on the verifier verdict**:
   - Only an evidence-backed `PASS` permits marking the task `done`:
     ```bash
     wtask <path> set <task-key> done
     ```
   - `FAIL`, `BLOCKED`, or `PARTIAL` keeps the task `progress`. Return the verifier's evidence and do not mark it done.
   - Never mark a completed implementation task `done` without a dedicated verifier `PASS`.

   **For parallel tasks**: Launch all implementation agents in a single tool call block. When each implementation completes, dispatch one independent `verifier` subagent for that task, supplying its task packet, implementation claim, and dependency handoff records. Each task remains `progress` until its own verifier returns an evidence-backed `PASS`; do not let another task's result satisfy this gate.

7. **Loop**: After completing a batch and its verifier dispatches, go back to step 3 to find the next ready tasks.

8. **Final verification** when all tasks report done:
   ```bash
   wtask <path> verify
   ```

## Task Management Reference

| Operation | Command |
|-----------|---------|
| Summary | `wtask <path> summary` |
| List all tasks | `wtask <path> list` |
| View ready tasks | `wtask <path> ready` |
| View in progress | `wtask <path> list --status progress` |
| Mark in progress | `wtask <path> set KEY progress` |
| Mark done | `wtask <path> set KEY done` |
| Verify all done | `wtask <path> verify` |

## Error Handling

- **Task fails**: Leave status as `"progress"`, report the error, allow user to retry
- **Verifier returns FAIL, BLOCKED, or PARTIAL**: Leave status as `"progress"`, report the verifier's evidence and verdict, allow user to retry
- **No ready tasks but not all done**: Report which tasks are blocking and why
- **Missing dependency**: Report which upstream tasks need to complete first
- **Missing detail file**: Proceed using only the task description and spec context

## Output Format

```
✓ Loaded tasks.yaml (X tasks)
  - Done: Y
  - In Progress: Z
  - Open: W

▶ Ready: task-name-1 (no deps)
▶ Ready: task-name-2 (no deps)

[Agents executing...]

✓ task-name-1 complete
  Modified: src/foo.ts, src/bar.ts

✓ task-name-2 complete
  Created: src/baz.ts

▶ Ready: task-name-3 (depends: task-name-1, task-name-2 ✓)

[...]

✓ All tasks complete!
```
