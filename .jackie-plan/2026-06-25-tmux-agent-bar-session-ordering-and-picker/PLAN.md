---
id: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
title: tmux-agent-bar session ordering and picker
state: inbox
createdAt: 2026-06-25T00:23:09.647Z
updatedAt: 2026-06-25T00:29:45.470Z
---

# tmux-agent-bar session ordering and picker

## Plan

# tmux-agent-bar session ordering and picker

## Goal
Make multiple agent sessions easier to scan and triage from tmux.

## Current behavior
`tmux-agent-bar` renders records from registered sources, filters the current session, keeps the first row per label, and truncates to the available status width.

The compact renderer now has an explicit state priority before truncation:

1. `waiting`
2. `working`
3. `done`
4. unknown non-empty states

Within each state, rows preserve source order. Source collection, duplicate precedence, and current-session filtering are unchanged.

## Inspiration review
Reviewed `https://github.com/samleeney/tmux-agent-status` at commit `037af05`. Useful ideas for this repo:

- A tmux popup `fzf` switcher is a good complement to a compact status line.
- A fallback `new-window` display mode is useful for tmux versions or terminals where popups are weak.
- Rows should carry an explicit target token so `Enter` can switch to a session/window/pane without fragile display parsing.
- A preview pane showing recent tmux pane output is likely the highest-value extra detail.
- Manual refresh with `ctrl-r` should exist. Auto-refresh can be considered later, but should not add a daemon or polling loop to the hot status path.
- A future picker can support richer modes, but the first version should stay flat and session-oriented because this repo currently tracks session-level records.

Ideas to avoid or defer from that project:

- Do not add an always-on sidebar daemon to the core runtime.
- Do not add workflow-specific deploy, remote setup, or launcher concepts to checked-in sources.
- Do not make destructive actions such as close/kill part of the first picker version.
- Do not hard-depend on Sesh. Provide a generic command and documented tmux binding; Sesh or private picker integrations can compose with that command externally.

## Picker proposal
Add an optional picker command that reads the same registered records as the renderer and presents richer rows in `fzf`.

Initial scope:

- Add a command such as `bin/tmux-agent-bar-picker` or a `picker` subcommand on `bin/tmux-agent-bar`.
- Support `tmux display-popup` when available, plus a simple `new-window` fallback.
- Provide a documented tmux binding example, with a configurable key left to the user. Candidate binding: `prefix + S` if not already used locally.
- Keep the command composable so a Sesh picker or private workflow can call it instead of this repo knowing about Sesh.
- Show flat session rows sorted with the same actionable priority as the status bar.
- Include at least: state, session label, agent, source, and updated age when available.
- Use a hidden machine-readable target field rather than parsing formatted display text.
- `Enter` switches to the selected tmux session.
- `ctrl-r` refreshes the row list.
- Optional preview: show recent pane output for the selected session with `tmux capture-pane`, bounded to a small number of lines.

Deferred picker ideas:

- Toggle between a flat agent-session list and a tree/list of session, window, and pane targets if the repo grows pane-level records.
- Add a `next actionable` command that follows the same ordering as the picker.
- Add wait/snooze or park/hide concepts only if there is a clear user-facing need and a generic state contract. These should not be implemented as private workflow assumptions.
- Add close/kill actions only with confirmation and tests, if ever.
- Consider aggregate summary mode for very large session counts, but do not replace the current per-session compact bar unless truncation remains painful after the picker exists.

## Implementation notes

- Preserve bounded status rendering. Do not introduce polling loops, unbounded process scans, or slow work in render truncation.
- Keep the public repo generic, launcher-agnostic, and environment-agnostic.
- Prefer a shared record-listing/sorting helper so the compact renderer and picker do not diverge.
- Add focused regression tests for row sorting, target parsing, tmux switching command construction, and binding docs/examples.
- Keep Sesh integration as documentation or an external/private module unless there is a generic, dependency-free interface to expose.

## Open questions

- Should the picker live as a `picker` subcommand or as a separate executable?
- Should tie-breaking within a state remain source order, or should the picker use a secondary sort such as label or `updated_at`?
- Should `done` sessions remain visible in the compact bar indefinitely, or should older `done` rows be primarily discoverable through the picker?
- What tmux binding should the public example recommend without conflicting with common user setups?
