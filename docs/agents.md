# Agents

An agent module registers a command name plus a tail classifier function.

```bash
tmux_agent_register_command "codex" "codex"
tmux_agent_register_classifier "codex" "tmux_codex_classify_line"
```

For Codex specifically, the repo also ships `bin/tmux-agent-bar-codex-hook`, which maps the official lifecycle and approval hook events onto the shared explicit-state entrypoint.

The tail classifier still matters for Codex because in-turn question prompts and plan confirmation prompts are not covered by those hook events.
