#!/usr/bin/env bash

_session_has_pane_command() {
  local session="$1" cmd wanted

  while IFS= read -r cmd; do
    for wanted in "${@:2}"; do
      if [[ "${cmd}" == "${wanted}" ]]; then
        return 0
      fi
    done
  done < <(tmux list-panes -t "${session}" -F '#{pane_current_command}' 2>/dev/null)

  return 1
}

_session_has_known_agent_pane() {
  [[ -n "$(_session_agent_command "$1" 2>/dev/null || true)" ]]
}

_session_has_remote_transport_pane() {
  _session_has_pane_command "$1" "${REMOTE_TRANSPORT_COMMANDS[@]}"
}

_session_live_agent_command() {
  local session="$1" agent="${2:-}" pane_pids="" line="" pid="" comm="" current_pid="" parent_pid=""
  local target_command=""
  local -a target_agents=()

  pane_pids=$(tmux list-panes -t "${session}" -F '#{pane_pid}' 2>/dev/null || true)
  [[ -n "${pane_pids//[[:space:]]/}" ]] || return 1

  target_command=$(tmux_agent_bar_command_for_agent "${agent}" 2>/dev/null || true)
  if [[ -n "${target_command}" ]]; then
    target_agents=("${target_command}")
  else
    target_agents=("${KNOWN_AGENT_COMMANDS[@]}")
  fi

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    read -r pid _ppid comm <<< "${line}"
    [[ "${pid}" =~ ^[0-9]+$ ]] || continue

    case " ${target_agents[*]} " in
      *" ${comm} "*) ;;
      *) continue ;;
    esac

    current_pid="${pid}"
    while [[ -n "${current_pid}" && "${current_pid}" != "1" ]]; do
      if printf '%s\n' "${pane_pids}" | grep -qx "${current_pid}"; then
        printf '%s\n' "${comm}"
        return 0
      fi

      parent_pid=$(ps -o ppid= -p "${current_pid}" 2>/dev/null | tr -d '[:space:]')
      [[ "${parent_pid}" =~ ^[0-9]+$ ]] || break
      [[ "${parent_pid}" != "${current_pid}" ]] || break
      current_pid="${parent_pid}"
    done
  done < <(ps -eo pid=,ppid=,comm= 2>/dev/null || true)

  return 1
}

_session_has_live_agent_process() {
  [[ -n "$(_session_live_agent_command "$@" 2>/dev/null || true)" ]]
}

_session_agent_command() {
  local session="$1" cmd known_cmd

  while IFS= read -r cmd; do
    for known_cmd in "${KNOWN_AGENT_COMMANDS[@]}"; do
      if [[ "${cmd}" == "${known_cmd}" ]]; then
        printf '%s\n' "${known_cmd}"
        return 0
      fi
    done
  done < <(tmux list-panes -t "${session}" -F '#{pane_current_command}' 2>/dev/null)

  _session_live_agent_command "${session}" 2>/dev/null || return 1
}

_session_live_state() {
  local session="$1" agent="${2:-}"

  if declare -F tmux_agent_session_live_state >/dev/null 2>&1; then
    tmux_agent_session_live_state "${session}" "${agent}"
    return 0
  fi

  # Prefer no live inference over drifting away from the shared classifier.
  printf '%s\n' ""
}

_state_file_has_stale_working() {
  local state_file="$1"

  if declare -F tmux_agent_state_is_stale_working >/dev/null 2>&1; then
    tmux_agent_state_is_stale_working "${state_file}"
    return $?
  fi

  return 1
}

_state_file_mtime() {
  local state_file="$1" updated_at=""

  if declare -F tmux_agent_state_file_mtime >/dev/null 2>&1; then
    updated_at=$(tmux_agent_state_file_mtime "${state_file}" 2>/dev/null || true)
  fi

  if [[ ! "${updated_at}" =~ ^[0-9]+$ ]]; then
    updated_at=0
  fi

  printf '%s\n' "${updated_at}"
}

_touch_state_file() {
  local state_file="$1"

  [[ -f "${state_file}" ]] || return 1
  touch "${state_file}" 2>/dev/null
}

tmux_session_status_resolve_state() {
  local explicit_state="$1" live_state="$2" has_known_agent_pane="${3:-0}" stale_working="${4:-0}" agent_mismatch="${5:-0}"
  local state="${explicit_state}"

  if [[ -n "${state}" ]]; then
    if [[ "${has_known_agent_pane}" == "1" ]]; then
      if [[ "${agent_mismatch}" == "1" ]]; then
        state="done"
      fi

      # Explicit hook state remains authoritative for active sessions, except
      # when the pane clearly shows the agent is still running or blocked on a
      # prompt. This rescues stale explicit done files that can linger across
      # longer Codex turns.
      if [[ "${live_state}" == "waiting" ]]; then
        state="waiting"
      elif [[ "${state}" == "done" && "${live_state}" == "working" ]]; then
        state="working"
      elif [[ "${state}" == "working" && "${stale_working}" == "1" ]]; then
        state="done"
      fi
    elif [[ "${state}" == "working" && "${stale_working}" == "1" ]]; then
      state="done"
    fi

    printf '%s\n' "${state}"
    return 0
  fi

  if [[ "${has_known_agent_pane}" != "1" ]]; then
    printf '%s\n' ""
    return 0
  fi

  if [[ -n "${live_state}" ]]; then
    printf '%s\n' "${live_state}"
  else
    # Keep open agent sessions visible even when the live tail has no active
    # working/waiting marker. They should only disappear once the agent process
    # itself is gone.
    printf '%s\n' "done"
  fi
}

tmux_session_status_current_session() {
  local target="${1:-}"

  if [[ -n "${target}" ]]; then
    tmux display-message -p -t "${target}" '#{session_name}' 2>/dev/null || printf '%s\n' "${target}"
    return 0
  fi

  tmux display-message -p '#{session_name}' 2>/dev/null || true
}

tmux_session_status_emit_record() {
  local session_label="$1" agent="$2" state="$3" source="$4" updated_at="$5"

  [[ -n "${session_label}" ]] || return 0
  [[ -n "${state}" ]] || return 0

  printf '%s\t%s\t%s\t%s\t%s\n' "${session_label}" "${agent}" "${state}" "${source}" "${updated_at}"
}

tmux_session_status_emit_local_record() {
  local session="$1" current="$2" safe="" state="" active_agent="" agent="" live_state=""
  local has_known_agent_pane=0 stale_working=0 agent_mismatch=0 state_file="" updated_at=0 source=""

  [[ "${session}" != "${current}" ]] || return 0

  safe="${session//\//%2F}"
  state_file="${STATE_DIR}/${safe}"

  if [[ -f "${state_file}" ]]; then
    IFS=$'\t' read -r agent state < <(_read_state_record "${state_file}")

    if [[ "${state}" == "done" ]] && [[ " ${KNOWN_AGENT_COMMANDS[*]} " == *" ${agent} "* ]] && \
       ! _session_has_live_agent_process "${session}" "${agent}"; then
      rm -f "${state_file}"
      return 0
    fi

    if _session_has_known_agent_pane "${session}"; then
      has_known_agent_pane=1
      active_agent=$(_session_agent_command "${session}" 2>/dev/null || true)
      if [[ -n "${active_agent}" && "${active_agent}" != "${agent}" ]]; then
        agent_mismatch=1
      fi
      live_state=$(_session_live_state "${session}" "${active_agent:-${agent}}")
      if [[ "${state}" == "working" && "${live_state}" == "working" ]]; then
        _touch_state_file "${state_file}" || true
      fi
      if [[ "${state}" == "working" && -z "${live_state}" ]] && _state_file_has_stale_working "${state_file}"; then
        stale_working=1
      fi
    elif [[ "${state}" == "working" ]] && _state_file_has_stale_working "${state_file}"; then
      stale_working=1
    fi

    state=$(tmux_session_status_resolve_state "${state}" "${live_state}" "${has_known_agent_pane}" "${stale_working}" "${agent_mismatch}")
    [[ -n "${state}" ]] || return 0

    updated_at=$(_state_file_mtime "${state_file}")
    source="local_explicit"
    agent="${active_agent:-${agent}}"
  elif _session_has_remote_transport_pane "${session}"; then
    return 0
  elif ! _session_has_known_agent_pane "${session}"; then
    return 0
  else
    agent=$(_session_agent_command "${session}" 2>/dev/null || true)
    live_state=$(_session_live_state "${session}" "${agent}")
    state=$(tmux_session_status_resolve_state "" "${live_state}" 1 0 0)
    [[ -n "${state}" ]] || return 0

    updated_at=0
    source="local_fallback"
  fi

  tmux_session_status_emit_record "${session}" "${agent}" "${state}" "${source}" "${updated_at}"
}

tmux_session_status_local_emit_records() {
  local current="$1" session=""

  while IFS= read -r session; do
    [[ -n "${session}" ]] || continue
    tmux_session_status_emit_local_record "${session}" "${current}"
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
}

tmux_agent_bar_local_emit_records() {
  tmux_session_status_local_emit_records "$1"
}
