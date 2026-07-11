---
id: 2026-07-11-document-remote-adapter-contract
title: Document remote adapter contract
state: complete
priority: high
createdAt: 2026-07-11T00:16:50.894Z
updatedAt: 2026-07-11T00:28:34.324Z
---

# Document remote adapter contract

## Plan

## Objective

Make the public `tmux-agent-bar` contract explicit enough that remote or devbox-style adapters can be built, tested, and eventually packaged without coupling the core runtime to one private launcher, connector, host scheme, or setup flow.

This consolidates the reusable parts of older private follow-ups about remote tmux attaches, remote status mirroring, connector failure handling, and adapter-owned state resolution. The private source notes contain environment-specific command names and host details; those details should stay outside this public repo.

## Why This Comes Before An Overlay Repo

A shareable overlay should be thin glue around the public contract. If the contract stays implicit, the overlay will either duplicate private assumptions or push transport behavior back into the core. The first useful step is to document and test the boundary the overlay will depend on.

## Scope

- Document the adapter boundary in the public repo: normalized rows, optional shadowing, source refresh hooks, current-session filtering, cached rows, bounded probes, and failure behavior.
- Document how replacement sources differ from additive sources.
- Preserve the rule that remote transport, devbox discovery, connector selection, attach commands, and session creation live outside the core runtime.
- Capture the generic remote state resolver contract for adapter authors: explicit hook state, live agent presence, inferred tail state, stale active state, cache preservation, and hidden rows.
- Clarify that a native remote tmux helper can be a valid manual path without becoming the managed adapter contract when the adapter needs custom remote session selection or recovery behavior.
- Add focused core tests only where the public contract is affected, such as generic source precedence, shadowing, cached-row behavior, or stale/tail fallback fixtures.

## Non-Goals

- Do not add private connector commands, private host names, company-specific setup, or work-only launcher details to checked-in files.
- Do not implement a devbox source in this repo.
- Do not add direct SSH or PTY fallback branches to the core runtime.
- Do not add polling loops, daemons, or unbounded process scans.
- Do not require one specific session picker or config manager.

## Proposed Implementation Notes

1. Audit the current docs in `README.md`, `docs/sources.md`, `docs/agents.md`, and `docs/install.md` for the adapter contract that already exists.
2. Add a concise remote-adapter section, probably in `docs/sources.md`, with examples that use generic names such as `remote`, `devbox`, `/workspace/project`, and `agent-session`.
3. Add a small state table for adapter-owned remote rows. Keep it generic: inputs are explicit state, explicit mtime, live-agent presence, inferred tail state, and transport/cache outcome.
4. Add or update contract tests only for public behavior. If an implementation detail belongs to a private adapter, leave it to that adapter's own tests.
5. Run `./scripts/check`.

## Acceptance Criteria

- A fresh adapter author can tell which files/functions are stable public extension points and which behavior belongs in their own source module.
- The public repo explains replacement shadowing without implying all remote sources should shadow local rows.
- The docs describe bounded refresh/probe expectations without naming a private connector or transport.
- The core tests cover any public precedence behavior changed by the docs update.
- `./scripts/check` passes.

## Backlog Assessment

Recommended priority before a shareable overlay repo: do this first. It removes ambiguity that would otherwise leak into the overlay installer, devbox source, and troubleshooting docs.
