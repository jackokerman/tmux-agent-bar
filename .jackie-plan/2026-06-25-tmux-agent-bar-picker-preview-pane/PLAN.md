---
id: 2026-06-25-tmux-agent-bar-picker-preview-pane
title: tmux-agent-bar picker preview pane
state: inbox
createdAt: 2026-06-25T00:47:17.114Z
updatedAt: 2026-06-26T00:40:52.719Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
---

# tmux-agent-bar picker preview pane

## Plan

Design and add a richer `tmux-agent-bar-picker` experience once the picker UI contract is clear. This is not implementation-ready until the UI, displayed fields, ordering, key binding, popup size, and preview behavior are decided.

Design inputs to resolve:

- UI shape: decide whether this remains a flat agent-session picker, grows a grouped/tree view, or supports multiple modes.
- Display fields: decide what extra information belongs in the picker beyond the status bar, such as full target, compact path label, agent, source, age, window/pane metadata, current command, or current path.
- Ordering: decide whether the current status-bar ordering is still right for interactive picking, or whether the picker should prioritize actionable states, recency, session name, or source grouping differently.
- Key binding: choose the recommended tmux binding. Current docs show `prefix + A` for a popup and `prefix + a` for a new window; the inspiration repo uses `prefix + S` for the popup switcher.
- Popup size: choose a default popup geometry. The inspiration repo uses a compact `60x14` popup when preview is hidden and `75% x 60%` when preview is visible.
- Preview pane: decide whether preview is always visible, toggled, or shown only for richer modes. The likely preview is recent output from the highlighted agent window or pane via bounded `tmux capture-pane`.

Reference notes:

- `sesh picker` is a useful baseline for a focused tmux picker surface. Locally it exposes flags for tmux sessions, configured sessions, zoxide results, icons, duplicate hiding, attached-session hiding, and separator-aware matching; `sesh preview` exists as a separate preview command.
- `samleeney/tmux-agent-status` has a hierarchical `fzf` switcher and an agents mode. The agents mode is a flat list sorted by status priority (`ask`, `done`, `working`, `wait`, `parked`), uses a live preview pane, and documents `prefix + S` as the main switcher binding.
- The inspiration repo's popup wrapper relaunches tmux popups to change dimensions because popups cannot be resized in flight. That may be useful if this picker supports toggling preview on and off.

Implementation constraints once design is settled:

- Keep preview output bounded and avoid background polling or status-renderer work.
- Preserve hidden full target selection so compact display labels do not change switch behavior.
- Keep `ctrl-r` reload behavior unless the new design replaces it deliberately.
- Add focused tests for fzf arguments, preview command wiring, ordering, and any documented key binding changes.
- Update README and adjacent install docs only after the final user-facing picker behavior is chosen.
