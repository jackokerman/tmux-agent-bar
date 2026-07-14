---
id: 2026-07-14-design-shareable-remote-adapter-package
title: Design shareable remote adapter package
state: inbox
createdAt: 2026-07-14T20:37:15.124Z
updatedAt: 2026-07-14T20:37:15.124Z
sourcePlan: 2026-07-14-evaluate-remote-activity-heuristics
---

# Design shareable remote adapter package

## Plan

## Objective

Design a separate remote adapter package or overlay for `tmux-agent-bar` that can be installed by another user without moving remote transport, launcher, setup, or workflow-specific logic into the public core.

## Context

The public core should keep owning only the generic status-line runtime: hook state, local evidence reconciliation, source registration, normalized row/cache consumption, replacement shadowing, ordering, rendering, and explain output.

A shareable adapter can make stronger environment assumptions that do not belong in the public core. The likely model is:

- the user has a local tmux session representing remote work;
- the remote environment runs a nested tmux session where the agent actually runs;
- the adapter maps the local session label to the remote tmux session or pane;
- the adapter installs or documents the needed local source module and remote hook/module setup;
- the adapter writes normalized `remote-rows.tsv` rows and optional `shadowed-sessions.txt` entries for replacement rows;
- the adapter owns remote probing, transport/reconnect policy, stale cache preservation, transcript/tail inference, output-volume heuristics, submit/startup/resize grace, and remote setup repair.

## Acceptance direction

- Keep the core package installable and useful without the adapter.
- Keep adapter installation explicit, documented, and reversible.
- Decide whether the adapter should vendor, depend on, or bootstrap the public core.
- Decide how hard the nested-remote-tmux assumption should be and document it directly if it is required.
- Once the adapter owns remote stale-working policy, revisit whether `tmux_agent_bar_remote_state_is_stale_working` should move out of the public core or be renamed to a generic mtime helper.
- Do not add remote transport, host discovery, setup wizard, or team-specific workflow details to the public core while designing this.
