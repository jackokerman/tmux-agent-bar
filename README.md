# tmux-agent-bar

Status-line-first agent status tracking for tmux sessions.

`tmux-agent-bar` renders a compact tmux status segment for your other sessions so you can see which agent panes are working or ready for you to check without switching away from your current session. It is launcher-agnostic: hooks, local pane inspection, and optional source modules all write the same generic state records.

## What it does

- Renders `working` and `done` state for non-current tmux sessions. `waiting` input is accepted but displays as `done`.
- Orders compact `status-right` output for right-to-left scanning: `done` sessions sit at the right edge, and `working` sessions sit behind them. Within each state, older timestamped rows stay ahead of newer rows.
- Tracks explicit state through `bin/tmux-agent-bar-hook`.
- Includes built-in agent classifiers for `claude` and `codex`.
- Includes `bin/tmux-agent-bar-codex-hook` for supported Codex lifecycle and approval hook events.
- Includes an optional `fzf` picker for switching to another agent session.
- Preserves live pane-tail inference for prompt states that hooks do not expose.
- Supports extra source modules, so local rows and remote rows share one renderer.
- Reads an optional remote cache without baking transport logic into the runtime.

## Quick start

Clone, vendor, or otherwise place this repo wherever you want. Then point tmux at the renderer entrypoint:

```tmux
set -g status-right "#(/path/to/tmux-agent-bar/bin/tmux-agent-bar '#{session_id}')"
```

Pass `#{session_id}` so tmux treats each session as a distinct `#()` job result and the current-session filter stays in sync when you switch sessions.

If you want shorter commands, add the repo `bin/` directory to your `PATH` or symlink the entrypoints you use into a directory that is already on your `PATH`.

See [docs/install.md](docs/install.md) for the shorter install reference.

## Hook integration

Use the generic hook entrypoint to write explicit state for the current tmux session:

```bash
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook working codex
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook waiting codex
/path/to/tmux-agent-bar/bin/tmux-agent-bar-hook done codex
```

The second argument is the agent name. If omitted, it defaults to `claude`.

For Codex, point supported hook events at:

```text
/path/to/tmux-agent-bar/bin/tmux-agent-bar-codex-hook <HookEvent>
```

The Codex adapter maps:

- `PermissionRequest` to `waiting`
- `UserPromptSubmit` and `PreToolUse` to `working`
- `SessionStart` and `Stop` to `done`

`PostToolUse` is intentionally ignored for durable state. `PreToolUse` already marks the turn as active, and treating the post-tool hook as another `working` edge can keep refreshing stale state after the last tool call if the later `Stop` edge is missed.

`waiting` is kept as a hook/classifier input state, but resolved rows display as `done` with the same green check mark. Codex still needs live tail inference for in-turn question and plan confirmation prompts because those do not currently have a dedicated hook event.

## CLI entrypoints

`bin/tmux-agent-bar` defaults to rendering the status segment:

```bash
/path/to/tmux-agent-bar/bin/tmux-agent-bar '#{session_id}'
```

It also supports explicit subcommands:

```text
render [current-target]
render-cached [current-target]
current-state [current-target]
current-state-cached [current-target]
explain <session>
explain-cached <session>
```

Use `render-cached` or `current-state-cached` when the caller must avoid source refresh hooks. Use `current-state` when another tmux-side integration needs the current session's resolved state instead of the rendered multi-session segment.

Use `explain` or `explain-cached` to debug why one session resolves to a visible row or stays hidden. The output is stable `key=value` lines with the selected row, local evidence, shadowing status, proposed side effects, and source/cache freshness fields. `explain-cached` skips source refresh hooks.

The status renderer defaults to optimizing for right-to-left scanning from the right edge. Set `TMUX_AGENT_BAR_SCAN_DIRECTION=left-to-right` in the renderer environment to put the front of the same queue at the left edge instead.

`bin/tmux-agent-bar-picker` opens an optional `fzf` picker over the same prioritized session rows and switches to the selected tmux session:

```bash
/path/to/tmux-agent-bar/bin/tmux-agent-bar-picker
```

The picker requires `fzf` and must run inside tmux. It refreshes sources when it opens, hides the current session, and keeps the original session label as the switch target. For path-like session names, the visible session column compacts to the trailing path component and adds parent context only when needed to disambiguate collisions.

Example tmux bindings:

```tmux
bind-key A display-popup -E "/path/to/tmux-agent-bar/bin/tmux-agent-bar-picker"
bind-key a new-window "/path/to/tmux-agent-bar/bin/tmux-agent-bar-picker"
```

## State and cache files

Explicit local hook state is stored under:

```text
${STATE_DIR:-/tmp/tmux-agent-$(id -u)}
```

Each state file contains:

```text
agent<TAB>state
```

The generic remote cache source reads:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/remote-rows.tsv
${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/shadowed-sessions.txt
```

The local collector also keeps bounded observation markers under:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/observed-sessions/
```

Those markers are written after a shell-wrapped session is observed in an active or waiting fallback state. Waiting fallback evidence displays as `done`. Markers are cleared when that pane no longer has active fallback evidence, so old scrollback does not keep a completed agent in the bar. Orphan markers are also pruned when their tmux session no longer exists.

`remote-rows.tsv` uses the normalized five-column row format:

```text
session_label<TAB>agent<TAB>state<TAB>source<TAB>updated_at
```

`shadowed-sessions.txt` is a newline-delimited list of tmux session labels that the local collector should suppress because another source already represents them. Only replacement sources should write this file; additive sources should emit rows directly and must not shadow local rows.

How those files get populated is intentionally left to user modules, overlays, or external scripts. For remote adapters and external launchers, treat the hook entrypoint, source registration API, and normalized cache rows as the public boundary.

See [docs/sources.md](docs/sources.md) for the source contract.

## User modules

Optional user-provided modules live under:

```text
~/.config/tmux-agent-bar/agents/*.sh
~/.config/tmux-agent-bar/sources/*.sh
```

Agent modules register a command name and a tail classifier function. Source modules register a record emitter and, optionally, a refresh function.

See [docs/agents.md](docs/agents.md) and [docs/sources.md](docs/sources.md) for the module contracts, including the explicit-state precedence model.

## Repository layout

```text
bin/       runtime entrypoints
agents/    built-in agent classifiers
sources/   built-in record sources
lib/       shared shell functions
docs/      install, agent, source, and migration notes
examples/  tmux and source snippets
tests/     regression tests
```

## Development

Run the regression suite with:

```bash
./scripts/check
```
