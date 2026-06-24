# tmux-agent-bar agent guidance

This is a public, generic repo. Keep the checked-in runtime, docs, examples, and tests installation-agnostic and environment-agnostic.

Do not add proprietary names, internal tool names, company-specific paths, or work-specific workflow details to checked-in files. References to local machines, remote machines, tmux sessions, or devboxes are fine when they stay generic.

Keep work-specific integration in private overlays, user modules, and external scripts that are not checked in. For this repo, that usually means `~/.config/tmux-agent-bar/agents/*.sh`, `~/.config/tmux-agent-bar/sources/*.sh`, or other private glue around the public entrypoints in `bin/`.

Keep the core runtime hook/status-file based and launcher-agnostic. Do not add sesh picker, one-shot launcher, devbox creation, remote transport, or other workflow-specific concepts to checked-in sources; model those as user modules or external scripts that write the same generic state records.

Prefer deleting coupling over adding compatibility branches. When a bug appears in source interaction, first confirm whether a source is replacing a local row, adding an independent row, or merely launching a process; only replacement sources should use shadowing.

Status rendering must stay bounded and predictable. Avoid polling loops, unbounded process scans, or refresh paths that can block hook completion; add focused regression tests for any performance-sensitive collector behavior.

If a bug only affects the active-session label or tmux refresh timing, inspect the tmux-side wrapper or `status-left`/`status-right` config that calls this repo before changing the shared runtime.

When you need placeholder names in docs, examples, or fixtures, use generic terms such as `remote`, `devbox`, `~/src/project`, `/workspace/project`, or `frontend/app`, not real internal project names or paths.

Prefer documenting extension points and contracts over documenting one specific personal setup. If an integration detail only applies to a private environment, leave it out of the public repo or describe it generically.

Run `./scripts/check` after changes. In this repo, the task is not done until the change is committed and pushed to `main` with a conventional commit.
