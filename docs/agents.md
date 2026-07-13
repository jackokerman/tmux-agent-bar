# Agents

An agent module registers a command name plus a tail classifier function.

```bash
tmux_agent_register_command "codex" "codex"
tmux_agent_register_classifier "codex" "tmux_codex_classify_line"
```

For Codex specifically, the repo also ships `bin/tmux-agent-bar-codex-hook`, which maps the official lifecycle and approval hook events onto the shared explicit-state entrypoint.

The tail classifier still matters for Codex because in-turn question prompts and plan confirmation prompts are not covered by those hook events.

## State model

The durable source of truth for local sessions is the hook state file written by `bin/tmux-agent-bar-hook`. Each record names an agent, one explicit state, and optionally the tmux pane id that wrote it. The explicit states are `working`, `waiting`, or `done`. `waiting` is accepted as input but resolves to the same visible `done` state as other check-in-needed rows.

Local pane inspection is a fallback, not a second writer. The collector uses it to detect live agent panes and to infer prompt states that hooks do not expose, especially current waiting prompts. When an explicit row has a pane id, live process and tail evidence for that row are scoped to the same pane; older two-field state files remain session-scoped. The collector does not refresh hook state file mtimes from transcript text.

The local precedence model is:

1. A known explicit row with no live same-agent process is removed and hidden. If the row has a pane id, only a live same-agent process in that pane counts. Old scrollback or another pane in the same tmux session cannot keep local explicit state alive after the recorded pane exits.
2. A same-agent live process in the matching pane lets live pane state reconcile the explicit row.
3. If the live pane belongs to a different registered agent command, the explicit row resolves as `done`.
4. A visible current waiting prompt resolves as `done`, even over explicit `working` or `done`.
5. A visible current working marker can render an explicit `done` row as `working`.
6. Stale explicit `working` with no current live marker resolves as `done`.
7. A live agent pane with no explicit state emits a `local_fallback` row only from active live inference.
8. A shell-wrapped pane with no explicit row and no live agent process emits a fallback row only for an inferred active or waiting state. Waiting fallback rows display as `done`. When that evidence disappears, the observed fallback marker is cleared.
9. No explicit row and no live agent pane emits nothing.

Source modules should emit normalized rows through the registered source contract. Replacement sources may shadow local rows; additive sources should emit their own rows without relying on renderer-specific side effects.

Use `bin/tmux-agent-bar explain-cached <session>` when a local row is surprising. It reports the explicit state, explicit pane id, live agent, tail inference, observed fallback marker, shadowing status, resolved row, and proposed side effects without deleting state files or writing observed-session markers.
