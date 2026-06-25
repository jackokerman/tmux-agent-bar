---
id: 2026-06-25-tmux-agent-bar-right-to-left-stable-status-ordering
title: tmux-agent-bar right-to-left stable status ordering
state: complete
priority: high
createdAt: 2026-06-25T01:22:19.265Z
updatedAt: 2026-06-25T19:51:35.436Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
sourceRepo: /Users/jackokerman/tmux-agent-bar
sourcePath: .
---

# tmux-agent-bar right-to-left stable status ordering

## Plan

# tmux-agent-bar right-to-left stable status ordering

## Goal
Make the compact status bar match a right-to-left scanning workflow.

The current shipped ordering prioritizes states for collection/truncation, but the visual order is still not right for a user who reads the status segment from the right edge inward.

## Current shipped behavior
`lib/records.sh` emits prioritized rows in this order:

1. `waiting`
2. `working`
3. `done`
4. other non-empty states

`lib/render.sh` formats records in the order it receives them. In a typical `status-right` placement, the later rendered items are closer to the far right edge. That means the shipped picker/session-row work gives actionable rows priority, but it does not guarantee that yellow waiting items sit at the immediate right edge.

Within each state bucket, rows currently preserve source order. There is no durable last-state memory and no explicit completion ordering beyond whatever `updated_at` source rows already carry.

## Clarified desired behavior
For the compact status bar, optimize visual scan order from right to left:

1. Yellow `waiting` sessions that require input should be at the immediate right edge.
2. Green `done` sessions should be next, ordered so the tasks that wrapped up earliest are encountered first while scanning right to left.
3. Blue `working` sessions are background work and should sit behind waiting/done items in the right-to-left scan.
4. If a session moves from green or yellow back to blue `working`, it should move toward the back of the blue section rather than staying in the urgent/right-edge area.

In other words, keep `waiting` as the most urgent state, but separate two concepts:

- truncation priority: which records survive when width is constrained
- visual scan order: where accepted records appear in the rendered status string

## Recommended implementation direction
Keep the existing shared priority helper as the truncation/input priority source, but add a status-bar-specific visual ordering step before final output.

Recommended default visual order for right-to-left status rendering:

- left-to-right render string: `working`, then `done`, then `waiting`
- right-to-left scan result: `waiting`, then `done`, then `working`

Do not apply this blindly to the picker unless there is a clear reason. The picker can stay priority-list oriented because it is not constrained by the physical right edge in the same way.

## Completion ordering
For green `done` rows, prefer an existing timestamp over adding persistent ordering state.

Candidate rule:

- For `done` rows with numeric `updated_at`, sort ascending by `updated_at` within the done section, so the earliest completed item is closest to the right edge among done items when rendered with the status visual order.
- Rows without numeric `updated_at` keep source order after timestamped rows, unless tests reveal a better fallback.

This should be verified against local explicit rows, where `updated_at` comes from the state file mtime, and remote cache rows, where the source controls `updated_at`.

## Configurability
Default to the right-to-left visual order. A configuration knob can be considered, but it is optional and should not be added unless the implementation is still simple.

If added, keep it generic and small, for example an environment/config variable that selects status visual order only. Avoid introducing launcher-specific config or a broader preference system.

## Constraints
- Preserve bounded status rendering and avoid slow work in the hot path.
- Keep source order and duplicate precedence understandable.
- Do not add launcher-specific assumptions.
- Avoid background polling or persistent ordering state unless existing timestamps are insufficient.
- Add focused tests for state transitions, timestamp sorting, and width truncation.

## Open questions
- Should the right-to-left visual order be the default unconditionally, or should it be configurable from the start?
- For `done` rows without numeric `updated_at`, should source order place them closer to or farther from the right edge than timestamped rows?
- Should `other` states render behind `working`, or stay last/least important for truncation only?

## Verification
- Add renderer tests showing yellow `waiting` rows render at the right edge in `status-right` scan order.
- Add renderer tests showing `done` rows sort by earliest completion within the done section.
- Add a transition-oriented test: a row changing from `done` or `waiting` to `working` moves into the back/background blue section.
- Add truncation tests proving `waiting` rows still survive constrained width over lower-priority rows.
- Run `./scripts/check`.
