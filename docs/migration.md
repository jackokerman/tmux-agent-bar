# Migration

The compatibility bridge can still load the legacy overlay script contract during migration:

- `tmux_agent_overlay_maybe_refresh`
- `tmux_agent_overlay_emit_records`

This keeps the old overlay shape working while the runtime moves to registered sources.
