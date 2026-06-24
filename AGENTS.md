# tmux-agent-bar agent guidance

This is a public, generic repo. Keep the checked-in runtime, docs, examples, and tests installation-agnostic and environment-agnostic.

Do not add proprietary names, internal tool names, company-specific paths, or work-specific workflow details to checked-in files. References to local machines, remote machines, tmux sessions, or devboxes are fine when they stay generic.

Keep work-specific integration in private overlays, user modules, and external scripts that are not checked in. For this repo, that usually means `~/.config/tmux-agent-bar/agents/*.sh`, `~/.config/tmux-agent-bar/sources/*.sh`, or other private glue around the public entrypoints in `bin/`.

If a bug only affects the active-session label or tmux refresh timing, inspect the tmux-side wrapper or `status-left`/`status-right` config that calls this repo before changing the shared runtime.

When you need placeholder names in docs, examples, or fixtures, use generic terms such as `remote`, `devbox`, `~/src/project`, `/workspace/project`, or `frontend/app`, not real internal project names or paths.

Prefer documenting extension points and contracts over documenting one specific personal setup. If an integration detail only applies to a private environment, leave it out of the public repo or describe it generically.

Run `./scripts/check` after changes. In this repo, the task is not done until the change is committed and pushed to `main` with a conventional commit.
