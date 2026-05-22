# Sources

A source module contributes rows to the shared renderer.

```bash
tmux_agent_register_source "local" "tmux_agent_bar_local_emit_records"
```

Optional refresh hooks can do slow work such as remote probes and local cache updates.

Remote or environment-specific source logic is intentionally left to user modules and overlays, so the checked-in repo stays generic.
