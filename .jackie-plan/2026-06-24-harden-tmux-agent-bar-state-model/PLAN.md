---
id: 2026-06-24-harden-tmux-agent-bar-state-model
title: Harden tmux-agent-bar state model
state: ready-to-implement
createdAt: 2026-06-24T22:21:37.150Z
updatedAt: 2026-06-24T22:22:53.880Z
---

# Harden tmux-agent-bar state model

## Plan

## Context

`tmux-agent-bar` should be stable and simple: hooks write explicit agent state, the renderer reads state records, and tmux displays a compact status segment. Recent fixes addressed stale Codex `working` state caused by old transcript lines, but the deeper goal is to reduce parser-driven flapping and keep the architecture understandable.

A concrete recent failure class: a completed Codex session can remain blue `working` when old transcript lines are still interpreted as live state. Commit `cd2e757` taught Codex tail inference to stop at the latest completed-turn boundary (`Worked for ...`), so old transcript above that boundary cannot refresh the explicit `working` heartbeat. That fix expresses a general boundary rule, but the remaining hardening work should make the state contract sharper instead of accumulating parser exceptions.

## Desired architecture

The stable model should be boring:

1. Hooks write durable explicit state records: `working`, `waiting`, or `done`.
2. Sources emit normalized rows.
3. Reconciliation applies a small documented precedence model.
4. Rendering only formats rows and filters the current session.
5. Pane-tail inference is a narrow fallback for states hooks do not expose, especially live prompts that require input.

Live pane inspection should not become the effective source of truth for completed turns. It can provide an ephemeral display state, and it can help stale `working` state expire, but it should not keep historical transcript state alive forever.

## Current transition points to audit

- `bin/tmux-agent-bar-hook`
  - Writes explicit durable state files.
  - Should remain the primary mutation path for normal lifecycle state.

- `bin/tmux-agent-bar-codex-hook`
  - Maps Codex events to explicit state.
  - Current mapping: `PermissionRequest -> waiting`, `UserPromptSubmit|PreToolUse|PostToolUse -> working`, `SessionStart|Stop -> done`.

- `lib/local-collector.sh`
  - Detects live agent processes and emits `local_explicit` or `local_fallback` rows.
  - Current brittle point: explicit `working` plus live `working` touches the state file as a heartbeat.
  - Current fallback behavior: sessions without explicit state but with live agent panes render from tail inference or `done`.

- `lib/reconcile.sh`
  - Applies explicit/live/stale precedence.
  - Current behavior lets visible `waiting` override explicit state, lets visible `working` revive explicit `done`, and expires stale explicit `working` to `done`.

- `lib/tail.sh`
  - Classifies pane tail text into `waiting`, `working`, or neutral.
  - Codex inference now stops at completed-turn boundaries, but generic/custom classifiers still scan tail history until they find a match.

## State precedence target

Use this as the implementation target unless local tests reveal a concrete incompatibility:

1. No agent process for a known explicit `done` row: remove the stale state file and hide the session.
2. Agent command mismatch for an explicit row: treat the explicit row as `done` for display; do not let a previous agent type keep control of the row.
3. Visible current waiting prompt: display `waiting`; this may override explicit `working` or `done` because user attention is required.
4. Explicit `working` with a clearly current live working marker: display `working`; this may refresh the heartbeat only if the marker is below the latest completion/idle boundary.
5. Explicit `working` with no current live marker and stale mtime: display `done`.
6. Explicit `done`: display `done` unless there is a clearly current live working marker or waiting prompt.
7. No explicit row but a live agent pane: emit `local_fallback` from current live inference, or `done` when the pane is neutral.
8. No explicit row and no live agent pane: emit nothing.

## Implementation plan

### Phase 1: Document the contract

- Add a concise state model section to the repo, likely in `docs/agents.md` with a short pointer from `README.md`.
- Cover durable hook state, fallback inference, row sources, shadowing, TTL cleanup, and render-only behavior.
- Explicitly state that source modules should emit rows or shadow local rows; they should not rely on renderer-specific side effects.

### Phase 2: Add characterization tests before changing behavior

Add tests that describe lifecycle behavior rather than only matching transcript strings:

- Hook writes `working`, then `done`; displayed state stays done when the pane tail is idle.
- Old `working` transcript above a completed-turn boundary cannot revive `working`.
- Current-turn `working` below the latest boundary still renders `working`.
- Waiting prompts below the latest boundary override explicit `done` and `working`.
- Waiting prompts above a completed-turn boundary do not override current explicit `done`.
- Missing explicit state with a live agent pane emits `local_fallback` without creating a durable state file.
- Stale explicit `working` expires to `done` when live inference is neutral.
- Live inference that is neutral must not touch or refresh the state file.
- A live `working` heartbeat should touch the state file only when the inference is clearly current; if this rule is hard to prove, prefer removing the heartbeat and relying on hook writes plus TTL.

### Phase 3: Clarify live inference freshness

- Introduce an internal concept of a current-turn inference result if needed. Keep it shell-simple, such as returning state only from below a known boundary.
- Codex already has a completed-turn boundary. Consider whether generic classifiers should support an optional boundary function instead of scanning all history.
- Do not build a full terminal parser. The boundary abstraction should remain small and agent-specific.

### Phase 4: Tighten local collector mutation rules

- Isolate durable writes to hook entrypoints and cleanup paths.
- Revisit `_touch_state_file` in `lib/local-collector.sh`:
  - Option A: keep it only for explicit `working` plus fresh, current `working` inference.
  - Option B: remove the heartbeat entirely and rely on hooks plus stale expiry.
- Prefer Option B if tests show hooks are frequent enough for normal Codex runs. Prefer Option A only if removing heartbeat makes active long-running turns expire incorrectly.
- Make any retained heartbeat rule explicit in code and tests.

### Phase 5: Keep reconciliation small

- Keep `tmux_session_status_resolve_state` as the single local precedence function.
- Avoid spreading precedence conditionals across collector and renderer.
- If needed, rename arguments or add a short comment so callers can tell which inputs are durable and which are ephemeral.

### Phase 6: Verify and ship

- Run focused tests:
  - `./tests/test-pane-state.sh`
  - `./tests/test-session-status.sh`
  - `./tests/test-session-status-local.sh`
- Run full suite: `./scripts/check`.
- Inspect `git status --short --branch` and `git log --oneline origin/main..HEAD` before pushing.
- Commit and push to `main` with a conventional commit.

## Non-goals

- Do not build a daemon, polling loop, background watcher, or unbounded process scanner.
- Do not add private launcher or environment-specific assumptions to the public repo.
- Do not turn transcript parsing into a full UI parser.
- Do not add compatibility branches unless they encode a general boundary, freshness, or precedence rule.
- Do not make the renderer responsible for state interpretation beyond formatting rows.

## Open questions

No blocker before implementation, but decide during Phase 4:

- Should `local-collector` keep any state-file heartbeat from live inference, or should hooks be the only normal durable write path?

The conservative implementation path is to write characterization tests first, try removing or narrowing the heartbeat, and keep whichever behavior preserves active long-running turns without reviving completed transcript history.

## Success criteria

- The repo documents an explicit state precedence model.
- Durable hook state and ephemeral fallback inference are distinguishable in code and tests.
- Stale transcript history cannot keep an agent blue forever.
- Active turns still stay visibly `working` while they are actually current.
- Main lifecycle behavior is covered by tests that would catch future flapping regressions.
- `./scripts/check` passes before commit/push.
