# Agents

An agent module registers a command name plus a tail classifier function.

```bash
tmux_agent_register_command "codex" "codex"
tmux_agent_register_classifier "codex" "tmux_codex_classify_line"
```
