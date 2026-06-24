# Sources

A source module contributes rows to the shared renderer.

```bash
tmux_agent_register_source "local" "tmux_agent_bar_local_emit_records"
```

Optional refresh hooks can do slow work such as remote probes and local cache updates.

The checked-in repo ships three generic sources:

- `local`, which inspects tmux sessions on the current host
- `one-shot`, which tracks configured tmux session labels while matching descendant process commands are still running
- `remote-cache`, which reads `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/remote-rows.tsv`

`remote-rows.tsv` must contain normalized five-column rows:

```text
session_label<TAB>agent<TAB>state<TAB>source<TAB>updated_at
```

If a remote row should replace a local row for the same tmux session, add that session label to `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/shadowed-sessions.txt`.

Remote transport, polling, and cache population are still intentionally left to user modules, overlays, or external scripts so the checked-in runtime stays generic.

The `one-shot` source is configured with `${XDG_CONFIG_HOME:-$HOME/.config}/tmux-agent-bar/one-shot.tsv`. Each non-comment line is:

```text
session_label<TAB>command<TAB>another-command
```
