---
id: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
title: tmux-agent-bar session ordering and picker
state: inbox
createdAt: 2026-06-25T00:23:09.647Z
updatedAt: 2026-06-25T00:25:12.397Z
---

# tmux-agent-bar session ordering and picker

## Plan

# tmux-agent-bar session ordering and picker

## Goal
Make multiple agent sessions easier to scan and triage from tmux.

## Current behavior
`tmux-agent-bar` renders records in source emission order. For local sessions, that mostly follows `tmux list-sessions`; the renderer filters the current session, keeps the first row per label, and truncates from the end. There is no explicit priority for actionable states.

## Proposed direction
1. Add an explicit status-bar ordering contract so actionable sessions appear first:
   - `waiting`
   - `working`
   - `done`
   - any unknown/non-empty states after known states
2. Keep tie-breaking simple and stable. Prefer the smallest behavior that feels predictable, likely source order within each state unless a stronger local pattern emerges.
3. Later, add an optional `fzf` picker command that shows richer session information without adding weight to the hot status render path. Useful fields could include state, session, agent, source, updated age, and maybe a short pane-tail preview. Selecting a row should switch to that tmux session.

## Implementation notes
- Preserve bounded status rendering. Do not introduce polling loops, unbounded scans, or slow work in render truncation.
- Keep the public repo generic and launcher-agnostic.
- Add focused regression tests for ordering before changing renderer behavior.
- Treat the picker as a follow-up unless the ordering work naturally exposes a clean reusable record listing path.

## Open questions
- Should tie-breaking within a state stay in source order, sort by `updated_at`, or sort by label?
- Should `done` sessions remain visible in the compact bar forever, or should the picker become the better place for older `done` rows?
