#!/usr/bin/env bash

tmux_agent_bar_display_state() {
  local state="$1"

  case "${state}" in
    waiting) printf '%s\n' "done" ;;
    *)       printf '%s\n' "${state}" ;;
  esac
}

tmux_session_status_resolve_state() {
  local explicit_state="$1" live_state="$2" has_known_agent_pane="${3:-0}" stale_working="${4:-0}" agent_mismatch="${5:-0}"
  local state="${explicit_state}"

  if [[ -n "${state}" ]]; then
    if [[ "${has_known_agent_pane}" == "1" ]]; then
      if [[ "${agent_mismatch}" == "1" ]]; then
        state="done"
      fi

      if [[ "${live_state}" == "waiting" ]]; then
        state="done"
      elif [[ "${state}" == "done" && "${live_state}" == "working" ]]; then
        state="working"
      elif [[ "${state}" == "working" && "${stale_working}" == "1" ]]; then
        state="done"
      fi
    elif [[ "${state}" == "working" && "${stale_working}" == "1" ]]; then
      state="done"
    fi

    tmux_agent_bar_display_state "${state}"
    return 0
  fi

  if [[ "${has_known_agent_pane}" != "1" ]]; then
    printf '%s\n' ""
    return 0
  fi

  tmux_agent_bar_display_state "${live_state}"
}

tmux_agent_bar_reconcile_remote_state() {
  local explicit_state="$1" live_state="$2" stale_working="${3:-0}"

  if [[ "${live_state}" == "waiting" ]]; then
    printf '%s\n' "done"
    return 0
  fi

  if [[ "${explicit_state}" == "working" && "${stale_working}" == "1" ]]; then
    printf '%s\n' "done"
    return 0
  fi

  tmux_agent_bar_display_state "${explicit_state}"
}

tmux_agent_bar_remote_state_is_stale_working() {
  local mtime="$1" ttl="${2:-${TMUX_AGENT_WORKING_TTL:-20}}" now=""

  [[ "${mtime}" =~ ^[0-9]+$ ]] || return 1

  now=$(date +%s)
  (( now - mtime > ttl ))
}
