# Sources

A source module contributes rows to the shared renderer.

```bash
tmux_agent_register_source "local" "tmux_agent_bar_local_emit_records"
```

The full registration form is:

```bash
tmux_agent_register_source "name" "emit_fn" "refresh_fn"
```

The emit function receives the current tmux session label as its first argument. It writes normalized rows to stdout. The renderer still owns current-session filtering, so sources may ignore the argument when emitting a complete cached view.

The refresh function is optional and receives no arguments. It runs before `render`, `current-state`, and `explain`; the `render-cached`, `current-state-cached`, and `explain-cached` paths skip refresh hooks. Keep refresh hooks bounded and opportunistic. They can probe another system or refresh a cache, but they should not poll forever, require interactive input, or block long enough to make tmux status rendering feel stuck. If a refresh fails, leave the last known cache in place when that is safer than deleting useful rows. The runtime ignores refresh failures to protect status rendering.

The checked-in repo ships two generic sources:

- `local`, which inspects tmux sessions on the current host
- `remote-cache`, which reads `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/remote-rows.tsv`

## Row format

`remote-rows.tsv` must contain normalized five-column rows:

```text
session_label<TAB>agent<TAB>state<TAB>source<TAB>updated_at
```

`state` should be `working`, `waiting`, or `done`. `waiting` is accepted as an input state and renders as `done`, matching the local hook contract. `source` should be a stable source identifier such as `remote_cache` or `remote_adapter`. `updated_at` should be Unix epoch seconds when known, or `0` when the source has no useful timestamp.

Rows are considered in source registration order, and the first row for a session label wins. That gives adapters two integration modes:

- Additive sources emit independent rows for sessions that the local collector does not own.
- Replacement sources emit rows for a session label that may also exist locally, and add that label to `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/shadowed-sessions.txt`.

Only replacement sources should write `shadowed-sessions.txt`. Additive sources must not shadow local rows. Shadowing is a local collector hint: it suppresses the local row before stale cleanup or local fallback logic runs, so the replacement row can represent the session without racing the local evidence.

## Remote adapters

The public adapter contract is the source interface plus the normalized cache files. Remote transport, host discovery, session creation, attach commands, connector selection, authentication, and recovery policy belong in user modules, overlays, or external scripts that write the same generic rows.

A remote adapter should resolve remote evidence before it writes a row:

| Evidence | Adapter responsibility |
| --- | --- |
| Explicit lifecycle state | Treat it as the primary state when it is current. |
| Live agent or prompt evidence | Use it to keep active work `working` or check-in-needed work `waiting`/`done`. |
| Tail or transcript inference | Keep it bounded and avoid treating stale connector or launcher output as live agent state. |
| Stale `working` state | Downgrade, hide, or preserve according to the adapter's own TTL and cache policy before writing the row. |
| Probe or transport failure | Prefer preserving the last useful cache over blocking the renderer or deleting rows blindly. |
| Same local session label | Use replacement rows plus `shadowed-sessions.txt`; otherwise stay additive. |

The checked-in `remote-cache` source does not perform remote probes. It only reads the normalized rows. This keeps the core runtime launcher-agnostic and gives each adapter room to choose the smallest reliable transport for its environment.

## External launchers

Launchers, pickers, and one-shot workflow scripts do not need first-class runtime support. Choose the narrowest contract that matches what the launcher actually owns:

- If the launcher starts an agent in the current tmux session, call `bin/tmux-agent-bar-hook` from that agent's lifecycle hooks.
- If the launcher represents independent work outside the local tmux session list, write additive source rows or update `remote-rows.tsv`.
- If the launcher owns the status for the same local tmux session label, write replacement rows and shadow that label.
- If the launcher only opens, creates, or switches sessions and the agent writes its own hook state, keep the launcher invisible to the bar.

Pass stable identifiers across launcher boundaries when possible. Display labels, icons, preview text, and picker-specific formatting are presentation, not durable status keys.

## Debugging

`bin/tmux-agent-bar explain <session>` reports the selected row plus generic source/cache diagnostics for one session. `bin/tmux-agent-bar explain-cached <session>` uses the same diagnostic shape without running source refresh hooks, which is the safer command to request when debugging stale cache or adapter behavior.
