---
id: 2026-07-02-add-session-status-explain-command
title: Add session status explain command
state: inbox
createdAt: 2026-07-02T18:45:51.938Z
updatedAt: 2026-07-08T18:29:21.768Z
---

# Add session status explain command

## Plan

## Why this exists

Debugging stale or surprising status rows currently requires knowing which source owns the row and then manually checking state files, pane commands, process ancestry, source rows, and captured tail inference. A generic explain command would make the state model easier to inspect without adding polling or broad renderer logic.

## Goal

Add a small read-only diagnostic command that explains why a session resolves to its current state.

## First slice

Add an `explain <session>` or similar CLI entrypoint that prints the selected normalized record plus useful fields already available in the generic runtime: session, agent, state, source, updated_at, whether the row came from explicit hook state or fallback inference, whether stale-working logic applied, and which broad path produced the row.

The command should support a cached or no-refresh mode so diagnosing a status-line issue does not trigger source refresh hooks or slow remote/cache update paths.

## Constraints

- Keep the command read-only and bounded.
- Do not add render-time polling.
- Do not move environment-specific transport details into the public runtime.
- Prefer reusing existing record emission and reconciliation helpers over adding a parallel state path.
- Avoid exposing full captured pane contents by default; report classifier decisions and concise reason labels instead.

## Verification

Add focused tests for local explicit rows, local fallback rows, stale working, no-agent hidden rows, source-provided rows, and cached/no-refresh behavior.
