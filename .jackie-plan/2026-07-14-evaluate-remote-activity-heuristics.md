---
id: 2026-07-14-evaluate-remote-activity-heuristics
title: Evaluate remote activity heuristics
state: inbox
createdAt: 2026-07-14T17:42:12.584Z
updatedAt: 2026-07-14T17:42:12.584Z
sourcePlan: 2026-07-11-document-remote-adapter-contract
---

# Evaluate remote activity heuristics

## Plan

## Objective

Decide whether `tmux-agent-bar` should add a small generic helper, fixture, or contract test for remote adapter activity classification, based on the adapter guidance in `docs/sources.md`.

The target outcome is a deliberate implementation decision, not a remote adapter in the public repo.

## Context

Remote adapters that own a terminal, PTY, or stream can classify active work more reliably than a process-alive check by combining explicit lifecycle events, a short submit grace period, output-volume windows, startup grace, resize grace, stale-working TTLs, and cache-preserving probe failure behavior.

The public core should stay launcher-agnostic. Any implementation must consume or validate generic rows, cache files, shadowing files, and timestamps only. Transport, host discovery, reconnect policy, PTY ownership, and session creation remain adapter responsibilities.

## Scope

- Audit whether existing helpers such as `tmux_agent_bar_reconcile_remote_state` and `tmux_agent_bar_remote_state_is_stale_working` are intentional adapter-facing API, dead code, or should be covered by tests.
- Decide whether a generic shell helper for adapter authors would reduce duplication without pulling transport behavior into the core.
- Consider a focused fake-adapter fixture that proves output-derived activity can be collapsed to normalized rows before the renderer sees it.
- Keep docs and tests generic; use placeholder names such as `remote`, `devbox`, `/workspace/project`, and `agent-session`.

## Non-goals

- Do not implement a built-in remote source.
- Do not add a daemon, supervisor, web UI, polling loop, PTY manager, SSH wrapper, or reconnect behavior to the checked-in runtime.
- Do not add private connector names, company-specific paths, private host naming, or one user's launcher workflow to docs, fixtures, or tests.
- Do not make the renderer inspect byte streams or transcript content for remote rows.

## Proposed approach

1. Inspect current remote-related helpers, docs, and tests to determine whether any API is unused or underdocumented.
2. If helpers are kept, add focused tests and docs that show adapter-owned stale-working reconciliation without transport details.
3. If helpers are not worth keeping, remove them and leave the byte-volume/startup/resize guidance as adapter documentation only.
4. If a fixture is useful, model only normalized adapter output and cache freshness, not real PTY behavior.
5. Run `./scripts/check`.

## Acceptance criteria

- The public repo has either documented, tested adapter-facing helpers or no unused remote reconciliation helper code.
- Any new test proves a public contract, not one private workflow.
- `docs/sources.md` remains the source of truth for adapter-owned status classification guidance.
- `./scripts/check` passes.
