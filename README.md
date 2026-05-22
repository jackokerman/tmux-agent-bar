# tmux-agent-bar

Status-line-first tmux agent status tracking for local and remote coding sessions.

## What it does

- Renders a compact `status-right` segment for non-current tmux sessions.
- Tracks explicit `working`, `waiting`, and `done` state via a hook entrypoint.
- Preserves live pane-tail inference for agents like `codex` that do not expose every state transition through hooks.
- Supports extra record sources, so local rows and remote rows can share the same renderer.

## Install

This repo is installation-agnostic. Clone it, vendor it, or manage it however you want. The runtime only assumes tmux can execute these entrypoints from your checkout:

```text
/path/to/tmux-agent-bar/bin/tmux-agent-bar
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook
```

A minimal tmux integration looks like:

```tmux
set -g status-right "#(/path/to/tmux-agent-bar/bin/tmux-agent-bar '#{session_id}')"
```

Pass `#{session_id}` so tmux treats each session as a distinct `#()` job result and the current-session filter stays in sync when you switch sessions.

If you want shorter shell commands, add the repo `bin/` directory to your `PATH` or symlink the two scripts wherever you prefer.

## Agent hooks

Write explicit state for the current tmux session:

```bash
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook working codex
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook waiting codex
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook done codex
```

The state file format is:

```text
agent<TAB>state
```

## Extension points

Agent modules register:

- command name
- tail classifier function

Source modules register:

- record emitter
- optional refresh function

Normalized source rows must look like:

```text
session_label<TAB>agent<TAB>state<TAB>source<TAB>updated_at
```

## Config

User-provided modules live under:

```text
~/.config/tmux-agent-bar/agents/*.sh
~/.config/tmux-agent-bar/sources/*.sh
```

Remote or devbox-specific integrations belong in those user-provided source modules, not in the checked-in runtime.

## Development

Run the regression suite with:

```bash
./scripts/check
```
