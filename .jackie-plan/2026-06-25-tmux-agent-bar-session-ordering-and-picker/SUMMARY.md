---
id: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
title: tmux-agent-bar session ordering and picker
state: complete
createdAt: 2026-06-25T00:23:09.647Z
updatedAt: 2026-06-25T17:19:38.079Z
---

Implemented the first-cut session picker plan.

Changes made:
- Added `lib/records.sh` to emit first-row-wins, prioritized session rows (`waiting`, `working`, `done`, then other states) for shared use.
- Routed `bin/tmux-agent-bar` render and current-state paths through the shared prioritized record helper.
- Simplified `lib/render.sh` so rendering formats the ordered input stream instead of owning state priority buckets.
- Added `bin/tmux-agent-bar-picker`, an optional `fzf` picker that runs inside tmux, refreshes sources, hides the current session, displays state/session/agent/source/age, and switches via the hidden original session target.
- Documented picker usage and tmux popup/new-window examples in `README.md`, `docs/install.md`, and `examples/tmux.conf.snippet`.
- Added non-interactive tests for shared ordering/current-state behavior and picker missing dependency, outside-tmux, row formatting, hidden target, and reload binding behavior.

Verification:
- `./scripts/check` passed.

Remaining related backlog stays captured separately:
- compact picker display labels
- optional picker preview pane
- right-to-left stable status ordering
