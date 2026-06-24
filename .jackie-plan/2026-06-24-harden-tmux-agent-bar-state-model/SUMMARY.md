---
id: 2026-06-24-harden-tmux-agent-bar-state-model
title: Harden tmux-agent-bar state model
state: complete
createdAt: 2026-06-24T22:21:37.150Z
updatedAt: 2026-06-24T22:42:31.041Z
---

Implemented the state-model hardening plan in tmux-agent-bar.

Changes made:
- Documented the explicit local state model and precedence in docs/agents.md, with a README pointer.
- Removed the local collector's live-inference heartbeat that touched explicit working state files.
- Added Codex tail characterization tests for completed-turn boundary freshness, including current-turn working, stale waiting above a boundary, and current waiting below a boundary.
- Updated local collector tests so live working still renders as working but does not mutate durable hook state, and stale working expires to done when live inference becomes neutral.

Verification passed:
- ./tests/test-pane-state.sh
- ./tests/test-session-status.sh
- ./tests/test-session-status-local.sh
- ./scripts/check

Next state: ready to commit and push to main.
