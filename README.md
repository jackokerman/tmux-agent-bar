# tmux-agent-bar

Status-line-first tmux agent status tracking for local and remote coding sessions.

## What it does

- Renders a compact `status-right` segment for non-current tmux sessions.
- Tracks explicit `working`, `waiting`, and `done` state via a hook entrypoint.
- Preserves live pane-tail inference for agents like `codex` that do not expose every state transition through hooks.
- Supports extra record sources, so local rows and remote rows can share the same renderer.

## Install

The intended install path in this setup is a dotty-managed checkout under:

```bash
~/.local/share/tmux-agent-bar/repo
```

The runtime entrypoints are:

```bash
bin/tmux-agent-bar
bin/tmux-agent-bar-hook
```

## Agent hooks

Write explicit state for the current tmux session:

```bash
tmux-agent-bar-hook working codex
tmux-agent-bar-hook waiting codex
tmux-agent-bar-hook done codex
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

## Development

Run the regression suite with:

```bash
./scripts/check
```
