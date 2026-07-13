#!/usr/bin/env bash

tmux_agent_bar_state_dir() {
  printf '%s\n' "${STATE_DIR:-/tmp/tmux-agent-$(id -u)}"
}

tmux_agent_bar_state_file_path() {
  local session="$1"

  printf '%s/%s\n' "$(tmux_agent_bar_state_dir)" "$(tmux_agent_bar_safe_name "${session}")"
}

tmux_agent_bar_cache_dir() {
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-bar"
}

tmux_agent_bar_remote_rows_file() {
  printf '%s/remote-rows.tsv\n' "$(tmux_agent_bar_cache_dir)"
}

tmux_agent_bar_shadowed_sessions_file() {
  printf '%s/shadowed-sessions.txt\n' "$(tmux_agent_bar_cache_dir)"
}

tmux_agent_bar_observed_sessions_dir() {
  printf '%s/observed-sessions\n' "$(tmux_agent_bar_cache_dir)"
}

tmux_agent_bar_safe_name() {
  local name="$1"

  printf '%s\n' "${name//\//%2F}"
}

tmux_agent_bar_decode_session_name() {
  local safe_name="$1"

  printf '%s\n' "${safe_name//%2F/\/}"
}

tmux_agent_bar_read_state_record() {
  local state_file="$1" raw="" agent="" state="" pane_id="" _extra=""

  raw=$(<"${state_file}")
  IFS=$'\t' read -r agent state pane_id _extra <<< "${raw}"

  if [[ -z "${state}" ]]; then
    state="${agent}"
    agent="claude"
    pane_id=""
  fi

  printf '%s\t%s\t%s\n' "${agent}" "${state}" "${pane_id}"
}

tmux_agent_state_file_mtime() {
  local state_file="$1"

  if stat -f '%m' "${state_file}" >/dev/null 2>&1; then
    stat -f '%m' "${state_file}"
    return 0
  fi

  stat -c '%Y' "${state_file}"
}

tmux_agent_state_is_stale_working() {
  local state_file="$1" ttl="${2:-${TMUX_AGENT_WORKING_TTL:-20}}" mtime="" now=""

  [[ -f "${state_file}" ]] || return 1

  mtime=$(tmux_agent_state_file_mtime "${state_file}" 2>/dev/null || true)
  [[ "${mtime}" =~ ^[0-9]+$ ]] || return 1

  now=$(date +%s)
  (( now - mtime > ttl ))
}

_decode_session_name() {
  tmux_agent_bar_decode_session_name "$1"
}

_read_state_record() {
  tmux_agent_bar_read_state_record "$1"
}
