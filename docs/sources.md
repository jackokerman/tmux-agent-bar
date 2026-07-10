# Sources

A source module contributes rows to the shared renderer.

```bash
tmux_agent_register_source "local" "tmux_agent_bar_local_emit_records"
```

Optional refresh hooks can do slow work such as remote probes and local cache updates.

The checked-in repo ships two generic sources:

- `local`, which inspects tmux sessions on the current host
- `remote-cache`, which reads `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/remote-rows.tsv`

`remote-rows.tsv` must contain normalized five-column rows:

```text
session_label<TAB>agent<TAB>state<TAB>source<TAB>updated_at
```

If a remote row should replace a local row for the same tmux session, add that session label to `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/shadowed-sessions.txt`.
Only replacement sources should write this file. Additive sources emit rows directly and must not shadow local rows.

Remote transport, polling, and cache population are still intentionally left to user modules, overlays, or external scripts so the checked-in runtime stays generic.

`bin/tmux-agent-bar explain <session>` reports the selected row plus generic source/cache diagnostics for one session. `bin/tmux-agent-bar explain-cached <session>` uses the same diagnostic shape without running source refresh hooks, which is the safer command to request when debugging stale cache or adapter behavior.
