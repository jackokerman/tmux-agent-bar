---
id: 2026-07-11-clarify-external-launcher-status-guidance
title: Clarify external launcher status guidance
state: complete
createdAt: 2026-07-11T00:17:01.864Z
updatedAt: 2026-07-11T00:28:34.364Z
---

# Clarify external launcher status guidance

## Plan

## Objective

Clarify how one-shot launchers, session pickers, and other external workflow glue should represent work in `tmux-agent-bar` without adding workflow-specific concepts to the checked-in runtime.

This consolidates the reusable part of older private notes about one-shot launcher status. Private setup docs may still need their own cleanup, but the public repo should own the generic extension guidance: when to use hooks, when to write a source module, and when a launcher should stay invisible to the bar.

## Scope

- Audit public docs for launcher guidance in `README.md`, `docs/install.md`, `docs/sources.md`, and examples.
- Decide whether the public repo needs a generic one-shot/source example or only clearer prose around hooks and source modules.
- Explain the recommended patterns:
  - use `tmux-agent-bar-hook` when the launcher runs an agent in the current tmux session;
  - use an additive source when the launcher represents independent work that does not replace a local tmux session row;
  - use a replacement source plus shadowing only when an adapter intentionally owns the same session label as a local row;
  - avoid parsing display labels from pickers when a stable identifier can cross the boundary instead.
- Keep command examples generic and environment-agnostic.
- Leave private picker labels, private config fragments, and private launcher names outside this repo.

## Non-Goals

- Do not add a built-in private one-shot source.
- Do not document one user's session picker or config manager as the public default.
- Do not add icons, presentation strings, or private labels as tested contracts.
- Do not change the status renderer unless the docs audit finds a real public behavior gap.

## Proposed Implementation Notes

1. Review existing public docs and examples for anything that implies external launchers need first-class runtime support.
2. Add a compact section describing launcher integration patterns and the source/shadowing decision.
3. If examples are useful, keep them as minimal shell snippets under `examples/` with placeholder session labels.
4. Run `./scripts/check`.

## Acceptance Criteria

- Public docs explain how an external launcher can participate without becoming part of the core runtime.
- The guidance distinguishes hook state, additive source rows, and replacement source rows.
- No private tool names, private paths, private labels, or work-only workflow details are introduced.
- `./scripts/check` passes.

## Backlog Assessment

Recommended priority before a shareable overlay repo: do this second, after the remote adapter contract. The overlay installer and docs will need to point at these public extension patterns instead of carrying a parallel explanation.
