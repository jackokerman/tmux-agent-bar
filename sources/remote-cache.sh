#!/usr/bin/env bash

tmux_agent_bar_remote_cache_emit_records() {
  local _current="$1" rows_file="" session="" agent="" state="" source="" updated_at=""

  rows_file=$(tmux_agent_bar_remote_rows_file)
  [[ -f "${rows_file}" ]] || return 0

  while IFS=$'\t' read -r session agent state source updated_at || [[ -n "${session:-}${agent:-}${state:-}${source:-}${updated_at:-}" ]]; do
    [[ -n "${session}" ]] || continue
    [[ "${session}" == \#* ]] && continue
    [[ -n "${state}" ]] || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "${session}" "${agent}" "${state}" "${source}" "${updated_at}"
  done < "${rows_file}"
}

tmux_agent_register_source "remote-cache" "tmux_agent_bar_remote_cache_emit_records"
