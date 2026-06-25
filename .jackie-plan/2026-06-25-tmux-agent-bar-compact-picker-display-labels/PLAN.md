---
id: 2026-06-25-tmux-agent-bar-compact-picker-display-labels
title: tmux-agent-bar compact picker display labels
state: inbox
createdAt: 2026-06-25T01:03:26.300Z
updatedAt: 2026-06-25T01:04:34.686Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
sourceRepo: /Users/jackokerman/tmux-agent-bar
sourcePath: .
---

# tmux-agent-bar compact picker display labels

## Plan

# tmux-agent-bar compact picker display labels

## Goal
Tighten `tmux-agent-bar-picker` display labels so long launcher/session paths do not dominate the picker UI, while preserving the current full session label as the machine target.

## Context
The motivating case is a session label shaped like a path, for example:

```text
remote/src/project
```

For picker scanning, the final directory/session component is often the meaningful part. Rendering the full path adds noise and burns horizontal space. At the same time, the repo's current source contract treats `session_label` as the identity: it is used for dedupe, shadowing, current-session filtering, state files, and `tmux switch-client -t` targets.

## Recommendation
Separate display label from target identity in the picker only.

- Keep the normalized row contract unchanged: `session_label<TAB>agent<TAB>state<TAB>source<TAB>updated_at`.
- Keep `session_label` as the exact tmux target used for switching.
- Render a compact display label in the picker, initially based on the basename/final path component.
- If compact display labels collide, qualify just enough parent context to disambiguate.
- Do not require a launcher naming change for the public repo feature.
- Do not add launcher-specific assumptions to checked-in code or docs.

Example display behavior:

```text
remote/src/project -> project
```

If there is a collision:

```text
local/project -> local/project
remote/src/project -> src/project
```

## Implementation shape
This likely belongs in the picker executable or a tiny picker-local helper, not in the shared renderer.

The picker can keep a hidden machine-readable target column containing the full `session_label`, while showing the compact label in the human-facing table. The status bar should continue rendering the current session label unless a separate status-label decision is made later.

## Open decisions
- Decide whether compact labels should apply only to path-like labels containing `/`, or also to other launcher-shaped names if a future generic heuristic is obvious.
- Decide how much parent context to reveal for collisions. Recommended default: reveal one parent at a time from the right until labels are unique.
- Decide whether the full target should be visible in a secondary column or only in an `fzf` preview/footer. Recommended default: keep the main table compact and include the full target only where it helps debugging.

## Verification
- Add tests for compact label formatting with path-like labels.
- Add tests for collision disambiguation.
- Add tests that picker selection still switches using the original full session label.
- Run `./scripts/check`.
