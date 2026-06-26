---
id: 2026-06-25-tmux-agent-bar-follow-ups-after-hook-runtime-fix
title: tmux-agent-bar follow-ups after hook/runtime fix
state: inbox
createdAt: 2026-06-25T15:46:58.869Z
updatedAt: 2026-06-25T15:46:58.869Z
sourcePlan: 2026-06-24-harden-tmux-agent-bar-state-model
sourceRepo: /Users/jackokerman/src/tmux-agent-bar
sourcePath: .
---

Captured follow-up backlog after the hook/runtime fix. No runtime changes were made in this plan entry, and the item remains `inbox`.

Key findings recorded here:
- Official Codex hooks still cover lifecycle and approval events, but not arbitrary in-turn question or plan-confirmation waiting states.
- The slow path observed during debugging was the shell-wrapper process scan, not pane-tail parsing.
- Direct pane command detection now handles `codex-*` variants before falling back to process inference.

Next work captured by the plan:
- Re-check Codex hook coverage periodically so tail-based waiting inference can be removed if a dedicated waiting hook appears.
- Consider an explicit alias/registration path for nonstandard Codex launch names instead of widening built-in command matching.
- Revisit whether shell-wrapper inference should remain enabled by default and, if it does, keep narrowing when it runs.
- Add focused performance coverage around local snapshot/render latency on large process tables.
