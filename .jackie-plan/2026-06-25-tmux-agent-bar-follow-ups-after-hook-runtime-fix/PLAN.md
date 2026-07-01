---
id: 2026-06-25-tmux-agent-bar-follow-ups-after-hook-runtime-fix
title: tmux-agent-bar follow-ups after hook/runtime fix
state: inbox
createdAt: 2026-06-25T15:46:58.869Z
updatedAt: 2026-06-25T15:46:58.869Z
sourcePlan: 2026-06-24-harden-tmux-agent-bar-state-model
---

# tmux-agent-bar follow-ups after hook/runtime fix

## Plan

## Why this exists

The personal-machine status bar issue is fixed, but the investigation surfaced a few architectural follow-ups worth considering so the local collector stays less brittle, more hook-first, and cheaper to run.

## Follow-ups to consider

- Re-check the Codex hook surface periodically and remove tail-based waiting inference if Codex adds a dedicated hook for in-turn questions or plan confirmation prompts.
- Consider an explicit alias/registration path for nonstandard Codex launch names so machine-specific binaries do not require broader built-in command matching over time.
- Revisit whether shell-wrapper process inference should remain enabled by default, or whether it should become opt-in / more tightly scoped.
- If shell-wrapper inference stays, keep reducing its scope so it only runs for sessions that actually need it.
- Add a focused performance regression test or benchmark around local snapshot/render latency on large process tables.
- Revisit whether any waiting-state detection can move closer to hook-triggered or current-session-triggered refresh boundaries without missing unsupported prompt states.

## Notes from this fix

- The current official Codex hooks still cover lifecycle and approval events, but not arbitrary in-turn question or plan-confirmation waiting states.
- The slow path on this machine was the shell-wrapper process scan, not pane-tail parsing.
- Direct pane command detection now handles `codex-*` variants before falling back to process inference.
