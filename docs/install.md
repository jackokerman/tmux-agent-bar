# Install

This repo is designed to be consumed as a managed runtime checkout.

- `dotfiles` clones or updates the repo into `~/.local/share/tmux-agent-bar/repo`
- tmux wrappers call the repo entrypoints from that stable path
- optional user modules load from `~/.config/tmux-agent-bar/`
