---
name: writer-check
description: Check that the active agent harness can launch easy-writer, moderate-writer, and hard-writer. Use when asked to verify writer-role availability.
---

# Check writer role availability

Launch each exact role in the active harness: `easy-writer`, `moderate-writer`, and `hard-writer`.

Use the harness's normal agent tool: Codex `spawn_agent`, Claude Code `Agent`, or OMP `task`, following the active harness instructions. Request each role by its exact name and let the harness select its configured model. Start each with isolated context and no conversation history where supported.

Use this harmless prompt, replacing `<role>` with the role's exact name:

> Availability check only. Do not call tools, inspect files, or edit files. Reply with one line of plain text, without quotes or Markdown: writer-check: <role> ready

Wait for every launch to finish. An error for one role does not stop checks of the others. A role passes only when its live reply exactly matches the requested acknowledgment. Report a pass or failure for each role, including the actual runtime error or unexpected reply for failures.

Distinguish these failure causes in the report:

- **Dispatch tool unavailable:** the active harness has no usable agent dispatch tool.
- **Role launch failure:** dispatch was available but rejected or failed to launch the requested role.
- **Model/runtime error:** the role launched, but its model or runtime failed before returning the acknowledgment.
- **Unexpected reply:** the role returned text other than the exact acknowledgment.

Do not retry with another role, model, or harness. Do not run production work or make file changes during these smoke checks.
