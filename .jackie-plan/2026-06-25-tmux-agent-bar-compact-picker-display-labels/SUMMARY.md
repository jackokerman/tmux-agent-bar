---
id: 2026-06-25-tmux-agent-bar-compact-picker-display-labels
title: tmux-agent-bar compact picker display labels
state: complete
createdAt: 2026-06-25T01:03:26.300Z
updatedAt: 2026-06-25T21:50:14.616Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
---

Implemented picker-local compact session labels without changing the shared row contract. `bin/tmux-agent-bar-picker` now compacts path-like session names to the trailing component and reveals additional parent segments only when collisions remain, while the hidden first column still carries the full `session_label` target for `tmux switch-client -t`. Added a deterministic picker test that covers collision disambiguation and preserved the existing switch-target assertion, then updated the README picker section and verified with `tests/test-picker.sh` and `./scripts/check`.
