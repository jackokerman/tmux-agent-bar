---
id: 2026-07-02-add-session-status-explain-command
title: Add session status explain command
state: inbox
createdAt: 2026-07-02T18:45:51.938Z
updatedAt: 2026-07-02T18:45:51.938Z
---

# Add session status explain command

## Plan

## Why this exists

Debugging stale or surprising status rows currently requires knowing which source owns the row and then running source-specific helpers such as `tmux-agent-devvy-debug`. A generic explain command would make the state model easier to inspect without adding polling or broad renderer logic.

## Goal

Add a small read-only diagnostic command that explains why a session resolves to its current state.

## First slice

Add an `explain <session>` or similar CLI entrypoint that prints the selected normalized record plus useful source fields already available in the generic runtime: session, agent, state, source, updated_at, whether the row came from explicit hook state or fallback inference, and any stale-working decision when available. Keep source-specific remote details outside the generic command unless the source already emits them through a stable contract.

## Constraints

- Keep the command read-only and bounded.
- Do not add render-time polling.
- Do not move private devbox-specific transport details into the public repo.
- Prefer reusing existing record emission and reconciliation helpers over adding a parallel state path.

## Verification

Add focused tests for local explicit, local fallback, stale working, and source-provided rows.
