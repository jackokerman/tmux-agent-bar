---
id: 2026-06-25-tmux-agent-bar-picker-preview-pane
title: tmux-agent-bar picker preview pane
state: inbox
createdAt: 2026-06-25T00:47:17.114Z
updatedAt: 2026-06-25T00:47:17.114Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
sourceRepo: /Users/jackokerman/tmux-agent-bar
sourcePath: 
---

# tmux-agent-bar picker preview pane

## Plan

# tmux-agent-bar picker preview pane

Add an optional second-pass preview for `tmux-agent-bar-picker` once the basic flat session switcher exists and proves useful.

Scope for the follow-up:

- use `tmux capture-pane` to show bounded recent output for the selected session
- keep preview line count small and configurable only if needed
- verify preview work does not introduce noticeable picker lag
- do not add background polling or preview logic to the status render path
