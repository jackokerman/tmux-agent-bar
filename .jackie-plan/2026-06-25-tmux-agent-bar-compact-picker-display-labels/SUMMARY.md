---
id: 2026-06-25-tmux-agent-bar-compact-picker-display-labels
title: tmux-agent-bar compact picker display labels
state: inbox
createdAt: 2026-06-25T01:03:26.300Z
updatedAt: 2026-06-25T01:04:34.686Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
sourceRepo: /Users/jackokerman/tmux-agent-bar
sourcePath: .
---

Captured follow-up for the picker: compact the human-facing display label for path-like session labels while preserving the full `session_label` as the switch target and source-contract identity.

Recommended design: keep the normalized row schema unchanged; render basename-style labels in `tmux-agent-bar-picker`; disambiguate collisions by revealing parent path components from the right; keep the full target in a hidden machine-readable picker column; avoid launcher-specific assumptions in checked-in code and docs.

Generic example: `remote/src/project` displays as `project`; if it collides with `local/project`, qualify to `src/project` and `local/project` while switching with the original full labels.

Verification for implementation: tests for path-like compaction, collision disambiguation, and picker selection using the original full session label, then run `./scripts/check`.
