---
id: 2026-06-25-tmux-agent-bar-follow-ups-after-hook-runtime-fix
title: tmux-agent-bar follow-ups after hook/runtime fix
state: inbox
createdAt: 2026-06-25T15:46:58.869Z
updatedAt: 2026-07-08T18:29:21.714Z
sourcePlan: 2026-06-24-harden-tmux-agent-bar-state-model
---

# tmux-agent-bar follow-ups after hook/runtime fix

## Plan

## Why this exists

The status bar is hook-first, but local fallback behavior still matters for wrapped panes, remote connector panes, and prompt states that hooks do not expose. These follow-ups keep that fallback narrow, explainable, and cheap to run.

## Follow-ups to consider

- Re-check the Codex hook surface periodically and remove tail-based waiting inference if Codex adds a dedicated hook for in-turn questions or plan confirmation prompts.
- Document the tail-discovery contract in `docs/agents.md` and/or `README.md`: fallback discovery is bounded, does not persist state, requires agent identity evidence, and should stay behind explicit hook/process state.
- Add captured-shape regression fixtures for wrapper sessions that lack a local agent process, including footerless active Codex UI and external connector or retry screens that should stop stale transcript inference.
- Keep treating external connector or retry screens as terminal boundaries for tail inference so older agent transcript above the current screen cannot leak into `working`.
- Consider an explicit alias or registration path for nonstandard agent launch names so local machine-specific binaries do not require broader built-in command matching over time.
- Revisit whether shell-wrapper process inference should remain enabled by default, or whether it should become opt-in or more tightly scoped.
- If shell-wrapper inference stays, keep reducing its scope so it only runs for sessions that actually need it.
- Add a focused performance regression test or benchmark around local snapshot/render latency on large process tables.
- Revisit whether any waiting-state detection can move closer to hook-triggered or current-session-triggered refresh boundaries without missing unsupported prompt states.

## Current assessment

The stable path is explicit hook state plus direct process detection. Tail parsing is a fallback, not a writer, and it should remain conservative: prefer a missed fallback row over a false active row. The highest-risk area is inferring state from visible terminal text after wrappers or connector UIs take over the pane.

## Verification guidance

For future changes in this area, add tests that cover both sides of each heuristic: one active agent shape that must render and one stale or copied transcript shape that must stay hidden.

## Agent handoff

Captured follow-up backlog after the hook/runtime fix. No runtime changes were made in this plan entry, and the item remains `inbox`.

Key findings recorded here:
- Official Codex hooks still cover lifecycle and approval events, but not arbitrary in-turn question or plan-confirmation waiting states.
- The slow path observed during debugging was the shell-wrapper process scan, not pane-tail parsing.
- Direct pane command detection now handles `codex-*` variants before falling back to process inference.

Next work captured by the plan:
- Re-check Codex hook coverage periodically so tail-based waiting inference can be removed if a dedicated waiting hook appears.
- Consider an explicit alias/registration path for nonstandard Codex launch names instead of widening built-in command matching.
- Revisit whether shell-wrapper inference should remain enabled by default and, if it does, keep narrowing when it runs.
- Add focused performance coverage around local snapshot/render latency on large process tables.
