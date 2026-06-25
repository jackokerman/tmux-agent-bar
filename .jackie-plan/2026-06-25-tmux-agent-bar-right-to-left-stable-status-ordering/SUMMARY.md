---
id: 2026-06-25-tmux-agent-bar-right-to-left-stable-status-ordering
title: tmux-agent-bar right-to-left stable status ordering
state: complete
priority: high
createdAt: 2026-06-25T01:22:19.265Z
updatedAt: 2026-06-25T17:35:59.600Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
sourceRepo: /Users/jackokerman/tmux-agent-bar
sourcePath: .
---

Follow-up correction implemented after clarifying queue semantics.

Corrected behavior:
- Queue/front-of-scan order is `waiting`, then `done`, then `working`, then other states.
- Within each state, numeric `updated_at` rows are ordered oldest first in scan order, so a newer yellow/green row is appended behind older rows in that same tier.
- `status-right` defaults to right-to-left scan optimization by reversing scan order visually, so the front of the queue sits at the right edge.
- `TMUX_AGENT_BAR_SCAN_DIRECTION=left-to-right` renders the same queue with the front at the left edge.
- The picker now uses the shared scan-order helper directly, so its top-to-bottom order matches the queue/front-of-attention order.

Verification:
- `tests/test-session-status.sh` passes.
- `tests/test-picker.sh` passes.
- `./scripts/check` passes.
