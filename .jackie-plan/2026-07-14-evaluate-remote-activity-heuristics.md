---
id: 2026-07-14-evaluate-remote-activity-heuristics
title: Stabilize remote adapter boundary
state: complete
createdAt: 2026-07-14T17:42:12.584Z
updatedAt: 2026-07-14T20:37:20.424Z
sourcePlan: 2026-07-11-document-remote-adapter-contract
---

# Stabilize remote adapter boundary

## Plan

## Objective

Make `tmux-agent-bar` more stable by enforcing one clear boundary for remote and launcher-owned activity state: adapters and hooks produce normalized state records, while the public core only reconciles local evidence, reads generic source/cache artifacts, orders rows, renders status, and explains decisions.

The implementation should settle the current ambiguity around remote activity helpers and close the loop on remote activity heuristics without adding a built-in remote adapter, daemon, PTY manager, transport wrapper, or renderer-side transcript parser.

## Current contract

The durable public contract is already mostly right:

- Local agent state is hook-first. `bin/tmux-agent-bar-hook` writes explicit `working`, `waiting`, or `done` state, and `waiting` resolves visually as `done`.
- Local pane/process/tail inspection is fallback evidence only. It should not refresh durable hook state from transcript text.
- Source modules emit normalized rows through the registered source contract.
- The built-in `remote-cache` source reads generic five-column rows from `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/remote-rows.tsv`.
- Replacement sources may suppress a matching local row by writing the session label to `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar/shadowed-sessions.txt`.
- Cached commands must not run source refresh hooks.
- `docs/sources.md` is the source of truth for adapter-owned remote classification guidance.

Comparative public-tool research supports this direction. Similar tmux agent status tools use lifecycle hooks and status files as the stable path, with process detection as fallback. Orchestration tools such as Conductor-style systems are useful inspiration for a future installable adapter or launcher package, but they should not pull orchestration, worktree management, transport, or sidebar/daemon behavior into this status-line-first core.

## Implementation scope

1. Audit the remote-adapter boundary in the current checkout.
   - Inspect `tmux_agent_bar_reconcile_remote_state` and `tmux_agent_bar_remote_state_is_stale_working` in `lib/reconcile.sh`.
   - Search the public repo and any immediately relevant local/private adapter or dotfiles integration that consumes this checkout to determine whether those functions are real API, unused leftovers, or private coupling.
   - Do not preserve helper functions merely because they exist; keep them only if there is a concrete adapter-facing use or a clearer public contract they should own.

2. Re-check the original comparable remote session manager as a bounded input to implementation.
   - Before changing code, do one targeted comparison against an existing private remote session manager's activity-state implementation and tests.
   - Extract only generic adapter-owned lessons such as submit grace, output-volume windows, startup and resize grace, disconnected/error collapse, one-way initialization, and aggregate status priority.
   - Do not copy private transport, host, launcher, UI, authentication, or workflow details into this public repo.

3. Resolve the helper ambiguity deliberately.
   - Preferred outcome if no real usage exists: remove the remote-specific helper functions and leave remote activity classification as adapter documentation plus normalized row tests.
   - Acceptable outcome if real usage exists: rename or document the smallest generic helper surface that adapter authors should call, add focused tests for it, and keep it transport-agnostic.
   - Do not add broad compatibility branches, environment knobs, or alternate config paths for hypothetical adapter users.

4. Strengthen the public contract only where it is under-specified.
   - Keep `docs/sources.md` focused on generic adapter responsibilities: explicit lifecycle events, bounded submit/output grace, startup/resize grace, stale-working TTLs, cache-preserving probe failure behavior, and normalized row emission.
   - Update docs only for public behavior that implementation changes or clarifies.
   - Keep examples generic, using names such as `remote`, `devbox`, `/workspace/project`, `frontend/app`, or `agent-session`.

5. Add or adjust focused tests for stable boundaries.
   - Keep `tests/test-state-contract.sh` as the state precedence contract when precedence changes.
   - Reuse or tighten the existing generic adapter-boundary fixture instead of creating a fake PTY or byte-stream simulator unless the implementation exposes a real untested public contract.
   - Cover any kept helper as public API, or remove helper-specific tests when the helper is removed.
   - Preserve coverage for normalized remote rows, replacement shadowing, cached render/current-state paths skipping source refresh, and core behavior not depending on remote transport probes.

6. Run `./scripts/check`.

## Non-goals

- Do not implement a built-in remote source beyond the existing generic `remote-cache` reader.
- Do not add a daemon, supervisor, web UI, polling loop, PTY manager, SSH wrapper, reconnect behavior, setup wizard, or one-shot launcher to the checked-in runtime.
- Do not make the renderer inspect byte streams, terminal transcripts, remote logs, or agent conversation content.
- Do not add private connector names, company-specific paths, host naming, authentication flows, or one user's launcher workflow to public docs, fixtures, examples, or tests.
- Do not create a separate installable remote/devbox adapter in this implementation. That is a plausible follow-up package, not part of this core stabilization pass.

## Stability principles

- Prefer explicit lifecycle events and normalized source rows over inference.
- Treat output/transcript/process heuristics as adapter-owned and bounded.
- Treat source refresh as opportunistic and failure-tolerant; stale useful cache is better than blocking tmux status rendering or deleting rows blindly.
- Keep replacement behavior explicit: only sources that own the same local session label should shadow local rows.
- Keep renderer behavior deterministic and bounded: no unbounded scans, no transport calls, no status refresh path that can block hook completion.
- Prefer deleting unused coupling over documenting accidental API.

## Escalation points

Pause for user input before making a change if implementation discovers any of these:

- A private or external adapter currently depends on `tmux_agent_bar_reconcile_remote_state` or `tmux_agent_bar_remote_state_is_stale_working` and removal would break the active setup.
- The cleanest fix requires changing the normalized source row format, cache file locations, hook command shape, state names, or shadowing semantics.
- Comparable-tool research reveals a small, generic contract that materially contradicts the current hook/source-row design.
- A proposed test would require baking private transport, host discovery, connector behavior, or launcher workflow into this public repo.

## Acceptance criteria

- The repo no longer has ambiguous remote reconciliation helper code: each helper is either removed or documented and tested as an intentional generic adapter-facing API.
- Remote activity classification remains adapter-owned; the core consumes normalized rows and generic cache/shadowing artifacts only.
- Existing local state precedence stays covered by `tests/test-state-contract.sh`; any precedence change updates docs and tests together.
- The public docs explain the adapter boundary without private integration details.
- `./scripts/check` passes.

## Follow-up direction

A separate adapter or plugin can later own user-specific remote/devbox setup, hook installation for Codex and Claude Code, remote session discovery, transport/reconnect policy, output-volume heuristics, and coworker onboarding. That adapter should write the same generic `remote-rows.tsv` and `shadowed-sessions.txt` artifacts rather than requiring new renderer behavior.

## Agent handoff

Implemented the remote adapter boundary stabilization through the review gate.

Code outcome:
- Removed the unused `tmux_agent_bar_reconcile_remote_state` helper from `lib/reconcile.sh` after confirming no public repo caller and no active private caller.
- Kept `tmux_agent_bar_remote_state_is_stale_working` as an intentional adapter-facing mtime helper because the active private adapter uses it for stale remote explicit `working` checks.
- Documented that helper in `docs/sources.md` as a narrow TTL comparison only; adapters still own transport state, transcript/tail inference, cache freshness, and row normalization.
- Added a focused regression in `tests/test-remote-cache.sh` for stale, fresh, invalid, and explicit TTL cases.

Bounded private comparison:
- The private resolver keeps remote activity classification adapter-owned: live-agent gating, waiting/working/done reconciliation, cache-preserving probe failure behavior, no preservation of cached `done`, and resolver-focused tests stay outside this public repo.

Verification:
- `./tests/test-remote-cache.sh` passed.
- `./tests/test-state-contract.sh` passed.
- `./scripts/check` passed.

Review gate:
- Stop before commit, push, lifecycle transition, or archive. Current changed scope is `.jackie-plan/2026-07-14-evaluate-remote-activity-heuristics.md`, `docs/sources.md`, `lib/reconcile.sh`, and `tests/test-remote-cache.sh`.
