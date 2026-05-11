#!/usr/bin/env bash

# Example naming-first remote source. The real work overlay can keep a
# repository-local version of this file and register it from
# ~/.config/tmux-agent-bar/sources/.

tmux_agent_register_source "devvy" devvy_emit devvy_refresh
