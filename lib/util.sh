#!/usr/bin/env bash

tmux_agent_bar_config_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/tmux-agent-bar"
}

tmux_agent_bar_agents_dir() {
  printf '%s/agents\n' "$(tmux_agent_bar_config_dir)"
}

tmux_agent_bar_sources_dir() {
  printf '%s/sources\n' "$(tmux_agent_bar_config_dir)"
}

tmux_agent_bar_load_dir() {
  local dir="$1" file=""

  [[ -d "${dir}" ]] || return 0

  for file in "${dir}"/*.sh; do
    [[ -r "${file}" ]] || continue
    # shellcheck source=/dev/null
    source "${file}"
  done
}
