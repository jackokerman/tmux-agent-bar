---
id: 2026-06-25-tmux-agent-bar-compact-picker-display-labels
title: tmux-agent-bar compact picker display labels
state: complete
createdAt: 2026-06-25T01:03:26.300Z
updatedAt: 2026-06-25T21:50:14.616Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
---

# tmux-agent-bar compact picker display labels

## Plan

## Goal
Tighten `tmux-agent-bar-picker` display labels so long path-like session names do not dominate the picker UI, while preserving the current full `session_label` as the tmux switch target and normalized record identity.

## Scope
- Keep the normalized row contract unchanged everywhere outside the picker.
- Add picker-local compact label generation for display only.
- Compact path-like labels to the final path component by default.
- When compact labels collide, reveal parent path segments from the right until each visible label is unique.
- Keep the hidden first picker column as the original full target used for `tmux switch-client -t`.

## Implementation notes
Implement the label logic inside `bin/tmux-agent-bar-picker`, not in the shared renderer or source contract. Keep non-path labels unchanged unless they collide with another identical display label.

## Verification
- Extend `tests/test-picker.sh` to cover compact labels for path-like session names.
- Add a collision case that verifies incremental parent qualification.
- Preserve the existing assertion that picker selection switches using the full hidden target.
- Run `./scripts/check`.

## Agent handoff

Implemented picker-local compact session labels without changing the shared row contract. `bin/tmux-agent-bar-picker` now compacts path-like session names to the trailing component and reveals additional parent segments only when collisions remain, while the hidden first column still carries the full `session_label` target for `tmux switch-client -t`. Added a deterministic picker test that covers collision disambiguation and preserved the existing switch-target assertion, then updated the README picker section and verified with `tests/test-picker.sh` and `./scripts/check`.
