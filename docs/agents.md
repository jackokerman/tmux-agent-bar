# Agents

An agent module registers a command name plus a tail classifier function.

```bash
tmux_agent_register_command "codex" "codex"
tmux_agent_register_classifier "codex" "tmux_codex_classify_line"
```

For Codex specifically, the repo also ships `bin/tmux-agent-bar-codex-hook`, which maps the official lifecycle and approval hook events onto the shared explicit-state entrypoint.

The tail classifier still matters for Codex because in-turn question prompts and plan confirmation prompts are not covered by those hook events.

## State model

The durable source of truth for local sessions is the hook state file written by
`bin/tmux-agent-bar-hook`. Each record names an agent and one explicit state:
`working`, `waiting`, or `done`.

Local pane inspection is a fallback, not a second writer. The collector uses it
to detect live agent panes and to infer prompt states that hooks do not expose,
especially current waiting prompts. It does not refresh hook state file mtimes
from transcript text.

The local precedence model is:

1. A known explicit `done` row with no live agent process is removed and hidden.
2. If the live pane belongs to a different registered agent command, the
   explicit row resolves as `done`.
3. A visible current waiting prompt resolves as `waiting`, even over explicit
   `working` or `done`.
4. A visible current working marker can render an explicit `done` row as
   `working`.
5. Stale explicit `working` with no current live marker resolves as `done`.
6. A live agent pane with no explicit state emits a `local_fallback` row from
   live inference, or `done` when the pane is neutral.
7. No explicit row and no live agent pane emits nothing.

Source modules should emit normalized rows through the registered source
contract. Replacement sources may shadow local rows; additive sources should
emit their own rows without relying on renderer-specific side effects.
