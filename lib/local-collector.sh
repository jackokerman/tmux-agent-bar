#!/usr/bin/env bash

TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY=0
TMUX_AGENT_BAR_LOCAL_SESSIONS_SNAPSHOT=""
TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT=""
TMUX_AGENT_BAR_LOCAL_PS_SNAPSHOT=""
TMUX_AGENT_BAR_LOCAL_SHADOWED_SESSIONS_SNAPSHOT=""
TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT=""

tmux_agent_bar_process_snapshot() {
  local snapshot=""

  # `ucomm` keeps the executable basename instead of the full path, which is
  # enough for agent matching and avoids bloating the snapshot on macOS.
  snapshot=$(ps -eo pid=,ppid=,ucomm= 2>/dev/null || true)
  if [[ -n "${snapshot}" ]]; then
    printf '%s\n' "${snapshot}"
    return 0
  fi

  ps -eo pid=,ppid=,comm= 2>/dev/null || true
}

tmux_agent_bar_command_matches_known_command() {
  local pane_command="$1" known_command="$2"

  [[ -n "${pane_command}" ]] || return 1
  [[ -n "${known_command}" ]] || return 1

  [[ "${pane_command}" == "${known_command}" || "${pane_command}" == "${known_command}-"* ]]
}

tmux_agent_bar_known_command_for_pane_command() {
  local pane_command="$1" known_command=""

  for known_command in "${KNOWN_AGENT_COMMANDS[@]}"; do
    [[ -n "${known_command}" ]] || continue
    if tmux_agent_bar_command_matches_known_command "${pane_command}" "${known_command}"; then
      printf '%s\n' "${known_command}"
      return 0
    fi
  done

  return 1
}

tmux_agent_bar_shell_wrapped_pane_command() {
  local pane_command="$1"

  case "${pane_command}" in
    bash|dash|fish|ksh|sh|zsh) return 0 ;;
  esac

  return 1
}

tmux_agent_bar_process_wrapped_pane_command() {
  local pane_command="$1"

  tmux_agent_bar_shell_wrapped_pane_command "${pane_command}" && return 0

  case "${pane_command}" in
    bun|deno|node|npm|npx|pnpm|python|python3|ruby|yarn) return 0 ;;
  esac

  return 1
}

tmux_agent_bar_snapshot_has_session() {
  local snapshot="$1" session="$2" snapshot_session="" snapshot_command=""

  while IFS=$'\t' read -r snapshot_session snapshot_command || [[ -n "${snapshot_session:-}${snapshot_command:-}" ]]; do
    [[ -n "${snapshot_session}" ]] || continue
    [[ "${snapshot_session}" == "${session}" ]] && return 0
  done <<< "${snapshot}"

  return 1
}

tmux_agent_bar_snapshot_add_session_command() {
  local session="$1" command="$2"

  [[ -n "${session}" ]] || return 0
  [[ -n "${command}" ]] || return 0
  tmux_agent_bar_snapshot_has_session "${TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT}" "${session}" && return 0

  if [[ -n "${TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT}" ]]; then
    TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT+=$'\n'
  fi
  TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT+="${session}"$'\t'"${command}"
}

tmux_agent_bar_local_prepare_snapshots() {
  local target_agents="" known_command="" pane_session="" pane_pid="" pane_command="" matched_command=""
  local needs_process_scan=0 process_snapshot="" snapshot_session="" snapshot_command=""

  TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY=1
  TMUX_AGENT_BAR_LOCAL_SESSIONS_SNAPSHOT=$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
  TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT=$(tmux list-panes -a -F '#{session_name}'$'\t''#{pane_pid}'$'\t''#{pane_current_command}' 2>/dev/null || true)
  TMUX_AGENT_BAR_LOCAL_PS_SNAPSHOT=""
  TMUX_AGENT_BAR_LOCAL_SHADOWED_SESSIONS_SNAPSHOT=""
  TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT=""

  for known_command in "${KNOWN_AGENT_COMMANDS[@]}"; do
    [[ -n "${known_command}" ]] || continue
    if [[ -n "${target_agents}" ]]; then
      target_agents+=","
    fi
    target_agents+="${known_command}"
  done

  while IFS=$'\t' read -r pane_session pane_pid pane_command || [[ -n "${pane_session:-}${pane_pid:-}${pane_command:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    matched_command=$(tmux_agent_bar_known_command_for_pane_command "${pane_command}" 2>/dev/null || true)
    if [[ -n "${matched_command}" ]]; then
      tmux_agent_bar_snapshot_add_session_command "${pane_session}" "${matched_command}"
      continue
    fi

    if tmux_agent_bar_process_wrapped_pane_command "${pane_command}"; then
      needs_process_scan=1
    fi
  done <<< "${TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT}"

  if [[ "${needs_process_scan}" == "1" && -n "${target_agents}" && -n "${TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT}" ]]; then
    TMUX_AGENT_BAR_LOCAL_PS_SNAPSHOT=$(tmux_agent_bar_process_snapshot)
  fi

  if [[ -n "${TMUX_AGENT_BAR_LOCAL_PS_SNAPSHOT}" ]]; then
    process_snapshot=$(
      awk -v target_agents="${target_agents}" '
        BEGIN {
          agent_count = split(target_agents, agents, ",")
          for (i = 1; i <= agent_count; i++) {
            if (agents[i] != "") {
              wanted[agents[i]] = 1
            }
          }
        }

        FNR == NR {
          split($0, pane_fields, "\t")
          session = pane_fields[1]
          pid = pane_fields[2]
          comm = pane_fields[3]

          if (session == "" || pid !~ /^[0-9]+$/) {
            next
          }

          pane_session[pid] = session
          if (wanted[comm] && !seen_session[session]) {
            seen_session[session] = 1
            direct_command[session] = comm
          }
          next
        }

        {
          pid = $1
          ppid = $2
          comm = $3

          if (pid !~ /^[0-9]+$/) {
            next
          }

          parent[pid] = ppid
          if (wanted[comm]) {
            candidate_count += 1
            candidate_pid[candidate_count] = pid
            candidate_command[candidate_count] = comm
          }
        }

        END {
          for (session in direct_command) {
            print session "\t" direct_command[session]
          }

          for (i = 1; i <= candidate_count; i++) {
            current = candidate_pid[i]
            depth = 0

            while (current != "" && current != "1" && depth < 256) {
              depth += 1
              if (current in pane_session) {
                session = pane_session[current]
                if (!seen_session[session]) {
                  seen_session[session] = 1
                  print session "\t" candidate_command[i]
                }
                break
              }
              if (parent[current] == current) {
                break
              }
              current = parent[current]
            }
          }
        }
      ' <(printf '%s\n' "${TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT}") <(printf '%s\n' "${TMUX_AGENT_BAR_LOCAL_PS_SNAPSHOT}")
    )

    while IFS=$'\t' read -r snapshot_session snapshot_command || [[ -n "${snapshot_session:-}${snapshot_command:-}" ]]; do
      [[ -n "${snapshot_session}" ]] || continue
      tmux_agent_bar_snapshot_add_session_command "${snapshot_session}" "${snapshot_command}"
    done <<< "${process_snapshot}"
  fi

  local shadowed_sessions_file=""

  shadowed_sessions_file=$(tmux_agent_bar_shadowed_sessions_file)
  if [[ -f "${shadowed_sessions_file}" ]]; then
    TMUX_AGENT_BAR_LOCAL_SHADOWED_SESSIONS_SNAPSHOT=$(<"${shadowed_sessions_file}")
  fi
}

_session_pane_rows() {
  local session="$1" pane_session="" pane_pid="" pane_command=""

  if [[ "${TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY}" != "1" ]]; then
    tmux list-panes -t "${session}" -F '#{session_name}'$'\t''#{pane_pid}'$'\t''#{pane_current_command}' 2>/dev/null || true
    return 0
  fi

  while IFS=$'\t' read -r pane_session pane_pid pane_command || [[ -n "${pane_session:-}${pane_pid:-}${pane_command:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    [[ "${pane_session}" == "${session}" ]] || continue
    printf '%s\t%s\t%s\n' "${pane_session}" "${pane_pid}" "${pane_command}"
  done <<< "${TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT}"
}

_session_has_pane_command() {
  local session="$1" pane_session="" _pane_pid="" cmd="" wanted=""

  while IFS=$'\t' read -r pane_session _pane_pid cmd || [[ -n "${pane_session:-}${_pane_pid:-}${cmd:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    for wanted in "${@:2}"; do
      if tmux_agent_bar_command_matches_known_command "${cmd}" "${wanted}"; then
        return 0
      fi
    done
  done < <(_session_pane_rows "${session}")

  return 1
}

_session_has_known_agent_pane() {
  [[ -n "$(_session_agent_command "$1" 2>/dev/null || true)" ]]
}

_session_is_shadowed() {
  local session="$1" line="" shadowed_sessions=""

  if [[ "${TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY}" == "1" ]]; then
    shadowed_sessions="${TMUX_AGENT_BAR_LOCAL_SHADOWED_SESSIONS_SNAPSHOT}"
  else
    local shadowed_sessions_file=""

    shadowed_sessions_file=$(tmux_agent_bar_shadowed_sessions_file)
    if [[ -f "${shadowed_sessions_file}" ]]; then
      shadowed_sessions=$(<"${shadowed_sessions_file}")
    fi
  fi

  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    [[ -n "${line}" ]] || continue
    [[ "${line}" == \#* ]] && continue
    [[ "${line}" == "${session}" ]] && return 0
  done <<< "${shadowed_sessions}"

  return 1
}

_session_live_agent_command() {
  local session="$1" agent="${2:-}" pane_rows="" pane_pids="" ps_snapshot="" target_command=""
  local target_agents="" live_agent_command="" pane_session="" pane_pid="" pane_command="" known_command=""
  local snapshot_session="" snapshot_command=""

  if [[ "${TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY}" == "1" ]]; then
    target_command=$(tmux_agent_bar_command_for_agent "${agent}" 2>/dev/null || true)
    while IFS=$'\t' read -r snapshot_session snapshot_command || [[ -n "${snapshot_session:-}${snapshot_command:-}" ]]; do
      [[ -n "${snapshot_session}" ]] || continue
      [[ "${snapshot_session}" == "${session}" ]] || continue
      if [[ -n "${target_command}" && "${snapshot_command}" != "${target_command}" ]]; then
        return 1
      fi
      printf '%s\n' "${snapshot_command}"
      return 0
    done <<< "${TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT}"

    return 1
  fi

  pane_rows=$(_session_pane_rows "${session}")
  while IFS=$'\t' read -r pane_session pane_pid pane_command || [[ -n "${pane_session:-}${pane_pid:-}${pane_command:-}" ]]; do
    [[ "${pane_pid}" =~ ^[0-9]+$ ]] || continue
    if [[ -n "${pane_pids}" ]]; then
      pane_pids+=","
    fi
    pane_pids+="${pane_pid}"
  done <<< "${pane_rows}"
  [[ -n "${pane_pids}" ]] || return 1

  target_command=$(tmux_agent_bar_command_for_agent "${agent}" 2>/dev/null || true)
  if [[ -n "${target_command}" ]]; then
    target_agents="${target_command}"
  else
    for known_command in "${KNOWN_AGENT_COMMANDS[@]}"; do
      [[ -n "${known_command}" ]] || continue
      if [[ -n "${target_agents}" ]]; then
        target_agents+=","
      fi
      target_agents+="${known_command}"
    done
  fi
  [[ -n "${target_agents}" ]] || return 1

  if [[ "${TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY}" == "1" ]]; then
    ps_snapshot="${TMUX_AGENT_BAR_LOCAL_PS_SNAPSHOT}"
  else
    ps_snapshot=$(tmux_agent_bar_process_snapshot)
  fi
  # Avoid re-scanning and rewriting the entire ps snapshot just to prove it
  # is non-empty; on large local process tables that can dominate render time.
  [[ -n "${ps_snapshot}" ]] || return 1

  live_agent_command=$(
    awk -v pane_pids="${pane_pids}" -v target_agents="${target_agents}" '
    BEGIN {
      pane_count = split(pane_pids, panes, ",")
      for (i = 1; i <= pane_count; i++) {
        if (panes[i] != "") {
          pane[panes[i]] = 1
        }
      }

      agent_count = split(target_agents, agents, ",")
      for (i = 1; i <= agent_count; i++) {
        if (agents[i] != "") {
          wanted[agents[i]] = 1
        }
      }
    }

    {
      pid = $1
      ppid = $2
      comm = $3

      if (pid !~ /^[0-9]+$/) {
        next
      }

      parent[pid] = ppid
      if (wanted[comm]) {
        candidate_count += 1
        candidate_pid[candidate_count] = pid
        candidate_command[candidate_count] = comm
      }
    }

    END {
      for (i = 1; i <= candidate_count; i++) {
        current = candidate_pid[i]
        depth = 0

        while (current != "" && current != "1" && depth < 256) {
          depth += 1
          if (pane[current]) {
            print candidate_command[i]
            exit
          }
          if (parent[current] == current) {
            break
          }
          current = parent[current]
        }
      }
    }
  ' <<< "${ps_snapshot}"
  )
  [[ -n "${live_agent_command}" ]] || return 1

  printf '%s\n' "${live_agent_command}"
}

_session_has_live_agent_process() {
  [[ -n "$(_session_live_agent_command "$@" 2>/dev/null || true)" ]]
}

_session_agent_command() {
  local session="$1" pane_session="" _pane_pid="" cmd="" known_cmd=""

  while IFS=$'\t' read -r pane_session _pane_pid cmd || [[ -n "${pane_session:-}${_pane_pid:-}${cmd:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    known_cmd=$(tmux_agent_bar_known_command_for_pane_command "${cmd}" 2>/dev/null || true)
    if [[ -n "${known_cmd}" ]]; then
      printf '%s\n' "${known_cmd}"
      return 0
    fi
  done < <(_session_pane_rows "${session}")

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

  tmux_agent_state_is_stale_working "${state_file}"
}

_state_file_mtime() {
  local state_file="$1" updated_at=""

  updated_at=$(tmux_agent_state_file_mtime "${state_file}" 2>/dev/null || true)
  [[ "${updated_at}" =~ ^[0-9]+$ ]] || updated_at=0
  printf '%s\n' "${updated_at}"
}

tmux_session_status_emit_local_record() {
  local session="$1" current="$2" state="" active_agent="" agent="" live_state=""
  local has_known_agent_pane=0 stale_working=0 agent_mismatch=0 state_file="" updated_at=0 source=""

  [[ "${session}" != "${current}" ]] || return 0
  _session_is_shadowed "${session}" && return 0

  state_file=$(tmux_agent_bar_state_file_path "${session}")

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

  tmux_agent_bar_local_prepare_snapshots

  while IFS= read -r session; do
    [[ -n "${session}" ]] || continue
    tmux_session_status_emit_local_record "${session}" "${current}"
  done <<< "${TMUX_AGENT_BAR_LOCAL_SESSIONS_SNAPSHOT}"
}

tmux_agent_bar_local_emit_records() {
  tmux_session_status_local_emit_records "$1"
}
