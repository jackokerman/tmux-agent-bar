---
id: 2026-06-25-tmux-agent-bar-right-to-left-stable-status-ordering
title: tmux-agent-bar right-to-left stable status ordering
state: inbox
createdAt: 2026-06-25T01:22:19.265Z
updatedAt: 2026-06-25T01:22:33.390Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
sourceRepo: /Users/jackokerman/tmux-agent-bar
sourcePath: .
---

Captured follow-up for compact status ordering: support right-to-left scanning by avoiding behavior where a session that transitions from `working` to `done` appears as the newest/rightmost visible item.

Implementation should preserve actionable priority for truncation, keep rendering bounded, avoid launcher-specific assumptions, and add renderer tests for state transitions plus constrained-width priority.
