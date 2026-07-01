---
id: 2026-06-25-tmux-agent-bar-right-to-left-stable-status-ordering
title: tmux-agent-bar right-to-left stable status ordering
state: complete
priority: high
createdAt: 2026-06-25T01:22:19.265Z
updatedAt: 2026-06-25T19:51:35.436Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
---

Additional stability fix after observing same-tier flip-flopping in live tmux status.

Cause:
- Explicit `working` hooks rewrite local state files, so `updated_at` is last hook activity, not stable tier-entry time.
- The scan-order helper used `updated_at` for every state and source sequence as the final tie-breaker, allowing active working rows or equal-timestamp rows to trade places between refreshes.

Fix:
- `tmux_agent_bar_emit_scan_ordered_records` now ignores `updated_at` for `working` rows and uses session label as the deterministic same-tier key.
- Non-working rows still use numeric `updated_at` first, but ties now use session label instead of source order.
- Added a focused regression test proving working rows do not reorder based on volatile mtimes and equal waiting timestamps are deterministic.

Verification:
- `tests/test-session-status.sh` passes.
- `./scripts/check` passes.
