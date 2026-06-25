---
id: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
title: tmux-agent-bar session ordering and picker
state: inbox
createdAt: 2026-06-25T00:23:09.647Z
updatedAt: 2026-06-25T00:29:45.470Z
---

Implemented the first layer: compact status rendering now groups rows by state priority before width truncation. Priority is `waiting`, then `working`, then `done`, then unknown non-empty states. Source collection, duplicate precedence, and current-session filtering are unchanged. Commit `94cbc3b` (`feat: prioritize actionable agent sessions`) was pushed to `main`.

Remaining follow-up: decide whether to add an optional `fzf` picker command for richer triage details and tmux session switching.
