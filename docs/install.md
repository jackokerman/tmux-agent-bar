# Install

This repo is install-agnostic. Clone it, vendor it, or manage it with whatever tool you want. The runtime only needs tmux to be able to execute the scripts in `bin/`.

For example, with `git`:

```bash
git clone https://github.com/jackokerman/tmux-agent-bar.git ~/src/tmux-agent-bar
```

Then point `tmux` at the renderer entrypoint from whatever checkout path you chose:

```tmux
set -g status-right "#(/path/to/tmux-agent-bar/bin/tmux-agent-bar '#{session_id}')"
```

If you want to call `tmux-agent-bar-hook` by name instead of by absolute path, expose the repo `bin/` directory however you prefer, such as adding it to your `PATH` or symlinking the scripts into `~/.local/bin`.

Optional user modules still load from `~/.config/tmux-agent-bar/`.
