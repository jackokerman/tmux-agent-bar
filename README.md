# tmux-agent-bar

Status-line-first tmux agent status tracking for local and remote coding sessions.

## What it does

- Renders a compact `status-right` segment for non-current tmux sessions.
- Tracks explicit `working`, `waiting`, and `done` state via a hook entrypoint.
- Includes a small Codex hook adapter for lifecycle and approval events.
- Preserves live pane-tail inference for agents like `codex` that do not expose every state transition through hooks.
- Supports extra record sources, so local rows and remote rows can share the same renderer.
- Includes a built-in remote cache reader without baking any transport logic into the runtime.
- Can track configured one-shot tmux sessions while their launcher process is still running.

## Install

This repo is installation-agnostic. Clone it, vendor it, or manage it however you want. The runtime only assumes tmux can execute these entrypoints from your checkout:

```text
/path/to/tmux-agent-bar/bin/tmux-agent-bar
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook
/path/to/tmux-agent-bar/bin/tmux-agent-bar-codex-hook
```

A minimal tmux integration looks like:

```tmux
set -g status-right "#(/path/to/tmux-agent-bar/bin/tmux-agent-bar '#{session_id}')"
```

Pass `#{session_id}` so tmux treats each session as a distinct `#()` job result and the current-session filter stays in sync when you switch sessions.

If you want shorter shell commands, add the repo `bin/` directory to your `PATH` or symlink whichever entrypoints you want wherever you prefer.

## Agent hooks

Write explicit state for the current tmux session:

```bash
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook working codex
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook waiting codex
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook done codex
```

For Codex, point the supported official hook events at:

```text
/path/to/tmux-agent-bar/bin/tmux-agent-bar-codex-hook <HookEvent>
```

The adapter maps:

- `PermissionRequest` to `waiting`
- `UserPromptSubmit`, `PreToolUse`, and `PostToolUse` to `working`
- `SessionStart` and `Stop` to `done`

Codex still needs live tail inference for in-turn question and plan confirmation prompts because those do not currently have a dedicated hook event.

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

## Remote cache contract

The checked-in runtime includes a generic remote cache source that reads:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/remote-rows.tsv
${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/shadowed-sessions.txt
```

`remote-rows.tsv` uses the normalized five-column row format above.

`shadowed-sessions.txt` is a plain newline-delimited list of tmux session labels that the local collector should suppress because a remote row is already representing them.

How those files get populated is intentionally left to user modules, overlays, or external scripts.

## Config

User-provided modules live under:

```text
~/.config/tmux-agent-bar/agents/*.sh
~/.config/tmux-agent-bar/sources/*.sh
```

Remote or devbox-specific transport logic belongs in those user-provided source modules or external scripts, not in the checked-in runtime.

### One-shot sessions

The built-in `one-shot` source is disabled until you create:

```text
~/.config/tmux-agent-bar/one-shot.tsv
```

Each non-comment row tracks one tmux session label and one or more descendant process commands:

```text
session_label<TAB>command<TAB>another-command
```

When a configured session is not current and one of its commands is still running under a pane in that session, the source emits a `one_shot` row. If a known agent process is also running, the source uses the shared tail classifier to distinguish `waiting`, `working`, and `done`; otherwise it reports `working`.

## Development

Run the regression suite with:

```bash
./scripts/check
```
