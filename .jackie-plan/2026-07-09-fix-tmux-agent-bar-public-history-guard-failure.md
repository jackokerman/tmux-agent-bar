---
id: 2026-07-09-fix-tmux-agent-bar-public-history-guard-failure
title: Fix tmux-agent-bar public-history guard failure
state: complete
createdAt: 2026-07-09T00:32:22.026Z
updatedAt: 2026-07-09T00:47:46.957Z
sourcePlan: 2026-07-08-audit-personal-tooling-test-drag
---

# Fix tmux-agent-bar public-history guard failure

## Plan

## Objective

Make `/Users/jackokerman/src/tmux-agent-bar`'s routine `./scripts/check` pass from the current repository state by resolving the pre-existing public-history guard failure.

## Context

During the `2026-07-08-audit-personal-tooling-test-drag` pruning pass, retained `tmux-agent-bar` tests passed, but the final `scripts/check-public-history` phase failed on reachable-history findings from older `.jackie-plan` commits that mention a private source helper name.

This was not introduced by the test deletions. It blocks a clean full check signal after unrelated work, so it should be handled separately from the test-pruning cleanup.

## Scope

- Reproduce the current `./scripts/check` failure.
- Inspect the guard's intended public-content boundary and its treatment of historical Jackie Plan artifacts.
- Choose the narrow fix that preserves the guard's value while making routine checks pass.
- Avoid rewriting history unless explicitly chosen as the right repair path after review.

## Verification

- `./scripts/check` passes in `/Users/jackokerman/src/tmux-agent-bar`.
