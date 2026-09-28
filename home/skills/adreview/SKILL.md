---
name: adreview
description: Run an adversarial review dialogue with the sibling agent in the same workmux session. Claude uses OMP; OMP uses Claude Code. Use when the user requests an adversarial review or invokes /adreview.
argument-hint: "[optional review target, question, files, branch, or diff] [--reviewer=claude|omp]"
---

# Adversarial sibling review

Use the other agent in the current workmux session as an external adversarial reviewer. Do not delegate implementation.

## Select the reviewer

Extract any explicit `--reviewer=claude` or `--reviewer=omp` flag from the arguments. If a flag is present, use it as the reviewer and strip it from the arguments to prevent it from leaking into the review prompt. Otherwise, auto-detect the reviewer from the current tmux window.

```bash
# Get the session
session=$(tmux display-message -p -t "$TMUX_PANE" '#S')

# Check for explicit reviewer flag
if [[ "$ARGUMENTS" =~ --reviewer=(claude|omp) ]]; then
  reviewer="${BASH_REMATCH[1]}"
  # Strip the flag from ARGUMENTS
  ARGUMENTS=$(echo "$ARGUMENTS" | sed 's/ *--reviewer=[^ ]*//')
else
  # Auto-detect from window
  window=$(tmux display-message -p -t "$TMUX_PANE" '#W')
  
  if [[ "$window" == "claude" ]]; then
    reviewer=omp
  elif [[ "$window" == "omp" ]]; then
    reviewer=claude
  else
    echo "Error: /adreview requires the 'claude' or 'omp' workmux window or explicit --reviewer flag." >&2
    exit 1
  fi
fi
```

Set `target="${session}:${reviewer}"`. Confirm that target exists before sending input. Do not select a window from another session.

## Start the review dialogue

Tell the sibling agent to inspect the current worktree and act only as an adversarial reviewer. Include `$ARGUMENTS` when present.

Require the reviewer to:

- challenge assumptions and stated requirements;
- find correctness, security, performance, and maintenance risks;
- identify missing behavioral tests and unsafe edge cases;
- propose simpler alternatives when they remove risk;
- cite exact files and lines for each finding;
- rank each finding as `must-fix`, `should-fix`, or `optional`;
- return `No findings` when repository evidence does not support a finding;
- review only, without editing files.

## Communicate through tmux

Write each complete message to a temporary file. Use the file as a tmux paste buffer:

```bash
tmux load-buffer -b adreview-message "$prompt_file"
tmux paste-buffer -t "$target" -b adreview-message -d
tmux send-keys -t "$target" Enter
rm -f "$prompt_file"
```

Create `prompt_file` with the available file-writing tool. Do not construct review text through shell variables or shell interpolation.

Always send `Enter` separately after the paste.

Wait until the sibling agent returns to its prompt. Then capture its output:

```bash
tmux capture-pane -t "$target" -p -S -2000
```

Continue the dialogue when a finding lacks evidence, conflicts with repository facts, or needs a focused challenge. Send the sibling the exact disputed finding and evidence. Ask for a correction or defense.

Stop when each finding has enough evidence for a decision, the sibling reports no findings, or the user stops the review. Do not let the agents start an unbounded exchange.

Do not attach to tmux. Do not read a partial streaming response as complete.

## Verify and report

Check every sibling finding against the repository before accepting it.

Report:

- the reviewer name;
- accepted findings, with evidence and severity;
- rejected findings, with the reason;
- unresolved findings that need user input;
- `No verified findings` when none survive verification.

Treat sibling output as external model input, not as verified repository evidence. Do not modify code unless the user separately asks for fixes.
