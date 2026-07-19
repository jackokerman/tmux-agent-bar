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
  local snapshot="$1" session="$2" pane_id="$3" snapshot_session="" snapshot_pane_id="" snapshot_command=""

  while IFS=$'\t' read -r snapshot_session snapshot_pane_id snapshot_command || [[ -n "${snapshot_session:-}${snapshot_pane_id:-}${snapshot_command:-}" ]]; do
    [[ -n "${snapshot_session}" ]] || continue
    [[ "${snapshot_session}" == "${session}" ]] || continue
    [[ "${snapshot_pane_id}" == "${pane_id}" ]] && return 0
  done <<< "${snapshot}"

  return 1
}

tmux_agent_bar_snapshot_add_session_command() {
  local session="$1" pane_id="$2" command="$3"

  [[ -n "${session}" ]] || return 0
  [[ -n "${pane_id}" ]] || return 0
  [[ -n "${command}" ]] || return 0
  tmux_agent_bar_snapshot_has_session "${TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT}" "${session}" "${pane_id}" && return 0

  if [[ -n "${TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT}" ]]; then
    TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT+=$'\n'
  fi
  TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT+="${session}"$'\t'"${pane_id}"$'\t'"${command}"
}

tmux_agent_bar_local_prepare_snapshots() {
  local target_agents="" known_command="" pane_session="" pane_id="" pane_pid="" pane_command="" matched_command=""
  local needs_process_scan=0 process_snapshot="" snapshot_session="" snapshot_pane_id="" snapshot_command=""

  TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY=1
  TMUX_AGENT_BAR_LOCAL_SESSIONS_SNAPSHOT=$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
  TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT=$(tmux list-panes -a -F '#{session_name}'$'\t''#{pane_id}'$'\t''#{pane_pid}'$'\t''#{pane_current_command}' 2>/dev/null || true)
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

  while IFS=$'\t' read -r pane_session pane_id pane_pid pane_command || [[ -n "${pane_session:-}${pane_id:-}${pane_pid:-}${pane_command:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    matched_command=$(tmux_agent_bar_known_command_for_pane_command "${pane_command}" 2>/dev/null || true)
    if [[ -n "${matched_command}" ]]; then
      tmux_agent_bar_snapshot_add_session_command "${pane_session}" "${pane_id}" "${matched_command}"
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
        function matching_agent_command(command, i) {
          for (i in wanted) {
            if (command == i || index(command, i "-") == 1) {
              return i
            }
          }
          return ""
        }

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
          pane_id = pane_fields[2]
          pid = pane_fields[3]
          comm = pane_fields[4]

          if (session == "" || pane_id == "" || pid !~ /^[0-9]+$/) {
            next
          }

          pane_session[pid] = session
          pane_token[pid] = pane_id
          key = session SUBSEP pane_id
          matched_command = matching_agent_command(comm)
          if (matched_command != "" && !seen_pane[key]) {
            seen_pane[key] = 1
            direct_command[key] = matched_command
            direct_session[key] = session
            direct_pane[key] = pane_id
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
          matched_command = matching_agent_command(comm)
          if (matched_command != "") {
            candidate_count += 1
            candidate_pid[candidate_count] = pid
            candidate_command[candidate_count] = matched_command
          }
        }

        END {
          for (key in direct_command) {
            print direct_session[key] "\t" direct_pane[key] "\t" direct_command[key]
          }

          for (i = 1; i <= candidate_count; i++) {
            current = candidate_pid[i]
            depth = 0

            while (current != "" && current != "1" && depth < 256) {
              depth += 1
              if (current in pane_session) {
                session = pane_session[current]
                pane_id = pane_token[current]
                key = session SUBSEP pane_id
                if (!seen_pane[key]) {
                  seen_pane[key] = 1
                  print session "\t" pane_id "\t" candidate_command[i]
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

    while IFS=$'\t' read -r snapshot_session snapshot_pane_id snapshot_command || [[ -n "${snapshot_session:-}${snapshot_pane_id:-}${snapshot_command:-}" ]]; do
      [[ -n "${snapshot_session}" ]] || continue
      tmux_agent_bar_snapshot_add_session_command "${snapshot_session}" "${snapshot_pane_id}" "${snapshot_command}"
    done <<< "${process_snapshot}"
  fi

  local shadowed_sessions_file=""

  shadowed_sessions_file=$(tmux_agent_bar_shadowed_sessions_file)
  if [[ -f "${shadowed_sessions_file}" ]]; then
    TMUX_AGENT_BAR_LOCAL_SHADOWED_SESSIONS_SNAPSHOT=$(<"${shadowed_sessions_file}")
  fi
}

_session_pane_rows() {
  local session="$1" pane_filter="${2:-}" target="" pane_session="" pane_id="" pane_pid="" pane_command=""

  if [[ "${TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY}" != "1" ]]; then
    target="${pane_filter:-${session}}"
    tmux list-panes -t "${target}" -F '#{session_name}'$'\t''#{pane_id}'$'\t''#{pane_pid}'$'\t''#{pane_current_command}' 2>/dev/null || true
    return 0
  fi

  while IFS=$'\t' read -r pane_session pane_id pane_pid pane_command || [[ -n "${pane_session:-}${pane_id:-}${pane_pid:-}${pane_command:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    [[ "${pane_session}" == "${session}" ]] || continue
    [[ -z "${pane_filter}" || "${pane_id}" == "${pane_filter}" ]] || continue
    printf '%s\t%s\t%s\t%s\n' "${pane_session}" "${pane_id}" "${pane_pid}" "${pane_command}"
  done <<< "${TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT}"
}

_session_has_pane_command() {
  local session="$1" pane_filter="${2:-}" pane_session="" _pane_id="" _pane_pid="" cmd="" wanted=""

  while IFS=$'\t' read -r pane_session _pane_id _pane_pid cmd || [[ -n "${pane_session:-}${_pane_id:-}${_pane_pid:-}${cmd:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    for wanted in "${@:3}"; do
      if tmux_agent_bar_command_matches_known_command "${cmd}" "${wanted}"; then
        return 0
      fi
    done
  done < <(_session_pane_rows "${session}" "${pane_filter}")

  return 1
}

_session_has_known_agent_pane() {
  [[ -n "$(_session_agent_command "$1" "${2:-}" 2>/dev/null || true)" ]]
}

_session_has_wrapped_pane() {
  local session="$1" pane_filter="${2:-}" pane_session="" _pane_id="" _pane_pid="" cmd=""

  while IFS=$'\t' read -r pane_session _pane_id _pane_pid cmd || [[ -n "${pane_session:-}${_pane_id:-}${_pane_pid:-}${cmd:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    if tmux_agent_bar_process_wrapped_pane_command "${cmd}"; then
      return 0
    fi
  done < <(_session_pane_rows "${session}" "${pane_filter}")

  return 1
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
  local session="$1" agent="${2:-}" pane_filter="${3:-}" pane_rows="" pane_pids="" ps_snapshot="" target_command=""
  local target_agents="" live_agent_command="" pane_session="" pane_id="" pane_pid="" pane_command="" known_command=""
  local snapshot_session="" snapshot_pane_id="" snapshot_command=""

  if [[ "${TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY}" == "1" ]]; then
    target_command=$(tmux_agent_bar_command_for_agent "${agent}" 2>/dev/null || true)
    while IFS=$'\t' read -r snapshot_session snapshot_pane_id snapshot_command || [[ -n "${snapshot_session:-}${snapshot_pane_id:-}${snapshot_command:-}" ]]; do
      [[ -n "${snapshot_session}" ]] || continue
      [[ "${snapshot_session}" == "${session}" ]] || continue
      [[ -z "${pane_filter}" || "${snapshot_pane_id}" == "${pane_filter}" ]] || continue
      if [[ -n "${target_command}" && "${snapshot_command}" != "${target_command}" ]]; then
        continue
      fi
      printf '%s\n' "${snapshot_command}"
      return 0
    done <<< "${TMUX_AGENT_BAR_LOCAL_AGENT_COMMANDS_SNAPSHOT}"

    return 1
  fi

  pane_rows=$(_session_pane_rows "${session}" "${pane_filter}")
  while IFS=$'\t' read -r pane_session pane_id pane_pid pane_command || [[ -n "${pane_session:-}${pane_id:-}${pane_pid:-}${pane_command:-}" ]]; do
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
    function matching_agent_command(command, i) {
      for (i in wanted) {
        if (command == i || index(command, i "-") == 1) {
          return i
        }
      }
      return ""
    }

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
      matched_command = matching_agent_command(comm)
      if (matched_command != "") {
        candidate_count += 1
        candidate_pid[candidate_count] = pid
        candidate_command[candidate_count] = matched_command
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
  local session="$1" pane_filter="${2:-}" pane_session="" _pane_id="" _pane_pid="" cmd="" known_cmd=""

  while IFS=$'\t' read -r pane_session _pane_id _pane_pid cmd || [[ -n "${pane_session:-}${_pane_id:-}${_pane_pid:-}${cmd:-}" ]]; do
    [[ -n "${pane_session}" ]] || continue
    known_cmd=$(tmux_agent_bar_known_command_for_pane_command "${cmd}" 2>/dev/null || true)
    if [[ -n "${known_cmd}" ]]; then
      printf '%s\n' "${known_cmd}"
      return 0
    fi
  done < <(_session_pane_rows "${session}" "${pane_filter}")

  _session_live_agent_command "${session}" "" "${pane_filter}" 2>/dev/null || return 1
}

_session_live_state() {
  local session="$1" agent="${2:-}" pane_filter="${3:-}"

  if declare -F tmux_agent_session_live_state >/dev/null 2>&1; then
    tmux_agent_session_live_state "${session}" "${agent}" "${pane_filter}"
    return 0
  fi

  # Prefer no live inference over drifting away from the shared classifier.
  printf '%s\n' ""
}

_session_tail_inferred_agent_state() {
  local session="$1" pane_filter="${2:-}"

  _session_has_wrapped_pane "${session}" "${pane_filter}" || return 1

  if declare -F tmux_agent_session_inferred_agent_state >/dev/null 2>&1; then
    tmux_agent_session_inferred_agent_state "${session}" "${pane_filter}"
    return 0
  fi

  return 1
}

_session_tail_identified_agent() {
  local session="$1" pane_filter="${2:-}"

  _session_has_wrapped_pane "${session}" "${pane_filter}" || return 1

  if declare -F tmux_agent_session_identified_agent >/dev/null 2>&1; then
    tmux_agent_session_identified_agent "${session}" "${pane_filter}"
    return 0
  fi

  return 1
}

_session_tail_identifies_agent() {
  local session="$1" agent="$2" pane_filter="${3:-}" identified_agent=""

  [[ -n "${agent}" ]] || return 1

  identified_agent=$(_session_tail_identified_agent "${session}" "${pane_filter}" 2>/dev/null || true)
  [[ -n "${identified_agent}" ]] || return 1
  [[ "${identified_agent}" == "${agent}" ]]
}

_session_observed_agent_file() {
  local session="$1"

  printf '%s/%s\n' "$(tmux_agent_bar_observed_sessions_dir)" "$(tmux_agent_bar_safe_name "${session}")"
}

_session_mark_observed_agent() {
  local session="$1" agent="$2" observed_file=""

  [[ -n "${session}" ]] || return 0
  [[ -n "${agent}" ]] || return 0

  observed_file=$(_session_observed_agent_file "${session}")
  mkdir -p "$(dirname "${observed_file}")"
  printf '%s\n' "${agent}" > "${observed_file}"
}

_session_observed_agent() {
  local session="$1" observed_file="" agent=""

  observed_file=$(_session_observed_agent_file "${session}")
  [[ -f "${observed_file}" ]] || return 1

  IFS= read -r agent < "${observed_file}" || true
  [[ -n "${agent}" ]] || return 1
  printf '%s\n' "${agent}"
}

_session_clear_observed_agent() {
  local session="$1"

  rm -f "$(_session_observed_agent_file "${session}")"
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

tmux_agent_bar_reset_local_evidence() {
  TMUX_AGENT_BAR_LOCAL_SESSION=""
  TMUX_AGENT_BAR_LOCAL_HAS_EXPLICIT="false"
  TMUX_AGENT_BAR_LOCAL_EXPLICIT_AGENT=""
  TMUX_AGENT_BAR_LOCAL_EXPLICIT_STATE=""
  TMUX_AGENT_BAR_LOCAL_EXPLICIT_PANE=""
  TMUX_AGENT_BAR_LOCAL_EXPLICIT_MTIME=""
  TMUX_AGENT_BAR_LOCAL_EXPLICIT_AGENT_REGISTERED="false"
  TMUX_AGENT_BAR_LOCAL_HAS_LIVE_AGENT_PROCESS="false"
  TMUX_AGENT_BAR_LOCAL_HAS_KNOWN_AGENT_PANE="false"
  TMUX_AGENT_BAR_LOCAL_LIVE_AGENT=""
  TMUX_AGENT_BAR_LOCAL_LIVE_STATE=""
  TMUX_AGENT_BAR_LOCAL_TAIL_AGENT=""
  TMUX_AGENT_BAR_LOCAL_TAIL_STATE=""
  TMUX_AGENT_BAR_LOCAL_STALE_WORKING="false"
  TMUX_AGENT_BAR_LOCAL_OBSERVED_AGENT=""
  TMUX_AGENT_BAR_LOCAL_SHADOWED="false"
}

tmux_agent_bar_reset_local_resolution() {
  TMUX_AGENT_BAR_EXPLAIN_LOCAL_RECORD=""
  TMUX_AGENT_BAR_EXPLAIN_LOCAL_RESOLUTION="hidden"
  TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECTS="none"
  TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECT_AGENT=""
  TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="no_local_evidence"
}

tmux_agent_bar_collect_local_evidence() {
  local session="$1" agent="" state="" pane_id="" state_file=""

  tmux_agent_bar_reset_local_evidence
  TMUX_AGENT_BAR_LOCAL_SESSION="${session}"

  if _session_is_shadowed "${session}"; then
    TMUX_AGENT_BAR_LOCAL_SHADOWED="true"
    return 0
  fi

  state_file=$(tmux_agent_bar_state_file_path "${session}")

  if [[ -f "${state_file}" ]]; then
    IFS=$'\t' read -r agent state pane_id < <(_read_state_record "${state_file}")
    TMUX_AGENT_BAR_LOCAL_HAS_EXPLICIT="true"
    TMUX_AGENT_BAR_LOCAL_EXPLICIT_AGENT="${agent}"
    TMUX_AGENT_BAR_LOCAL_EXPLICIT_STATE="${state}"
    TMUX_AGENT_BAR_LOCAL_EXPLICIT_PANE="${pane_id}"
    TMUX_AGENT_BAR_LOCAL_EXPLICIT_MTIME=$(_state_file_mtime "${state_file}")

    if tmux_agent_bar_command_for_agent "${agent}" >/dev/null 2>&1; then
      TMUX_AGENT_BAR_LOCAL_EXPLICIT_AGENT_REGISTERED="true"
      if _session_has_live_agent_process "${session}" "${agent}" "${pane_id}"; then
        TMUX_AGENT_BAR_LOCAL_HAS_LIVE_AGENT_PROCESS="true"
      else
        return 0
      fi
    fi

    if _session_has_known_agent_pane "${session}" "${pane_id}"; then
      TMUX_AGENT_BAR_LOCAL_HAS_KNOWN_AGENT_PANE="true"
      TMUX_AGENT_BAR_LOCAL_LIVE_AGENT=$(_session_agent_command "${session}" "${pane_id}" 2>/dev/null || true)
      TMUX_AGENT_BAR_LOCAL_LIVE_STATE=$(_session_live_state "${session}" "${TMUX_AGENT_BAR_LOCAL_LIVE_AGENT:-${agent}}" "${pane_id}")
    else
      if _session_tail_identifies_agent "${session}" "${agent}" "${pane_id}"; then
        TMUX_AGENT_BAR_LOCAL_TAIL_AGENT="${agent}"
        TMUX_AGENT_BAR_LOCAL_LIVE_STATE=$(_session_live_state "${session}" "${agent}" "${pane_id}")
      else
        TMUX_AGENT_BAR_LOCAL_TAIL_AGENT=$(_session_tail_identified_agent "${session}" "${pane_id}" 2>/dev/null || true)
      fi
    fi

    if [[ "${state}" == "working" && -z "${TMUX_AGENT_BAR_LOCAL_LIVE_STATE}" ]] && \
       _state_file_has_stale_working "${state_file}"; then
      TMUX_AGENT_BAR_LOCAL_STALE_WORKING="true"
    fi

    return 0
  fi

  if _session_has_known_agent_pane "${session}"; then
    TMUX_AGENT_BAR_LOCAL_HAS_KNOWN_AGENT_PANE="true"
    TMUX_AGENT_BAR_LOCAL_LIVE_AGENT=$(_session_agent_command "${session}" 2>/dev/null || true)
    TMUX_AGENT_BAR_LOCAL_LIVE_STATE=$(_session_live_state "${session}" "${TMUX_AGENT_BAR_LOCAL_LIVE_AGENT}")
    return 0
  fi

  TMUX_AGENT_BAR_LOCAL_OBSERVED_AGENT=$(_session_observed_agent "${session}" 2>/dev/null || true)
  if IFS=$'\t' read -r agent state < <(_session_tail_inferred_agent_state "${session}"); then
    if [[ -n "${agent}" && -n "${state}" ]]; then
      TMUX_AGENT_BAR_LOCAL_TAIL_AGENT="${agent}"
      TMUX_AGENT_BAR_LOCAL_TAIL_STATE="${state}"
    fi
  else
    if [[ -n "${TMUX_AGENT_BAR_LOCAL_OBSERVED_AGENT}" ]] && \
       _session_tail_identifies_agent "${session}" "${TMUX_AGENT_BAR_LOCAL_OBSERVED_AGENT}"; then
      TMUX_AGENT_BAR_LOCAL_TAIL_AGENT="${TMUX_AGENT_BAR_LOCAL_OBSERVED_AGENT}"
    else
      TMUX_AGENT_BAR_LOCAL_TAIL_AGENT=$(_session_tail_identified_agent "${session}" 2>/dev/null || true)
    fi
  fi
}

tmux_agent_bar_resolve_local_evidence() {
  local session="" agent="" state="" active_agent="" has_known_agent_pane=0 stale_working=0 agent_mismatch=0

  tmux_agent_bar_reset_local_resolution

  session="${TMUX_AGENT_BAR_LOCAL_SESSION}"
  if [[ "${TMUX_AGENT_BAR_LOCAL_SHADOWED}" == "true" ]]; then
    TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="shadowed"
    return 0
  fi

  if [[ "${TMUX_AGENT_BAR_LOCAL_HAS_EXPLICIT}" == "true" ]]; then
    agent="${TMUX_AGENT_BAR_LOCAL_EXPLICIT_AGENT}"
    state="${TMUX_AGENT_BAR_LOCAL_EXPLICIT_STATE}"

    if [[ "${TMUX_AGENT_BAR_LOCAL_EXPLICIT_AGENT_REGISTERED}" == "true" && \
          "${TMUX_AGENT_BAR_LOCAL_HAS_LIVE_AGENT_PROCESS}" != "true" ]]; then
      TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECTS="delete_explicit_state"
      TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="explicit_agent_not_live"
      return 0
    fi

    if [[ "${TMUX_AGENT_BAR_LOCAL_HAS_KNOWN_AGENT_PANE}" == "true" ]]; then
      has_known_agent_pane=1
      active_agent="${TMUX_AGENT_BAR_LOCAL_LIVE_AGENT}"
      if [[ -n "${active_agent}" && "${active_agent}" != "${agent}" ]]; then
        agent_mismatch=1
      fi
    elif [[ -n "${TMUX_AGENT_BAR_LOCAL_TAIL_AGENT}" && "${TMUX_AGENT_BAR_LOCAL_TAIL_AGENT}" == "${agent}" ]]; then
      has_known_agent_pane=1
    fi

    if [[ "${TMUX_AGENT_BAR_LOCAL_STALE_WORKING}" == "true" ]]; then
      stale_working=1
    fi

    state=$(tmux_session_status_resolve_state "${state}" "${TMUX_AGENT_BAR_LOCAL_LIVE_STATE}" "${has_known_agent_pane}" "${stale_working}" "${agent_mismatch}")
    if [[ -z "${state}" ]]; then
      TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="explicit_resolved_hidden"
      return 0
    fi

    agent="${active_agent:-${agent}}"
    TMUX_AGENT_BAR_EXPLAIN_LOCAL_RECORD="${session}"$'\t'"${agent}"$'\t'"${state}"$'\tlocal_explicit\t'"${TMUX_AGENT_BAR_LOCAL_EXPLICIT_MTIME}"
    TMUX_AGENT_BAR_EXPLAIN_LOCAL_RESOLUTION="selected"
    TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="local_explicit"
    return 0
  fi

  if [[ "${TMUX_AGENT_BAR_LOCAL_HAS_KNOWN_AGENT_PANE}" == "true" ]]; then
    if [[ -z "${TMUX_AGENT_BAR_LOCAL_LIVE_STATE}" ]]; then
      TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="live_agent_neutral"
      return 0
    fi

    state=$(tmux_session_status_resolve_state "" "${TMUX_AGENT_BAR_LOCAL_LIVE_STATE}" 1 0 0)
    if [[ -z "${state}" ]]; then
      TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="live_agent_resolved_hidden"
      return 0
    fi

    TMUX_AGENT_BAR_EXPLAIN_LOCAL_RECORD="${session}"$'\t'"${TMUX_AGENT_BAR_LOCAL_LIVE_AGENT}"$'\t'"${state}"$'\tlocal_fallback\t0'
    TMUX_AGENT_BAR_EXPLAIN_LOCAL_RESOLUTION="selected"
    TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="live_fallback"
    return 0
  fi

  if [[ -n "${TMUX_AGENT_BAR_LOCAL_TAIL_AGENT}" && -n "${TMUX_AGENT_BAR_LOCAL_TAIL_STATE}" ]]; then
    state=$(tmux_agent_bar_display_state "${TMUX_AGENT_BAR_LOCAL_TAIL_STATE}")
    TMUX_AGENT_BAR_EXPLAIN_LOCAL_RECORD="${session}"$'\t'"${TMUX_AGENT_BAR_LOCAL_TAIL_AGENT}"$'\t'"${state}"$'\tlocal_fallback\t0'
    TMUX_AGENT_BAR_EXPLAIN_LOCAL_RESOLUTION="selected"
    TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECTS="write_observed_agent"
    TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECT_AGENT="${TMUX_AGENT_BAR_LOCAL_TAIL_AGENT}"
    TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="tail_fallback"
    return 0
  fi

  if [[ -n "${TMUX_AGENT_BAR_LOCAL_OBSERVED_AGENT}" && \
        -n "${TMUX_AGENT_BAR_LOCAL_TAIL_AGENT}" && \
        "${TMUX_AGENT_BAR_LOCAL_TAIL_AGENT}" == "${TMUX_AGENT_BAR_LOCAL_OBSERVED_AGENT}" ]]; then
    TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECTS="clear_observed_agent"
    TMUX_AGENT_BAR_EXPLAIN_SELECTED_REASON="observed_agent_neutral"
  fi
}

tmux_agent_bar_collect_local_explain() {
  tmux_agent_bar_collect_local_evidence "$1"
  tmux_agent_bar_resolve_local_evidence
}

tmux_agent_bar_apply_local_resolution_effects() {
  local session="$1"

  case "${TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECTS}" in
    delete_explicit_state)
      rm -f "$(tmux_agent_bar_state_file_path "${session}")"
      ;;
    write_observed_agent)
      _session_mark_observed_agent "${session}" "${TMUX_AGENT_BAR_EXPLAIN_SIDE_EFFECT_AGENT}"
      ;;
    clear_observed_agent)
      _session_clear_observed_agent "${session}"
      ;;
  esac
}

tmux_session_status_emit_local_record() {
  local session="$1" current="$2"

  [[ "${session}" != "${current}" ]] || return 0

  tmux_agent_bar_collect_local_evidence "${session}"
  tmux_agent_bar_resolve_local_evidence
  tmux_agent_bar_apply_local_resolution_effects "${session}"

  [[ -n "${TMUX_AGENT_BAR_EXPLAIN_LOCAL_RECORD}" ]] || return 0
  printf '%s\n' "${TMUX_AGENT_BAR_EXPLAIN_LOCAL_RECORD}"
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
