---
id: 2026-07-16-review-fleet-and-nick-nisi-s-workflow
title: Review Fleet and Nick Nisi's workflow
state: inbox
createdAt: 2026-07-16T15:56:20.568Z
updatedAt: 2026-07-16T15:56:20.568Z
sourcePlan: 2026-07-14-design-shareable-remote-adapter-package
---

# Review Fleet and Nick Nisi's workflow

## Plan

## Objective

Evaluate Fleet as a possible replacement for, companion to, or source of design ideas for `tmux-agent-bar`, then review Nick Nisi's current public tools, dotfiles, and workflow for adjacent patterns worth exploring.

This is a research plan. It should end with an evidence-backed recommendation and precise follow-up changes, not an implementation.

## Why this is separate

The source plan remains the implementation contract for hardening the public adapter platform. Fleet and the surrounding workflow are an independent build-versus-buy investigation that may change, narrow, or supersede parts of that work.

## Preliminary assessment

Fleet appears especially relevant because it preserves tmux as the session substrate while providing much of the desired agent-facing UI:

- a flat, urgency-sorted picker for tmux-backed agent sessions;
- hook-backed state for Claude Code, Codex, and pi, plus process and pane-based discovery for other agents;
- explicit states for permission, questions, work, unseen completion, acknowledged idle, shell, and stopped sessions;
- keyboard switching, filtering, live pane previews, prompt sending, permission actions, renaming, and guarded session termination;
- filesystem status records and JSONL events combined with bounded pane inspection;
- explicit acknowledgement that turns unseen completion into idle;
- diagnostic surfaces such as `doctor`, `reconcile`, and `explain`.

This overlap makes Fleet a potentially better workflow fit than a workspace-oriented orchestrator. It also makes its state model and source boundaries useful comparison material even if wholesale adoption is not practical.

The initial source review was pinned to Fleet commit `4883ce2fd95abd5d9d0bca103d0455dafb7f0417`. One implementation detail already merits scrutiny: its prompt-marker fallback can inspect the full captured buffer, so a stale prompt in scrollback may influence the current state.

## Research questions

1. Could Fleet replace `tmux-agent-bar` and the current picker without disrupting the existing tmux session, editor sidecar, and review-tool workflow?
2. Could Fleet instead consume or coexist with `tmux-agent-bar` state through a clean public boundary?
3. Which ideas should `tmux-agent-bar` borrow if Fleet is not adopted: state fusion, acknowledgement, diagnostics, row ordering, preview, passthrough, or action handling?
4. How do Fleet's state meanings and precedence compare with the current explicit hook state, process identity, tail fallback, observed wrapped-session memory, normalized source rows, replacement shadowing, and render ordering boundaries?
5. Are Fleet's process discovery and pane-scraping fallbacks bounded, predictable, and accurate enough for long-lived sessions?
6. Can generic remote adapter rows participate naturally, while proprietary connection and launch behavior remains private glue?
7. What installation, hook, status-line, runtime, and maintenance costs would adoption introduce?
8. Which current tools and patterns in Nick Nisi's public dotfiles and related repositories explain how Fleet is actually used, rather than merely how its README presents it?

## Evaluation sequence

1. Pin Fleet's current version, commit, license, and supported agent surfaces. Inspect its README, source, tests, changelog, and issue history using primary sources.
2. Map Fleet's architecture onto the existing `tmux-agent-bar` state boundaries and adapter contract.
3. If source inspection leaves important interaction questions unresolved, run an isolated smoke test without changing global tmux or agent configuration.
4. Inspect Nick Nisi's current public dotfiles and relevant tools for tmux, Fleet, session switching, agent hooks, worktrees, launchers, shell navigation, and editor integration. Use commit dates to distinguish current workflow from stale examples.
5. Compare three outcomes: adopt Fleet, integrate a Fleet-like UI with `tmux-agent-bar` state, or borrow selected patterns while retaining the existing architecture.

## Comparison focus

- canonical state records and stable session identity;
- evidence authority, freshness, precedence, and stale-state retirement;
- unseen completion versus acknowledged idle;
- permission and question states versus a single waiting state;
- a stable row snapshot API and shared ordering across status bars and pickers;
- explain, doctor, and reconciliation diagnostics;
- preview, passthrough, prompt sending, permission actions, and termination safety;
- hookless discovery accuracy and process-scan performance;
- separation between state collection, status-line rendering, and the interactive picker;
- integration with generic remote adapters without embedding transport or environment-specific behavior.

## Non-goals

- Do not copy or import Fleet code before making an adoption decision.
- Do not add private machine, connection, repository, or workflow details to this public plan.
- Do not install Fleet globally or mutate the active tmux configuration during research.
- Do not rewrite `tmux-agent-bar` based only on README-level similarities.
- Do not create a duplicate implementation plan until the research identifies a concrete, approved direction.
- Do not assume another person's dotfiles are current, complete, or a direct fit for this workflow.

## Stopping point

Produce:

- a concise feature and architecture comparison backed by source links and pinned revisions;
- a recommendation among wholesale adoption, a shared-state or UI integration, and selective borrowing;
- the strongest rejected alternative and the reason it lost;
- a short list of useful surrounding workflow ideas from Nick Nisi's public tools and dotfiles;
- precise amendments to existing Jackie Plans, or one new implementation plan if a distinct approved direction emerges.

## Verification

- Record the revisions used for all conclusions that may drift.
- Prefer repository source, tests, current configuration, and official documentation over inference.
- Run Fleet's focused tests only when needed to verify behavior not established by source inspection.
- Run `./scripts/check` after changing this repository's plan artifacts.
