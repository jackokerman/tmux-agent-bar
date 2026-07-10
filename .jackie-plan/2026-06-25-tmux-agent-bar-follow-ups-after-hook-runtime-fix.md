---
id: 2026-06-25-tmux-agent-bar-follow-ups-after-hook-runtime-fix
title: Stabilize tmux-agent-bar state model
state: ready-to-implement
createdAt: 2026-06-25T15:46:58.869Z
updatedAt: 2026-07-10T00:53:31.189Z
sourcePlan: 2026-06-24-harden-tmux-agent-bar-state-model
---

# Stabilize tmux-agent-bar state model

## Plan

## Why this exists

`tmux-agent-bar` is useful and close to the right architecture, but recent fixes have clustered around the same brittle boundary: explicit hook state, live pane/process identity, tail-derived fallback state, observed wrapped sessions, remote cache rows, and render ordering. The goal is to stop shipping one-off bug fixes that move one case forward and another case backward.

Recent commit history shows the churn pattern clearly: fixes have alternated around stale transcript boundaries, tail identity checks, wrapped-session visibility, explicit state cleanup on process exit, stale `done`/`working` expiry, post-tool hook behavior, runtime-wrapped process detection, snapshot performance, and source probe resilience. Those are all symptoms of the same missing contract. This plan should turn those repeated bug reports into a small state model that can be tested, explained, and refactored safely.

The stable direction is hook-first and bounded:

- Agent hooks write durable state for the current tmux session.
- The status bar renders that state plus normalized source rows.
- Local polling and transcript inference are fallback evidence, not a second source of truth.
- Remote or devbox transport stays outside the public runtime and feeds the same generic cache/source contract through adapters.

Green means the agent needs attention or has wrapped up; blue means active work is underway. When an agent surface does not expose enough hooks, fallback inference can bridge the gap, but it should be narrow, observable, and easy to remove when better hooks exist.

## Goal

Make state resolution boring and testable:

1. Encode the hook-first state model as an executable local precedence contract.
2. Add a read-only diagnostic path for explaining a surprising session row.
3. Refactor the local collector so evidence gathering, pure state resolution, and side effects are separate.
4. Tighten fallback behavior only after tests expose the active and stale shapes being protected.
5. Add repo guidance that forces future state bugs to update the contract instead of adding narrow one-off branches.
6. Preserve portability by keeping machine-specific, private, remote-transport, or launcher-specific details in external adapters that emit generic rows.
7. Make the adapter boundary testable: checked-in core code consumes generic files and rows only, while adapters own collection, transport, private host discovery, launcher behavior, and cache population.

## Current baseline

`./scripts/check` currently passes on `main`. A previous public-history guard failure was resolved separately by commit `b144acc` (`fix: ignore historical JP notes in public guard`), so this plan should treat the normal check suite as the verification baseline.

The current runtime behavior should be treated as the baseline unless a failing contract test proves a specific bug.

Important facts:

- Explicit hook state is the durable source of truth for local sessions.
- A hook write records state; it does not register a command alias. Command registration is only for local evidence, cleanup, and fallback inference.
- Live process and pane-tail inspection are fallback evidence, not durable writers.
- Tail inference is still needed for prompt states that hooks do not expose, especially in-turn questions and plan confirmation prompts.
- It is acceptable for `done` and `waiting` to share the same visual priority for now: both mean the user may want to check in.
- Tail inference must stay identity-gated and boundary-aware. Prefer missing a fallback row over rendering stale transcript text as active work.
- Remote transport and cache population stay outside this public runtime. Source modules emit normalized rows; replacement sources may shadow local rows; additive sources must not shadow.
- The public adapter contract is artifacts, not implementation details: hook files, normalized source rows, cache files, shadowing files, and tmux session labels.
- Remote, connector-backed, or private-environment source probes are inherently brittle even when timeout-bounded. A failing source should degrade to cached rows or no row without making tmux attach, client switching, or cached status rendering feel blocked.
- The renderer should keep formatting, current-session filtering, deduplication, ordering, and truncation concerns separate from state interpretation.

## Non-goals

- Do not add a daemon, polling loop, background watcher, or unbounded process scanner to the public core.
- Do not add remote transport, session launcher, picker workflow, devbox creation, or environment-specific concepts to checked-in runtime code.
- Do not couple the public runtime to any private connector, PTY, SSH wrapper, host naming, or work-machine setup. Those belong in user-owned adapters that write generic source/cache records.
- Do not let the core branch on adapter implementation details, probe private transport commands, infer host types, or special-case one machine's launcher flow.
- Do not build a full terminal UI parser.
- Do not broaden built-in command matching for one local launcher shape without a generic registration or alias story.
- Do not make renderer ordering or truncation responsible for state interpretation.
- Do not mix a broad refactor with behavior changes unless a focused failing contract test requires the behavior change.

## Audit findings

The planning audit found that the public runtime already has the right source-of-truth split, but the local collector does too much in one branch-heavy path.

### Comparative tool research

This planning pass compared public tmux agent tools, hook/status-file based tmux tooling, statusLine-cache plugins, notification-marker plugins, full control-plane tools, internal daemon/provider based tools, and a personal dotfiles overlay. The durable implementation takeaway is generic; do not copy private names, private transport details, or launcher-specific assumptions into this repository.

Findings:

- Pane-content/TUI tools detect status from captured pane content: prompt borders, interrupt text, spinner text, and confirmation markers. They have useful ideas for exact pane targeting, previewing, compact status labels, and paired positive/negative fixtures. They are not the right public-core architecture because terminal text is presentation, varies by agent/version/theme, and repeatedly creates stale-transcript failure modes.
- Hook/status-file tools are closest to this repo. Their hooks write pane or session state, readers aggregate per-pane or per-window state by priority, and cached status-line paths avoid expensive tmux calls when possible. Useful patterns: contract tests for "hook state wins," cache fast-path tests, per-pane rollup as a possible future contract, and explicit liveness cleanup that does not overwrite hook-owned state.
- Claude-specific hook plugins independently validate several failure modes this plan already calls out: late `PostToolUse` events can revive phantom `working`; `PermissionRequest` can be too broad for user-visible waiting; `Notification` can better represent actual attention prompts but still needs self-healing on `Stop`; hook writers must be fast and nonblocking.
- Claude `statusLine` cache plugins are good evidence for the cache-artifact model. They are useful for rich metadata and cheap active-pane reads, but they do not solve generic working/waiting/done state across agents and should not become this repo's core dependency.
- Notification-marker plugins show a useful marker-set/reconcile pattern: write small per-pane markers, recompute global display from the full marker set, and clear on multiple lifecycle edges so one stale marker does not deadlock the whole bar. This is a good diagnostic and cleanup idea, but not a complete state model by itself.
- Polling daemon plugins can provide live badges and notifications, but their source of truth is process scans and captured pane text. That makes them attractive for zero-hook setup and less attractive for this repo's stability goal. Their useful pieces are bounded snapshotting, single-instance locks, and display-state aging; their polling/content inference should remain fallback evidence here.
- Full orchestration/control-plane tools use SQLite, local HTTP servers, side panels, worker identities, heartbeats, or web dashboards. They are credible products when the goal is to manage agents, not merely render a tmux status segment. Their useful pattern is provider normalization: provider-specific lifecycle events translate into a small runtime-state vocabulary before UI consumes them.
- Internal daemon/provider tools favor explicit status enums, persisted session rows, evented status transitions, provider debug information, duplicate suppression by stable ownership keys, bounded remote query timeouts, and stale-heartbeat detection. Useful patterns: normalized provider outputs, explain/debug fields, freshness/staleness semantics, and ownership-based dedupe. The public core should adapt only these generic patterns.
- A personal dotfiles overlay did not contain a separate tmux status model. Its relevant pattern is separation: tmux shows lightweight visual indicators and notifications, while agent status flows through hooks and external bridge/adaptor code.

Build-vs-buy conclusion:

- Do not replace this repo with an off-the-shelf daemon, GUI, sidebar, or Claude-specific tmux plugin. Those tools solve adjacent problems, but adopting them would either narrow the repo to one agent surface, add a heavier always-on process, or make pane scraping the primary truth.
- Keep the public core hook/source-row based. This was not selected merely because the repo already works that way; it best matches the constraints: portable shell/tmux runtime, multi-agent support, cheap status rendering, private adapter compatibility, and a clear contract for future regression tests.
- Borrow generic patterns only: lifecycle event normalization, hook-owned state precedence, cache fast paths, bounded liveness cleanup, marker-set reconciliation, source freshness metadata, and explain/debug output.

Implementation consequence:

- Adopt a generic adapter boundary: adapters may know about private remotes, launchers, connector tools, daemons, or host naming, but checked-in core code only sees hook files, source rows, cache files, shadowing files, and tmux session labels.
- Treat adapter implementations as outside the core trust boundary. The core can validate rows and freshness, but it must not know how an adapter collected those rows.
- Adopt diagnostic and contract ideas, not a daemon/sidebar architecture.
- Prefer exact, table-driven fixtures over broad terminal scraping.
- If future multi-pane or multi-agent ambiguity becomes real, consider pane-level state as an explicit public contract rather than adding more process/tail heuristics.

### Historical failure patterns

Recent commits and prior planning notes show these recurring classes of failures:

- Stale transcript text being interpreted as current work after a turn had completed.
- Connector or retry screens sitting above old agent transcript and reviving stale status.
- Tail identity checks being too broad or too narrow for wrapped sessions.
- Explicit `done` rows either disappearing too aggressively or staying visible after the agent process exited.
- Explicit `working` rows staying blue after live evidence disappeared.
- Post-tool hook output refreshing `working` after the last tool call when no later stop edge arrived.
- Runtime-wrapped local panes requiring process ancestry detection, which then creates performance and stale-detection risk.
- Source refresh behavior needing to be resilient without letting remote/cache transport details leak into core runtime.

Implementation consequence: do not add another targeted branch for these. Encode them as contract rows first, make the explain command expose the evidence path, then refactor the collector around that contract.

### Hook state

Current behavior:

- `bin/tmux-agent-bar-hook` writes `agent<TAB>state` to a per-session file under `${STATE_DIR:-/tmp/tmux-agent-$(id -u)}`.
- `bin/tmux-agent-bar-codex-hook` maps supported Codex events to that generic hook: `PermissionRequest` to `waiting`, `UserPromptSubmit` and `PreToolUse` to `working`, and `SessionStart` and `Stop` to `done`.
- `PostToolUse` is intentionally ignored so a completed final tool call does not keep refreshing `working` if `Stop` is missed.
- Explicit `working` has a stale timeout fallback; live inference can reconcile it to `waiting` or `done` without refreshing the hook file mtime.

Gaps to address:

- The hook contract is documented, but the complete precedence matrix is spread across scenario tests and collector branches.
- Missing hook coverage for in-turn questions and plan confirmation prompts still justifies a small amount of tail inference.
- Current public Codex docs establish hooks as lifecycle handlers for events such as tool use, permission requests, and turn stop, but this planning pass did not find a dedicated documented waiting-for-input hook. Implementation should re-check the installed CLI/help and official docs before preserving or expanding fallback inference.

Implementation action:

- Add contract tests that make hook-owned, fallback-owned, and render-only state transitions explicit before changing collector behavior.

### Local evidence and fallback inference

Current behavior:

- The local source snapshots `tmux list-sessions`, `tmux list-panes`, and `ps` once per render when needed.
- Direct panes with registered agent commands are recognized without `ps`; shell/runtime-wrapped panes trigger bounded process ancestry scanning.
- Tail inference is used for active/waiting evidence when a direct command or explicit hook state is not enough.
- Connector/terminal boundaries and completed-turn boundaries stop stale transcript inference.
- Observed shell-wrapped session markers preserve only active fallback memory and are cleared when active evidence disappears.

Gaps to address:

- Evidence collection, precedence decisions, and side effects are interleaved in `tmux_session_status_emit_local_record`.
- The shell-wrapper path is useful for real wrapped sessions, but it is the riskiest stale-transcript path.
- The current tests cover many regressions, but they do not present the behavior as one complete table-driven contract.

Implementation actions:

- Add a table-driven local state contract before refactoring.
- Include paired positive and negative fixtures for every tail fallback shape that stays supported.
- Refactor into evidence collection, pure resolution, and side-effect application only after the contract and explain command exist.

### Source and remote/cache integration

Current behavior:

- Source modules emit normalized five-column rows: `session_label<TAB>agent<TAB>state<TAB>source<TAB>updated_at`.
- Fresh render/current-state paths run registered source refresh hooks before emitting rows; refresh failures are ignored by core.
- Cached render/current-state paths do not run refresh hooks.
- `remote-cache` reads `remote-rows.tsv`; replacement sources can list shadowed sessions in `shadowed-sessions.txt`; additive sources should not shadow local rows.
- Deduplication preserves first-row precedence according to source order, so replacement sources must explicitly shadow local rows if they represent the same session.

Gaps to address:

- Cached behavior is tested, but source refresh latency/failure expectations are mostly documentation rather than contract.
- Core cannot and should not know private transport details; devbox/remote probes need to stay in source modules or external scripts that write normalized rows.
- There is no explicit test that a source row can represent private/remote state without the core knowing how it was collected.
- There is no explicit negative contract that would fail if core logic started shelling out to adapter transport commands or keying behavior off private host/launcher names.

Implementation actions:

- Keep core tests focused on cached mode, source-order/deduplication behavior, source freshness metadata, and shadowing semantics.
- Document source refresh expectations: refresh hooks must be bounded, failures must degrade to cached rows or no rows, and cached commands must remain read-only with respect to refresh.
- Add an adapter-boundary fixture using a generic fake source that emits rows and shadowing data. The fixture should prove the core depends only on normalized rows and does not call transport-specific commands.
- Add a negative adapter-boundary assertion: the core test setup should make any unexpected transport/host/launcher probe fail, while the fake adapter succeeds by writing only generic source/cache/shadowing artifacts.
- Do not add transport-specific runtime branches.

### Command registration and aliases

Current behavior:

- Hooks write state for a session regardless of whether the agent command is registered.
- Command registration maps an agent name to a command for local pane/process recognition.
- Unknown explicit-only agents can still render from hook state.
- Registered command matching already accepts suffixed command names such as `codex-*`.

Gaps to address:

- Nonstandard aliases matter only when local inference or cleanup needs to recognize a pane/process as a known agent. They are not required for the basic hook-state path.
- The registry currently supports one command per agent. Adding multiple aliases would be a public API expansion and should only happen for a concrete supported workflow.

Implementation action:

- Do not add alias support in the first pass. Let the explain command reveal alias-related evidence gaps; add a public alias registration path only if implementation finds a real local inference case that hooks or user modules cannot cover cleanly.

### Diagnostics

Current behavior:

- There is no command that explains why a session rendered, why it was hidden, or which side effect normal rendering would apply.

Implementation action:

- Add `bin/tmux-agent-bar explain <session>` and `bin/tmux-agent-bar explain-cached <session>` as read-only diagnostic commands.
- The initial output should be stable `key=value` lines. This is enough for humans, easy to test, and avoids committing to a JSON schema before the evidence model settles.
- `explain-cached` must not run source refresh hooks or apply local side effects.
- Include adapter/source diagnostic fields such as selected source, shadowing reason, source freshness, refresh status when available, and cache age when available. Keep values generic and avoid transport-specific keys.

## Implementation plan

### Execution guardrails

This plan is intended to be implemented mostly autonomously in one focused implementation session. The implementation agent should not stop for user review after every small phase. Proceed through the phases in order, making conservative choices that preserve the existing public contract, and escalate only for one of these conditions:

- `./scripts/check` or the focused runtime tests fail before any runtime change and the failure is unrelated to this plan.
- A new contract test exposes behavior where preserving current behavior and fixing the likely bug are both plausible user-visible choices.
- A required fix would need private transport, host, launcher, or machine-specific logic in checked-in core code.
- A change would alter existing hook commands, state file locations, normalized source row format, cache semantics, or public CLI behavior outside the explicit `explain` additions.
- The implementation cannot leave the status bar, session picker/status consumers, and existing hook integration usable by the end of the session.

Use the canonical source checkout for the implementation handoff, not the old duplicate planning checkout. If the canonical checkout is also the live runtime path used by tmux wrappers, create a temporary git worktree or otherwise isolated implementation workspace for runtime edits. The live runtime checkout should only be advanced as an intentional cutover after checks pass.

Keep the cutover contained:

- Preserve the current hook commands, state directory layout, source-row format, cache files, shadowing files, and render/current-state commands while refactoring internals.
- Introduce the contract tests and `explain` command first, then refactor behind the existing CLI surface.
- Do not land a half-switched state model. If the implementation must stop between phases, leave the existing runtime behavior working and verified.
- Prefer additive internal helpers and tests during the refactor, then remove obsolete branches only after the focused tests prove the replacement path.
- Avoid long-lived feature flags, alternate runtime modes, or parallel public config. Temporary private helpers inside tests are fine; public users should see the same behavior until the final verified behavior change, if any.
- If a behavior change is required, isolate it in its own commit after the no-intentional-behavior-change contract/refactor commits.
- After the implementation branch is merged and the canonical checkout has been safely cut over, remove or archive the old duplicate checkout so future work and runtime wrappers converge on one source of truth.

### Phase 0: Confirm the verification baseline

Before changing runtime behavior, run the normal safety gate and keep it green:

```bash
./scripts/check
```

If it fails, fix or isolate that failure before proceeding with runtime changes. Do not combine verification-baseline repair with collector or resolver behavior changes.

Stopping point: do not proceed to runtime refactoring until `./scripts/check` is green, or until any temporary exception is explicit, narrow, and not hiding runtime failures.

### Phase 1: Add an executable state contract

Add a table-driven contract test that covers local state resolution across the main evidence dimensions instead of only adding scenario tests after regressions.

Suggested file: `tests/test-state-contract.sh` or a clearly named new section in `tests/test-session-status-local.sh`.

Each case should describe:

- session label
- explicit agent/state/mtime, if any
- direct pane command or process-derived agent identity, if any
- tail-identified agent, if any
- tail-inferred state: `waiting`, `working`, or neutral
- whether explicit `working` is stale
- whether an observed wrapped-session marker exists
- whether the session is shadowed
- expected output row or hidden result
- expected side effect: none, delete explicit state file, write observed marker, or clear observed marker
- a short reason label

Minimum contract cases:

- explicit `done`, no live same-agent process and no same-agent tail identity: hide and delete stale state file
- explicit `done`, same-agent tail identity but no live process: encode the current hide/delete behavior explicitly
- explicit `done`, visible same-agent `working`: render `working`
- explicit `working`, visible `waiting`: render `waiting`
- explicit `done`, visible `waiting`: render `waiting`
- explicit `working`, stale and neutral: render `done` without touching mtime
- explicit row, different live registered agent: render `done`
- no explicit row, direct live agent pane and neutral tail: hide unless there is active live inference
- no explicit row, direct live agent pane and waiting/working tail: emit `local_fallback` with that state
- no explicit row, shell-wrapped pane, identified active tail: emit `local_fallback` and write observed marker
- no explicit row, shell-wrapped pane, unidentified active-looking text: hide
- no explicit row, shell-wrapped pane, connector or retry screen above stale agent transcript: hide
- observed shell-wrapped session with same-agent neutral or completed tail: clear observed marker and hide
- shadowed local session: hide before local resolution
- duplicate local and source-provided rows: preserve first-row precedence according to source order
- cached current-state/render paths: do not run source refresh hooks
- generic fake adapter source: emits rows and optional shadowing data without core transport knowledge
- negative adapter-boundary case: fake adapter output works while any attempted core transport/host/launcher probe would fail the test

This phase should not intentionally change behavior. If the contract exposes an inconsistency, write the failing case first, then decide whether to preserve current behavior or fix it in a separate commit.

### Phase 2: Add a read-only explain command

This phase folds in the former `2026-07-02-add-session-status-explain-command` plan. Do not implement that plan separately.

Add a small diagnostic entrypoint so future bugs can be debugged from evidence instead of guesswork.

CLI shape:

```text
bin/tmux-agent-bar explain <session>
bin/tmux-agent-bar explain-cached <session>
```

The command should answer: "What evidence did the bar see for this session, what state did it resolve to, and what would normal rendering do next?"

The command should be bounded and read-only by default. It should avoid full captured pane output unless a later explicit debug flag is added.

Initial output shape: stable `key=value` lines only.

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
- `source_freshness`
- `source_refresh_status`
- `cache_age`
- `selected_reason`

Verification cases:

- local explicit row
- local fallback row
- stale explicit `working`
- hidden no-agent row
- shadowed row
- source-provided row
- cached mode does not run source refresh hooks
- explain mode does not delete explicit state or write/clear observed markers
- explain output for a generic source row stays transport-agnostic
- explain output uses generic source/cache/freshness labels only, with no adapter-private transport keys

Stopping point: after this phase, a future bug report should be debuggable by asking for `explain-cached <session>` output plus the visible status segment.

### Phase 3: Refactor local collection around evidence and resolution

Only after the contract tests and explain command exist, refactor the local collector so state decisions are easier to reason about.

Preferred shape:

- `tmux_agent_bar_collect_local_evidence <session>` gathers explicit state, live identity, tail identity/state, stale-working, observed marker, and shadowing facts.
- `tmux_agent_bar_resolve_local_evidence` is a pure function that maps evidence to a normalized row, a hidden result, a reason label, and proposed side effects.
- `tmux_agent_bar_apply_local_resolution_effects` handles bounded side effects such as deleting stale explicit state or writing/clearing observed-session markers.
- `tmux_session_status_emit_local_record` becomes orchestration glue.

Keep the pure resolver free of tmux, `ps`, filesystem, or time reads. That makes the precedence matrix cheap to test and harder to accidentally bypass.

Do not change the remote source contract in this phase. Remote rows remain normalized five-column records, and shadowing remains an explicit replacement-source mechanism.

### Phase 4: Tighten fallback scope only where tests justify it

After the refactor, revisit the riskiest fallback paths with the contract tests in place.

Candidates:

- Keep shell-wrapper inference enabled only for cases with same-agent evidence and paired stale-negative fixtures.
- Keep external terminal, connector, and retry screens as hard boundaries that prevent stale transcript inference.
- Treat source refresh latency as part of the source contract. Cached render paths must not run source refresh hooks, and fresh refresh paths should preserve stale-good rows or fail closed when a source cannot initialize quickly.
- Re-check current official hook docs and installed CLI behavior before expanding or preserving tail-based waiting inference. If a dedicated waiting/input hook exists later, remove or narrow the tail heuristic instead of keeping both systems.
- Add a focused performance test around snapshot collection when any change affects `tmux list-panes`, `ps`, per-session tail capture counts, or source-refresh timing.
- Re-check the adapter-boundary fixture before and after fallback tightening so transport-specific logic does not sneak into core.

Do not add nonstandard command alias support in this phase unless the contract tests or explain output demonstrate a concrete local inference gap that hooks and user modules cannot cover.

Each fallback change needs paired tests:

- one active shape that must render
- one stale, copied, connector, or wrapper shape that must stay hidden

### Phase 5: Update durable docs and repo guidance

Update user-facing docs where the implementation contract changes:

- `docs/agents.md` for local state precedence and fallback semantics.
- `docs/sources.md` for refresh/cached expectations, source freshness, adapter boundaries, and shadowing rules, if those become more explicit.
- `README.md` only if CLI entrypoints or setup behavior change.

Add or tighten a short rule in `AGENTS.md` or the narrowest repo-facing guidance file:

When fixing a status-state bug, first identify the boundary being changed: explicit hook state, live process identity, tail fallback, observed wrapped-session memory, normalized source rows, replacement shadowing, or render-only ordering. If precedence changes, update the state-contract matrix and docs in the same change. Tail fallback changes require both a positive active fixture and a negative stale or connector fixture. Machine-specific transport and launcher details belong in adapters outside the public core.

Keep this concise. The detailed procedure belongs in tests and docs, not always-loaded guidance.

### Phase 6: Verification and rollout discipline

Use staged commits so a regression can be bisected cleanly:

1. Verification baseline confirmation or repair, if needed.
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

Run the full public suite before each push:

```bash
./scripts/check
```

Before pushing, inspect:

```bash
git status --short --branch
git log --oneline origin/main..HEAD
```

Before advancing the live runtime checkout, run the available wrapper and private-adapter integration checks from the repositories that own those wrappers/adapters. At minimum, verify the canonical checkout path resolution, checkout sync behavior, shared renderer integration, and private source adapter behavior. If those checks are unavailable in the implementation environment, call that out explicitly before cutover.

Implementation is not complete until the branch is green, staged into reviewable commits, the default status rendering/current-state paths are usable with the same public commands and configuration as before, and the live runtime checkout has either been intentionally advanced or left untouched with a clear cutover note.

## Acceptance criteria

- The current good behavior is preserved unless a focused failing contract test proves a bug.
- The check baseline is green before runtime changes begin.
- The implementation proceeds mostly autonomously from the persisted plan; user escalation is limited to baseline failures, ambiguous user-visible behavior choices, adapter-boundary violations, public contract changes, or inability to leave the runtime usable.
- Existing hook commands, state directory layout, source-row format, cache files, shadowing files, render commands, and current-state commands remain compatible unless an explicit behavior-change commit and docs update justify a public contract change.
- Existing tmux status and session picker/status consumers remain usable throughout implementation. The refactor happens behind the current CLI/config surface, and no half-switched state model is left behind between phases.
- The hook-first model is explicit: durable state comes from hooks and normalized source rows; polling/tail inference is fallback evidence only.
- Local state precedence is represented as executable table-driven coverage, not only prose.
- A read-only explain command can show why a session resolved to its visible state or why it was hidden without triggering slow refresh paths in cached mode.
- `lib/local-collector.sh` no longer interleaves evidence gathering, precedence decisions, and side effects in one branch-heavy function.
- Tail inference remains identity-gated, boundary-aware, non-durable, and justified by missing hook coverage.
- Remote/source behavior remains normalized-row based and launcher-agnostic.
- Source refresh hooks are documented as bounded and failure-tolerant; cached commands never refresh sources.
- The public core remains portable outside any one work environment: machine-specific transport, private host discovery, launcher workflows, connector details, and transport command invocations live in external adapters that emit generic records.
- Adapter-boundary tests prove generic source/cache/shadowing artifacts are sufficient and that core behavior does not require private transport, host, or launcher knowledge.
- Future state bug fixes have a clear test and documentation update path.
- `./scripts/check` passes before commit and push, or any temporary exception is explicit, narrow, and not used to hide runtime test failures.

## Settled decisions

- The functionality audit is part of this planning session and is reflected in this plan.
- The audit should become actionable implementation detail in the plan, not a separate checked-in design note unless implementation discovers a need.
- Commit history is enough evidence for the known failure classes; there are no additional live failure cases known right now.
- `explain` starts with stable `key=value` output only.
- The old `2026-07-02-add-session-status-explain-command` plan is folded into this umbrella plan as Phase 2.
- Shell-wrapper inference stays enabled initially, but only contract-backed behavior should survive later tightening.
- Do not add command alias support in the first pass.
- Keep core source-refresh testing focused on cached behavior, source-order/deduplication, source freshness, fake-adapter rows, negative adapter-boundary assertions, and shadowing; document bounded failure semantics for source modules.
- Comparative research supports the existing hook/source-row direction. Adopt generic patterns such as explicit status contracts, explain/debug output, source freshness, bounded cache behavior, and ownership-based dedupe; do not adopt a daemon/sidebar architecture or broad pane-content parser for this repo.
- Core implementation must remain machine-agnostic and work-agnostic. Private remotes, connector flows, PTY details, SSH quirks, host naming, launcher behavior, and transport command invocation are adapter responsibilities outside checked-in public core code.
- Implementation should be autonomous and contained. Do not ask for routine per-phase review; do preserve the existing public command/config/state contracts and keep status rendering/session-picker consumers usable while internals are refactored.

## Remaining open questions

No known user-visible failure cases are missing from the audit right now. The remaining decision is lifecycle only: after reviewing the persisted contract, decide whether to mark this plan `ready-to-implement`.

## Relationship to existing plans

This plan supersedes the earlier loose hook/runtime follow-up list.

The former `2026-07-02-add-session-status-explain-command` plan is folded into this umbrella as Phase 2 and should not be implemented independently.

The earlier public-history guard follow-up `2026-07-09-fix-tmux-agent-bar-public-history-guard-failure` is complete and no longer blocks this work.

## Agent handoff

Implemented the next reviewable step for Phase 1 after confirming the Phase 0 baseline.

Completed:
- Confirmed fresh persisted state was `ready-to-implement` with `jp show 2026-06-25-tmux-agent-bar-follow-ups-after-hook-runtime-fix --json`.
- Confirmed the pre-change baseline was green with `./scripts/check`.
- Added `tests/test-state-contract.sh` as a table-driven local state contract covering explicit hook state, live local evidence, stale working expiry, agent mismatch, direct fallback, shell-wrapped tail fallback, observed wrapped-session cleanup, shadowing, duplicate source precedence, cached no-refresh behavior, and generic adapter/cache/shadowing artifacts.
- Wired the new contract test into `scripts/check`.
- While running the new adapter-boundary contract, exposed an existing blank-row quirk in `tmux_agent_bar_print_record_bucket` when earlier state buckets were empty; fixed it by skipping empty records before printing.

Verification:
- `./tests/test-state-contract.sh` passes.
- Focused runtime tests pass: `./tests/test-pane-state.sh`, `./tests/test-session-status-local.sh`, and `./tests/test-session-status.sh`.
- Full `./scripts/check` passes.

Next honest step:
- Start Phase 2 by adding the read-only `bin/tmux-agent-bar explain <session>` and `explain-cached <session>` diagnostic path, using the new contract cases as guardrails and preserving cached no-refresh/no-side-effect behavior.
