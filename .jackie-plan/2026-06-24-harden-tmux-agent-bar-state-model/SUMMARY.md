---
id: 2026-06-24-harden-tmux-agent-bar-state-model
title: Harden tmux-agent-bar state model
state: ready-to-implement
createdAt: 2026-06-24T22:21:37.150Z
updatedAt: 2026-06-24T22:22:53.880Z
---

Ready-to-implement repo-local plan for hardening `tmux-agent-bar` state stability. The target architecture is: hooks own durable state, sources emit rows, reconciliation applies documented precedence, rendering formats only, and pane-tail inference remains bounded and ephemeral. Start implementation by documenting the state model, then add characterization tests around lifecycle behavior before tightening `_touch_state_file` and collector mutation rules. The main implementation choice is whether to remove the live-inference heartbeat entirely or keep it only for clearly current `working` markers below the latest completion/idle boundary. Verify with focused tests plus `./scripts/check`, then commit and push to `main`.
