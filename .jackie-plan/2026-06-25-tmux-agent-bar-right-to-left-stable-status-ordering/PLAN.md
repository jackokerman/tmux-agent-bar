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

# tmux-agent-bar right-to-left stable status ordering

## Plan

## Goal
Make the compact status bar easier to scan for users who read agent status from right to left.

When an agent finishes working, it should not be appended to the far right of the status segment just because its state changed. The user should be able to scan the visible items in a predictable order instead of having completed sessions appear at the right edge and disrupt the reading flow.

## Context
The current renderer groups rows by actionable state priority before truncation:

1. `waiting`
2. `working`
3. `done`
4. other non-empty states

That prioritizes actionable sessions, but it can also move a session between buckets when its state changes. For a right-to-left reader, a session transitioning from `working` to `done` may effectively jump to the far side of the segment, which makes the bar feel noisy.

## Desired behavior
Preserve actionable prioritization without causing newly completed sessions to appear as the newest/rightmost item.

Potential directions:

- Treat the right edge as the oldest or least-surprising side, not the place where newly completed work lands.
- Keep state priority for truncation, but consider rendering accepted items in an order that is stable for right-to-left scanning.
- Consider whether `done` rows should stay in their prior relative position for a short time or sort behind still-actionable rows without appending at the far right.
- Avoid adding background polling or persistent ordering state unless the behavior cannot be achieved from existing records.

## Constraints
- Preserve bounded status rendering and avoid slow work in the hot path.
- Keep source order and duplicate precedence understandable.
- Do not add launcher-specific assumptions.
- Add focused tests for ordering changes, especially state transitions and width truncation.

## Open questions
- Is the right-to-left scan order a status-bar-only concern, or should the picker mirror the same visual order?
- Should completed rows be rendered left of actionable rows, or should the segment preserve first-seen/source order while using priority only for truncation?
- Is any lightweight timestamp or last-state memory needed, or can this stay stateless?

## Verification
- Add renderer tests covering a `working` row transitioning to `done` without becoming the rightmost visible item.
- Add truncation tests to ensure `waiting` and `working` rows still win over `done` rows under constrained width.
- Run `./scripts/check`.
