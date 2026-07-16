---
id: 2026-07-14-design-shareable-remote-adapter-package
title: Harden public adapter platform
state: paused
priority: high
createdAt: 2026-07-14T20:37:15.124Z
updatedAt: 2026-07-16T19:15:02.655Z
sourcePlan: 2026-07-14-evaluate-remote-activity-heuristics
---

# Harden public adapter platform

## Plan

## Objective

Prepare `tmux-agent-bar` to be a stable, open-source-ready base package that works on a personal machine with only local tmux sessions and also gives adapter authors and custom UI authors a clear contract to build on.

The base package should remain useful without any remote/devbox adapter: local hooks, local pane fallback, the compact status renderer, `explain`, and the picker should keep working with no proprietary tools, private paths, or environment-specific setup.

## Current assessment

Recent history shows real paper-cut churn, but the churn is not evenly distributed:

- The public core has been converging toward a coherent state model: hook-first local state, fallback local evidence, normalized source rows, deterministic ordering, and `explain` output.
- The remaining instability is mostly at boundaries: tmux cached status refresh behavior, remote adapter refresh timing, transport/probe cache policy, and implicit source contracts.
- The next work should harden those boundaries instead of adding more special cases to local collection or rendering.

This plan supersedes earlier public shareable-adapter planning as the canonical public/base plan. Environment-specific adapter packaging belongs in a separate private or downstream plan.

## Design principles

- Keep the base installable and useful without adapters.
- Keep proprietary transport, auth, host discovery, launcher setup, and remote repair policy out of this repo.
- Treat adapter output as data: normalized rows plus optional shadowing, not renderer-side transport behavior.
- Keep status rendering bounded. No remote probes, polling loops, unbounded process scans, or blocking recovery paths should run in the hot render path.
- Make UI consumers depend on a stable row/debug API, not on sourced Bash internals.
- Prefer one obvious extension path over parallel compatibility paths.

## Public platform scope

### 1. Stable row API

Add or formalize a public row-listing command for non-render consumers such as pickers, custom status bars, and external TUIs.

Recommended first shape:

- `rows [current-target]`: refreshes sources, emits prioritized rows.
- `rows-cached [current-target]`: skips source refresh hooks and emits prioritized rows.
- Output stays the existing five-column TSV unless implementation finds a concrete current consumer that needs more fields.
- The row order must come from the same helper used by the renderer and picker so custom UI code does not drift from status behavior.
- Document which fields are stable: `session_label`, `agent`, display-resolved `state`, `source`, and `updated_at`.
- Defer JSON until there is a real second consumer or a custom UI cannot reasonably consume TSV. If JSON is added, it must be a projection of the same row model, not a second ordering path.

### 2. Supported tmux status integration modes

Clarify and test the supported status installation modes.

The base should keep the direct `#()` install path because it is simple and portable. If the event-driven cached option path remains recommended for heavier adapter setups, either move a generic version into this repo or document the exact wrapper contract adapters should rely on.

The cached path needs focused coverage for:

- render timeout behavior;
- lock/coalescing behavior;
- stale cached option recovery;
- current-session targeting;
- cached render paths skipping source refresh hooks.

The recent stale status issue is a useful regression shape: a cached row existed and direct render worked, but the tmux option stayed stale because the coalesced wrapper timed out before writing the option.

### 3. Adapter author contract

Keep the public adapter contract centered on normalized rows and optional shadowing.

Add or refine docs/examples so an adapter author can answer these without reading private config:

- Should this adapter be additive or replacement/shadowing?
- Which process writes `remote-rows.tsv`?
- Does the adapter need a refresh hook, or can it update cache out of band?
- What should happen on probe failure?
- Which debug command should explain whether a row is missing because the adapter did not emit it, the core filtered it, or rendering truncated it?

Prefer a generic example adapter/cache writer over another prose-only description if that would make the contract easier to copy.

### 4. Debuggability and install confidence

Keep `explain` as the primary row-level debugger, and consider a small `doctor` or documented smoke-test sequence only if implementation shows repeated setup ambiguity.

The minimum smoke test for the base should prove:

- local hook state can write and render;
- `rows-cached` and `render-cached` agree about visible sessions;
- source rows from `remote-rows.tsv` render without any adapter installed;
- the current-session filter works through the documented tmux integration path.

### 5. Open-source readiness

Before treating this as a public package others can build on, audit the repo for:

- private names, private paths, and environment-specific docs;
- install docs that assume one user's dotfiles or wrapper layout;
- examples that imply one proprietary adapter is the default;
- tests that lock presentation details unrelated to public behavior.

## Non-goals

- Do not implement a proprietary remote/devbox adapter in the public repo.
- Do not add a daemon, supervisor, transport manager, host discovery flow, setup wizard, or auth repair path to the base.
- Do not make the renderer inspect remote transcripts, terminal streams, or adapter logs.
- Do not ship multiple row formats or configuration modes without a concrete consumer that needs them.
- Do not make the richer picker or future TUI depend on private adapter internals.

## Relationship to existing plans

- `2026-07-11-document-remote-adapter-contract` is complete and remains the public contract baseline.
- `2026-07-11-clarify-external-launcher-status-guidance` is complete and remains the launcher/source/shadowing guidance baseline.
- `2026-06-25-tmux-agent-bar-picker-preview-pane` should depend on the stable row API from this plan before adding richer preview/UI behavior.
- Environment-specific overlay or adapter packaging belongs in a downstream private plan, not in this public repo.
- Adjacent private dependency, auth, or tool-policy plans should not become the canonical public platform plan.

## Recommended implementation sequence

1. Add or formalize the public `rows` and `rows-cached` commands, migrate the picker to that command if needed, and document the TSV contract.
2. Decide whether the generic cached tmux status wrapper belongs in this repo. If it does, add the smallest wrapper and tests for timeout/coalescing/current-target behavior. If it does not, document the wrapper contract and leave implementation to integrations.
3. Add a generic adapter/cache-writer example only if the docs still leave adapter authors guessing how to produce rows.
4. Add the base smoke-test sequence and run it without any user/private source modules enabled.
5. Do the open-source readiness audit and remove or revise anything that assumes one user's environment.

## Acceptance criteria

- A personal machine can install and use the base package with local agent hooks and no remote adapter.
- A custom picker or status UI can consume a documented row command instead of sourcing internal shell helpers.
- An adapter author can produce rows and debug missing rows without adding transport logic to the renderer.
- The supported tmux status integration path has a bounded-refresh story and a regression test for stale cached options.
- Public docs and examples remain generic and open-source-safe.
- `./scripts/check` passes.

## Next honest step

Start with the row API and tmux cached-wrapper decision. Do not extract or package an environment-specific adapter until the base row/status contract is explicit enough that the adapter can depend on it without reaching into private wrapper behavior.

## Agent handoff

Paused while Fleet is evaluated as the primary off-the-shelf path. Do not implement the public row/status contract first unless the user explicitly overrides the Fleet-first sequence or Fleet is rejected/deferred. If Fleet fails, this plan remains the fallback public implementation contract.
