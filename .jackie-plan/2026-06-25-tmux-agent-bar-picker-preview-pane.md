---
id: 2026-06-25-tmux-agent-bar-picker-preview-pane
title: tmux-agent-bar picker preview pane
state: inbox
createdAt: 2026-06-25T00:47:17.114Z
updatedAt: 2026-07-15T04:43:10.205Z
sourcePlan: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
---

# tmux-agent-bar picker preview pane

## Plan

## Objective

Design and add a richer picker/TUI experience on top of the public `tmux-agent-bar` row API, without coupling the picker to private adapters, status-wrapper internals, or transport behavior.

This remains a design follow-up, not implementation-ready, until the public platform plan has settled the stable row-listing contract.

## Dependency

This work depends on `2026-07-14-design-shareable-remote-adapter-package` (`Harden public adapter platform`) for the stable `rows` / `rows-cached` consumer contract.

The picker should consume the same public row command that third-party TUIs would consume. It should not source internal helpers directly once the public row command exists, and it should not assume any proprietary adapter fields.

## Design inputs to resolve

- UI shape: decide whether this remains a flat agent-session picker, grows a grouped/tree view, or supports multiple modes.
- Display fields: decide what belongs beyond the status bar, such as full target, compact path label, agent, source, age, current state, and bounded pane preview.
- Ordering: decide whether the interactive picker should mirror status ordering exactly or add a documented interactive ordering mode.
- Data contract: decide whether the stable TSV row API is enough for the first richer picker, or whether a JSON projection is justified by an actual UI need.
- Key binding: choose the recommended tmux binding. Current docs show `prefix + A` for a popup and `prefix + a` for a new window; an inspiration repo uses `prefix + S` for a popup switcher.
- Popup size: choose a default popup geometry. One reference shape is a compact popup when preview is hidden and a larger popup when preview is visible.
- Preview pane: decide whether preview is always visible, toggled, or shown only for richer modes. The likely preview is recent output from the highlighted local tmux session or pane via bounded `tmux capture-pane`.

## Reference notes

- Existing public tmux switchers are useful as interaction references, but this picker should keep its data model independent of any one launcher or session manager.
- `samleeney/tmux-agent-status` has a hierarchical `fzf` switcher and an agents mode. The agents mode is a flat list sorted by status priority (`ask`, `done`, `working`, `wait`, `parked`), uses a live preview pane, and documents `prefix + S` as the main switcher binding.
- Popup wrappers may need to relaunch tmux popups to change dimensions because popups cannot be resized in flight. That may be useful if this picker supports toggling preview on and off.

## Implementation constraints once design is settled

- Consume the public row command rather than private shell internals.
- Keep preview output bounded and avoid background polling or status-renderer work.
- Preserve hidden full target selection so compact display labels do not change switch behavior.
- Keep adapter-specific fields out of the public picker unless they come through a documented row/API extension.
- Keep `ctrl-r` reload behavior unless the new design replaces it deliberately.
- Add focused tests for fzf arguments, preview command wiring, ordering, target extraction, and any documented key binding changes.
- Update README and adjacent install docs only after the final user-facing picker behavior is chosen.

## Non-goals

- Do not build transport, remote probing, or adapter setup into the picker.
- Do not add destructive actions such as killing sessions in this pass.
- Do not add a separate data schema just for the picker if the public row API can support the design.
- Do not make the picker require a proprietary adapter or source module.

## Acceptance criteria

- The picker design names the exact public row command it consumes.
- A future third-party TUI could use the same row contract without reading picker internals.
- Preview behavior is bounded and local to tmux capture or another documented public source.
- The design states whether TSV is sufficient or JSON is required for a concrete reason.
- Implementation can proceed without changing the remote adapter or tmux status refresh architecture.

## Agent handoff

Original design input and public-tool research remain useful: a reference switcher uses `prefix + S`, a flat agents mode sorted by actionable status, live `tmux capture-pane` preview, and separate compact/larger popup shapes depending on preview visibility. The plan is now explicitly blocked on the public row API/platform hardening work so the richer picker becomes a consumer of the same contract as external TUIs.
