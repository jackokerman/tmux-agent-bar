#!/usr/bin/env bash

# Example naming-first remote source. A private overlay can keep a
# setup-specific version of this file and register it from
# ~/.config/tmux-agent-bar/sources/.

tmux_agent_register_source "remote" remote_emit remote_refresh
