---
id: 2026-07-02-add-session-status-explain-command
title: Add session status explain command
state: paused
createdAt: 2026-07-02T18:45:51.938Z
updatedAt: 2026-07-09T22:38:48.229Z
---

# Add session status explain command

## Plan

## Folded into umbrella plan

This plan has been folded into `2026-06-25-tmux-agent-bar-follow-ups-after-hook-runtime-fix` as Phase 2 of the broader state-model stabilization work.

Do not implement this plan independently. The controlling implementation contract now lives in the umbrella plan, which sequences the explain command after executable state-contract tests and before the local collector refactor.

## Preserved intent

The explain command should remain a read-only diagnostic path that answers why a session resolved to its current visible or hidden state. It should report concise evidence and reason fields without exposing full pane contents by default, and it should include a cached/no-refresh mode for diagnosing status-line behavior without triggering source refresh hooks.

The umbrella plan owns the current CLI shape, output format, fields, verification cases, and stopping points.
