---
id: 2026-06-25-tmux-agent-bar-right-to-left-stable-status-ordering
title: tmux-agent-bar right-to-left stable status ordering
state: ready-to-ship
priority: high
createdAt: 2026-06-25T01:22:19.265Z
updatedAt: 2026-06-25T17:29:02.816Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
sourceRepo: /Users/jackokerman/tmux-agent-bar
sourcePath: .
---

Implemented compact status rendering with separate truncation priority and visual scan order.

Changes:
- `tmux_session_status_render_records` still accepts rows in incoming priority order for width/truncation.
- Accepted rows are visually ordered left-to-right as other, working, done, waiting, so `status-right` scans right-to-left as waiting, done, working.
- Numeric `done` rows render newest-to-oldest left-to-right, making the earliest completed `done` row closest to the right edge and encountered first when scanning right-to-left.
- The truncation indicator renders at the low-priority left side, preserving waiting rows at the right edge when they survive constrained width.
- Added focused renderer tests and updated the overlay contract fixture plus README behavior note.

Verification:
- `tests/test-session-status.sh` passes.
- `./scripts/check` passes.
