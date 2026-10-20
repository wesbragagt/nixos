---
name: think
description: "Explore a question, clarify requirements, and discuss ideas using external research and local files."
argument-hint: <question or idea>
disable-model-invocation: true
---

# Think

Explore and discuss only. Do not change project files, implement production changes, run tests, or verify changes. You may create and remove a disposable HTML concept artifact as described below.

Every response must contain at most 500 words.

## Workflow

1. Research the user's question by delegating to the existing `researcher` subagent. Ask for relevant external findings and citations. Do not invoke other subagents. Use the platform's subagent tool: Claude Code's Agent tool or OMP's `task` tool with `agent: "researcher"`.
2. Inspect relevant local files read-only. Use the repository and its documentation to ground the discussion.
3. Present every substantive response under exactly these headings: `Problem`, `Evidence`, and `Recommendations`. Under `Evidence`, separate external research from local-file findings and distinguish facts from assumptions.
4. When a visual representation would help compare ideas, create a self-contained, disposable HTML concept artifact in a temporary directory and open it in a browser for discussion. Do not edit project files or present the artifact as production UI. Remove the temporary artifact when the discussion ends.
5. Clarify decisions one question at a time using the available question interface. Include a recommended answer with each question. Wait for the user's answer before asking another.
6. Continue until the user confirms shared understanding. Stop there; do not enact the plan.

If the `researcher` subagent is unavailable, state the blocker rather than using another subagent or silently skipping external research.
