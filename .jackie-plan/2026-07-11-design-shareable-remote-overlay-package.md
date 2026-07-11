---
id: 2026-07-11-design-shareable-remote-overlay-package
title: Design shareable remote overlay package
state: inbox
priority: low
createdAt: 2026-07-11T00:17:18.121Z
updatedAt: 2026-07-11T00:17:26.591Z
---

# Design shareable remote overlay package

## Plan

## Objective

Design a separate overlay package for people who want a turnkey remote/devbox-style `tmux-agent-bar` workflow without putting transport, launcher, or private setup assumptions into the public core runtime.

The overlay should install or configure external glue around the public entrypoints: agent hooks, source modules, optional picker integration, local attach wrappers, and remote cache population. The public repo remains launcher-agnostic and source-contract based.

## Preconditions

Do not start implementation until these public repo follow-ups are settled or intentionally deferred:

1. `2026-07-11-document-remote-adapter-contract`
2. `2026-07-11-clarify-external-launcher-status-guidance`

The picker preview plan, `2026-06-25-tmux-agent-bar-picker-preview-pane`, is useful but not a hard blocker. A basic overlay can use the existing picker; richer preview work can remain a separate enhancement.

## Scope

- Inventory the private scripts and docs that currently provide remote/devbox attach, source refresh, hook setup, picker entries, cache files, and troubleshooting.
- Decide the package shape: standalone repo, dotfiles overlay, plugin-like installer, or documented example bundle.
- Define the install contract:
  - clone or locate the base `tmux-agent-bar` checkout;
  - expose `bin/` entrypoints;
  - install agent hook snippets for supported agents;
  - install source modules under the user config directory;
  - optionally add session picker hooks or examples;
  - leave secrets, account-specific setup, and private auth outside the package.
- Decide what stays external even in the overlay: remote creation, private auth, company-specific command wrappers, and machine-local overrides.
- Define verification for a fresh machine and an existing machine migration.
- Plan the migration path out of private dotfiles once the overlay repo exists.

## Non-Goals

- Do not make `tmux-agent-bar` depend on the overlay.
- Do not require one agent, one remote platform, or one picker tool.
- Do not include private hostnames, private command names, company-specific paths, or private auth behavior in a public package.
- Do not preserve compatibility with old private fallback paths unless a current user-facing requirement needs them.
- Do not build broad installer automation before the smallest documented workflow works.

## Proposed Design Questions

- Should the overlay be public and generic, private and work-specific, or split into a generic template plus private adapter package?
- Does the overlay own a remote source module directly, or only an example source that users copy and adapt?
- How much should the installer mutate tmux config versus printing snippets for the user to add?
- Should hook setup be agent-specific scripts, documented snippets, or generated config fragments?
- What is the smallest smoke test that proves the overlay works without depending on a particular remote provider?

## Backlog Assessment

Recommended sequencing before creating the overlay repo:

1. Finish the remote adapter contract docs/tests in the public repo.
2. Finish launcher/source guidance in the public repo.
3. Decide whether the existing picker is good enough for the first shareable workflow. Recommended default: yes; do not block overlay design on preview panes.
4. Only then create the overlay repo or package and migrate private glue into it.

## Acceptance Criteria

- There is an explicit package/repo recommendation and a smallest viable install workflow.
- The design states what belongs in public core, generic overlay, and private local configuration.
- The design includes a migration checklist for moving private source modules and attach wrappers out of private dotfiles.
- No implementation starts until the user approves the package boundary.
