---
id: 2026-06-25-tmux-agent-bar-follow-ups-after-hook-runtime-fix
title: Stabilize tmux-agent-bar state model
state: inbox
createdAt: 2026-06-25T15:46:58.869Z
updatedAt: 2026-07-08T22:52:11.194Z
sourcePlan: 2026-06-24-harden-tmux-agent-bar-state-model
---

# Stabilize tmux-agent-bar state model

## Plan

## Why this exists

`tmux-agent-bar` is currently useful and close to the right architecture, but recent fixes have clustered around the same brittle boundary: explicit hook state, live pane/process identity, tail-derived fallback state, observed wrapped sessions, remote cache rows, and render ordering. The goal is to lock the current good behavior into a small executable state contract before making more behavior changes, so future edge-case fixes do not create new regressions.

The stable direction is not a broad rewrite. Preserve the existing hook-first runtime, keep the renderer bounded, and make each stage observable before changing behavior.

## Goal

Make state resolution boring and testable:

1. Document and test the full local state precedence matrix.
2. Add a read-only diagnostic path for explaining a surprising session row.
3. Refactor the local collector so evidence gathering, pure state resolution, and side effects are separate.
4. Add repo guidance that forces future state bugs to update the contract instead of adding narrow one-off branches.

## Current baseline

The current runtime behavior should be treated as the baseline unless a failing contract test proves a specific bug.

Important facts:

- Explicit hook state is the durable source of truth for local sessions.
- Live process and pane-tail inspection are fallback evidence, not durable writers.
- Tail inference is still needed for prompt states that hooks do not expose, especially in-turn questions and plan confirmation prompts.
- Tail inference must stay identity-gated and boundary-aware. Prefer missing a fallback row over rendering stale transcript text as active work.
- Remote transport and cache population stay outside this public runtime. Source modules emit normalized rows; replacement sources may shadow local rows; additive sources must not shadow.
- The renderer should keep formatting, current-session filtering, deduplication, ordering, and truncation concerns separate from state interpretation.
- The repo check currently has a non-runtime public-history failure from reachable plan history. Settle that verification baseline before shipping runtime changes so `./scripts/check` is once again a reliable safety gate.

## Non-goals

- Do not add a daemon, polling loop, background watcher, or unbounded process scanner.
- Do not add remote transport, session launcher, picker workflow, or environment-specific concepts to checked-in runtime code.
- Do not build a full terminal UI parser.
- Do not broaden built-in command matching for one local launcher shape without a generic registration or alias story.
- Do not make renderer ordering or truncation responsible for state interpretation.
- Do not mix a broad refactor with behavior changes unless a focused failing contract test requires the behavior change.

## Implementation plan

### Phase 0: Restore the verification baseline

Before changing runtime behavior, make the normal safety gate meaningful again.

- Run `./scripts/check` and capture the current failure.
- Decide the narrow public-history fix separately from state-model work.
- If history cleanup is required, do it as its own explicit change and do not combine it with collector or resolver behavior.
- If the public-history policy is intentionally current-tree-only, adjust the guard deliberately and document why. Do not silently weaken it to pass the state-model rollout.
- End this phase with `./scripts/check` passing or with a clearly documented temporary verification command for the state-model work that excludes only the known non-runtime blocker.

Stopping point: do not proceed to runtime refactoring until the verification baseline is either green or the exception is explicit and narrow.

### Phase 1: Add an executable state contract

Add a table-driven contract test that covers local state resolution across the main evidence dimensions instead of only adding scenario tests after regressions.

Suggested file: `tests/test-state-contract.sh` or a clearly named new section in `tests/test-session-status-local.sh`.

Each case should describe:

- session label
- explicit agent/state/mtime, if any
- live direct or process-derived agent identity, if any
- tail-identified agent, if any
- tail-inferred state: `waiting`, `working`, or neutral
- whether explicit `working` is stale
- whether an observed wrapped-session marker exists
- whether the session is shadowed
- expected output row or hidden result
- expected side effect: none, delete explicit state file, or write observed marker
- a short reason label

Minimum contract cases:

- explicit `done`, no live same-agent process and no same-agent tail identity: hide and delete stale state file
- explicit `done`, same-agent tail identity but no live process: keep visible as `done`
- explicit `done`, visible same-agent `working`: render `working`
- explicit `working`, visible `waiting`: render `waiting`
- explicit `done`, visible `waiting`: render `waiting`
- explicit `working`, stale and neutral: render `done` without touching mtime
- explicit row, different live registered agent: render `done`
- no explicit row, direct live agent pane and neutral tail: emit `local_fallback` `done`
- no explicit row, direct live agent pane and waiting/working tail: emit `local_fallback` with that state
- no explicit row, shell-wrapped pane, identified active tail: emit `local_fallback` and write observed marker
- no explicit row, shell-wrapped pane, unidentified active-looking text: hide
- no explicit row, shell-wrapped pane, connector or retry screen above stale agent transcript: hide
- observed shell-wrapped session with same-agent neutral or completed tail: emit `local_fallback` `done`
- shadowed local session: hide before local resolution
- duplicate local and source-provided rows: preserve first-row precedence according to source order

This phase should not intentionally change behavior. If the contract exposes an inconsistency, write the failing case first, then decide whether to preserve current behavior or fix it in a separate commit.

### Phase 2: Add a read-only explain command

Add a small diagnostic entrypoint so future bugs can be debugged from evidence instead of guesswork.

Proposed CLI shape:

```text
bin/tmux-agent-bar explain <session>
bin/tmux-agent-bar explain-cached <session>
```

The command should be bounded and read-only by default. It should avoid full captured pane output unless a later explicit debug flag is added.

Recommended output shape: stable `key=value` lines, because that is readable and easy to test.

Fields to include when available:

- `session`
- `selected_record`
- `agent`
- `state`
- `source`
- `updated_at`
- `explicit_state`
- `explicit_agent`
- `explicit_mtime`
- `live_agent`
- `tail_agent`
- `tail_state`
- `stale_working`
- `observed_agent`
- `shadowed`
- `resolution`
- `side_effects` for what a normal render would do, but without actually doing it in explain mode

Verification cases:

- local explicit row
- local fallback row
- stale explicit `working`
- hidden no-agent row
- shadowed row
- source-provided row
- cached mode does not run refresh hooks

Stopping point: after this phase, a future bug report should be debuggable by asking for `explain-cached <session>` output plus the visible status segment.

### Phase 3: Refactor local collection around evidence and resolution

Only after the contract tests and explain command exist, refactor the local collector so state decisions are easier to reason about.

Preferred shape:

- `tmux_agent_bar_collect_local_evidence <session>` gathers explicit state, live identity, tail identity/state, stale-working, observed marker, and shadowing facts.
- `tmux_agent_bar_resolve_local_evidence` is a pure function that maps evidence to a normalized row, a hidden result, and a reason label.
- `tmux_agent_bar_apply_local_resolution_effects` handles bounded side effects such as deleting stale explicit `done` state or writing observed-session markers.
- `tmux_session_status_emit_local_record` becomes orchestration glue.

Keep the pure resolver free of tmux, `ps`, filesystem, or time reads. That makes the precedence matrix cheap to test and harder to accidentally bypass.

Do not change the remote source contract in this phase. Remote rows remain normalized five-column records, and shadowing remains an explicit replacement-source mechanism.

### Phase 4: Tighten fallback scope only where tests justify it

After the refactor, revisit the riskiest fallback paths with the contract tests in place.

Candidates:

- Make shell-wrapper inference run only when the pane command is a known wrapper and either process ancestry or tail identity provides same-agent evidence.
- Keep external terminal, connector, and retry screens as hard boundaries that prevent stale transcript inference.
- Consider an explicit public registration path for nonstandard agent command aliases instead of widening built-in command matching.
- Re-check current Codex hook docs before expanding or preserving tail-based waiting inference. If a dedicated waiting/input hook exists later, remove or narrow the tail heuristic instead of keeping both systems.
- Add a focused performance test around snapshot collection when any change affects `tmux list-panes`, `ps`, or per-session tail capture counts.

Each fallback change needs paired tests:

- one active shape that must render
- one stale, copied, connector, or wrapper shape that must stay hidden

### Phase 5: Update durable repo guidance

Add a short rule to `AGENTS.md` or the narrowest repo-facing guidance file:

When fixing a status-state bug, first identify the boundary being changed: explicit hook state, live process identity, tail fallback, observed wrapped-session memory, remote/additive source rows, replacement shadowing, or render-only ordering. If precedence changes, update the state-contract matrix and docs in the same change. Tail fallback changes require both a positive active fixture and a negative stale or connector fixture.

Keep this concise. The detailed procedure belongs in tests and docs, not always-loaded guidance.

### Phase 6: Verification and rollout discipline

Use staged commits so a regression can be bisected cleanly:

1. Verification baseline fix, if needed.
2. State contract tests with no intentional behavior change.
3. Explain command.
4. Collector evidence/resolver refactor with no intentional behavior change.
5. Any behavior change proven by a failing contract test.
6. Documentation and agent guidance updates.

Run focused checks after each runtime stage:

```bash
./tests/test-pane-state.sh
./tests/test-session-status-local.sh
./tests/test-session-status.sh
```

Run the full suite before each push:

```bash
./scripts/check
```

Before pushing, inspect:

```bash
git status --short --branch
git log --oneline origin/main..HEAD
```

## Acceptance criteria

- The current good behavior is preserved unless a focused failing contract test proves a bug.
- Local state precedence is represented as executable table-driven coverage, not only prose.
- A read-only explain command can show why a session resolved to its visible state without triggering slow refresh paths in cached mode.
- `lib/local-collector.sh` no longer interleaves evidence gathering, precedence decisions, and side effects in one branch-heavy function.
- Tail inference remains identity-gated, boundary-aware, and non-durable.
- Remote source behavior remains normalized-row based and launcher-agnostic.
- Future state bug fixes have a clear test and documentation update path.
- `./scripts/check` passes before commit and push, or any temporary exception is explicit, narrow, and not used to hide runtime test failures.

## Open decisions

- Whether to repair the current public-history check through history cleanup, current-tree-only policy adjustment, or another explicit repository policy decision.
- Whether the explain command should print only `key=value` text initially or also support a later machine-readable format. Default recommendation: start with `key=value` only.
- Whether shell-wrapper inference should remain enabled by default after the contract tests expose its full behavior. Default recommendation: keep it enabled for now, but narrow it only with paired positive and negative fixtures.

## Relationship to existing plans

This plan supersedes the earlier loose hook/runtime follow-up list. The narrower `2026-07-02-add-session-status-explain-command` plan remains valid as Phase 2 of this broader stabilization effort, unless implementation folds it directly into this plan.

## Agent handoff

No runtime implementation has started from this revised plan.

Next honest step:
- Review this stabilization plan and decide whether it is ready to implement as the controlling umbrella plan.
- Before runtime changes, resolve or explicitly isolate the current `./scripts/check` public-history failure so later green checks are meaningful.
- Keep the existing `2026-07-02-add-session-status-explain-command` plan as the Phase 2 diagnostic slice unless implementation folds it into this plan and updates that artifact accordingly.
