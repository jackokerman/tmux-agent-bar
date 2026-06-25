---
id: 2026-06-25-tmux-agent-bar-session-ordering-and-picker
title: tmux-agent-bar session ordering and picker
state: ready-to-ship
createdAt: 2026-06-25T00:23:09.647Z
updatedAt: 2026-06-25T17:17:43.077Z
---

# tmux-agent-bar session ordering and picker

## Plan

# tmux-agent-bar session ordering and picker

## Goal
Make multiple agent sessions easier to scan and triage from tmux without adding background daemons, workflow-specific coupling, or hot-path render cost.

## Investigation summary
The current runtime shape is a good fit for a picker if the first version stays session-level and consumes the existing normalized row stream.

Confirmed from the repo:

- `bin/tmux-agent-bar` is still small and mostly composes shared shell helpers.
- Sources already emit normalized five-column rows: `session<TAB>agent<TAB>state<TAB>source<TAB>updated_at`.
- Recent churn has been narrow: state reconciliation, render ordering, and nounset-safe truncation. There is not broader CLI or source-contract churn right now.
- The current renderer and `current-state` path duplicate some row traversal logic, so a shared prioritized-record helper would reduce drift.
- Session labels are already valid tmux switch targets for the current public data model, so the first picker does not need a schema change to support selection.

Constraints that should continue to hold:

- The checked-in runtime stays bounded and launcher-agnostic.
- No always-on polling loop or background refresh daemon.
- No workflow-specific concepts such as deploys, devboxes, or sesh baked into the public repo.
- No destructive picker actions in the first version.

## Recommendation
Pick this up now, but narrow the first implementation.

The repo does not need a long cool-down period before a picker, because the recent churn has been concentrated in the same session-row pipeline the picker should reuse. The risk is not that the surface is too unstable; the risk is scope creep. A thin first version is the right tradeoff.

Recommended first cut:

- Add an optional `bin/tmux-agent-bar-picker` executable rather than growing `bin/tmux-agent-bar` subcommand dispatch further.
- Keep the picker flat and session-oriented.
- Reuse the same state priority and duplicate precedence as the status bar.
- Make `fzf` an optional runtime dependency of the picker only. The existing render path should keep working without it.
- Document tmux popup and `new-window` bindings as integration examples instead of baking popup orchestration deeply into the runtime.
- Defer preview panes and any pane/window-level navigation until the basic session switcher proves useful.

## Why this scope
This narrower shape keeps churn local to shared row listing plus one new executable.

It avoids three avoidable risks in the same change:

- adding a new row schema before it is needed
- coupling the runtime to tmux popup behavior too deeply
- taking on interactive preview performance questions before the basic picker exists

## Proposed implementation plan

### Phase 1: shared prioritized record listing
Add a shared helper, likely in a new `lib/records.sh`, that emits the same deduped, prioritized session rows for both the compact renderer and the picker.

Responsibilities:

- optionally refresh sources
- resolve the current session target when needed
- filter the current session when desired
- keep first-row-wins duplicate precedence
- sort by current actionable priority: `waiting`, `working`, `done`, then other non-empty states
- preserve source order within each state bucket

Expected outcome:

- renderer consumes the helper instead of reimplementing ordering logic
- picker can consume the exact same ordered rows
- focused regression tests cover ordering and duplicate precedence at the shared helper boundary

### Phase 2: picker executable
Add `bin/tmux-agent-bar-picker` as an opt-in interactive command.

Recommended behavior:

- fail clearly with a short message if `fzf` is unavailable
- gather prioritized rows using the shared helper
- display a human-readable table with at least `state`, `session`, `agent`, `source`, and age when `updated_at` is numeric
- keep a hidden machine-readable target column; for v1 this can just be the tmux session label
- on selection, run `tmux switch-client -t <session>`
- support a simple `ctrl-r` reload using `fzf --bind ...reload(...)`

Non-goals for v1:

- no kill/close actions
- no pane/window tree mode
- no background watcher or auto-refresh loop

### Phase 3: tmux integration docs
Document two example integrations instead of hard-coding them into the picker runtime:

- popup example for tmux versions that support `display-popup`
- `new-window` fallback example for terminals or tmux setups where popup use is weak

This keeps the executable composable and lets private setups wrap it however they want.

### Deferred follow-up
If the basic picker proves useful, add a second pass for optional preview content sourced from `tmux capture-pane`, bounded to a small line count and tested separately.

## Open decisions and recommended defaults

### Executable shape
Recommendation: separate executable.

Reason:

- interactive picker semantics and optional `fzf` dependency are distinct from the render CLI
- keeps `bin/tmux-agent-bar` stable for status-line callers
- lowers review risk by isolating the new behavior

### Secondary sort within a state
Recommendation: preserve source order for v1.

Reason:

- matches the current status bar exactly
- avoids surprising reordering across sources
- keeps the picker as a richer view of the same pipeline rather than a different prioritizer

### Handling `done` rows
Recommendation: keep current bar behavior unchanged for now.

Reason:

- the recent ordering change already made actionable states win before truncation
- hiding older `done` rows is a separate product decision and should not be bundled into picker delivery

### Public tmux binding example
Recommendation: document examples but do not bless a single default key yet.

Reason:

- the repo stays generic
- tmux key conflicts are personal and environment-specific
- users can copy the example and choose their own binding

## Gaps to resolve before implementation
These are small and should be resolved in code or docs, not by delaying the work indefinitely.

- Confirm the minimum acceptable behavior when `fzf` is missing: recommended answer is clear non-zero exit with one-line install/use message.
- Decide whether age formatting belongs in the picker executable or a tiny shared helper. Keep it local unless a second caller appears.
- Decide whether `ctrl-r` reload should re-run source refresh hooks or use cached rows. Recommended answer: refresh, because the picker is interactive and off the hot path.
- Decide whether the picker should no-op outside tmux or fail clearly. Recommended answer: fail clearly, because switching sessions without tmux is not meaningful.

## Verification plan
Keep verification focused and non-interactive.

- Add shell tests for the shared prioritized-row helper.
- Add shell tests for picker row formatting and target extraction with mocked `fzf` and mocked `tmux`.
- Add docs/examples coverage through existing repo checks plus any focused assertions needed for new snippets.
- Run `./scripts/check` before shipping.

## Ship criteria
This plan is ready to implement when the first cut is limited to:

- shared prioritized row helper
- optional `fzf` picker executable
- tmux binding documentation/examples
- no preview pane
- no new source schema
- no destructive actions
