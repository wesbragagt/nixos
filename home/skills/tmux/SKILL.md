---
name: tmux
description: Read from and send to tmux panes non-interactively. Uses workmux commands for agents in worktrees, and raw tmux for other panes. Use when the user mentions tmux, another window or pane, or something running in another terminal.
---

# tmux

## 1. Agents: use workmux

If the target is an agent that workmux manages, use workmux. Do not use raw tmux.
Workmux targets an agent by worktree name, so it cannot hit the wrong pane.

```bash
workmux status --all                      # find agent names and status (working/waiting/done)
workmux capture <name> -n 50              # read the last 50 lines
workmux send <name> "fix the tests"       # send a prompt (submits it)
workmux send <name> -f prompt.md          # send a long or multi-line prompt
workmux wait <name> --timeout 1800        # block until the agent is done
workmux run <name> -- npm test            # run a command in the worktree window, stream output
```

- Use `project:name` for an agent in another repo.
- A worktree can have more than one agent (for example OMP and Claude). `send` goes to only one of them. If `status` shows two rows, run `capture` to confirm which agent got the text.
- Run `workmux capture` before `workmux send`, to confirm the agent state.
- Use `workmux wait`, not `sleep`, to wait for a reply. Then `capture`.
- Write long prompts to a file in the scratchpad, then use `-f`.

## 2. Other panes: raw tmux

Use raw tmux only for panes that are not workmux agents (dev servers, builds, shells).

```bash
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_name} #{pane_current_command} #{pane_current_path}'
tmux capture-pane -t %3 -p -S -50         # read the last 50 lines
tmux send-keys -t %3 -l 'npm run dev'     # literal text
tmux send-keys -t %3 Enter                # submit
```

Before each `send-keys`, do these checks:

1. Target a pane ID (`%3`). Do not use window or pane indexes. They change.
2. Confirm `#{pane_current_command}` is the program you expect.
3. Confirm the target is not your own pane (`$TMUX_PANE`).
4. After the send, run `capture-pane` to see where the text went.

To wait for output, poll with a timeout. Do not use a bare foreground `sleep`.

```bash
timeout 30 bash -c 'until tmux capture-pane -t %3 -p -S -50 | grep -q "^ready"; do sleep 0.5; done'
```

Anchor the pattern (`^`). An unanchored pattern also matches the command line you typed.

## Rules

- Never run `tmux kill-server`. It destroys every session.
- Kill only sessions, windows, or panes that you created or that the user named.
- Never run `tmux attach`. It blocks the shell.
- Create sessions detached: `tmux new-session -d -s <name>`.
- `tmux ls` with "no server running" means zero sessions, not an error.
