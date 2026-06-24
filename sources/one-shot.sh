#!/usr/bin/env bash

tmux_agent_bar_one_shot_config_file() {
  printf '%s/one-shot.tsv\n' "$(tmux_agent_bar_config_dir)"
}

tmux_agent_bar_one_shot_rows() {
  local config_file="" line=""

  config_file=$(tmux_agent_bar_one_shot_config_file)
  [[ -f "${config_file}" ]] || return 0

  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    [[ -n "${line}" ]] || continue
    [[ "${line}" == \#* ]] && continue
    printf '%s\n' "${line}"
  done < "${config_file}"
}

tmux_agent_bar_one_shot_session_commands() {
  local target_session="$1" row="" session="" commands="" field="" output=""

  while IFS=$'\t' read -r session commands || [[ -n "${session:-}${commands:-}" ]]; do
    [[ "${session}" == "${target_session}" ]] || continue
    [[ -n "${commands}" ]] || continue

    output=""
    while IFS=$'\t' read -r field || [[ -n "${field:-}" ]]; do
      [[ -n "${field}" ]] || continue
      if [[ -n "${output}" ]]; then
        output+=","
      fi
      output+="${field}"
    done < <(printf '%s\n' "${commands}" | tr ',' '\t')

    [[ -n "${output}" ]] || return 1
    printf '%s\n' "${output}"
    return 0
  done < <(tmux_agent_bar_one_shot_rows)

  return 1
}

tmux_agent_bar_one_shot_session_is_tracked() {
  tmux_agent_bar_one_shot_session_commands "$1" >/dev/null 2>&1
}

tmux_agent_bar_one_shot_sessions() {
  local row="" session="" _commands=""

  while IFS=$'\t' read -r session _commands || [[ -n "${session:-}${_commands:-}" ]]; do
    [[ -n "${session}" ]] || continue
    printf '%s\n' "${session}"
  done < <(tmux_agent_bar_one_shot_rows)
}

tmux_agent_bar_one_shot_agent_command_csv() {
  local command="" output=""

  for command in "${KNOWN_AGENT_COMMANDS[@]}"; do
    [[ -n "${command}" ]] || continue
    if [[ -n "${output}" ]]; then
      output+=","
    fi
    output+="${command}"
  done

  printf '%s\n' "${output}"
}

tmux_agent_bar_one_shot_descendant_command() {
  local session="$1" target_commands="$2" pane_rows="" pane_pids="" process_rows=""
  local pane_session="" pane_pid="" _pane_command=""

  pane_rows=$(tmux list-panes -t "${session}" -F '#{session_name}'$'\t''#{pane_pid}'$'\t''#{pane_current_command}' 2>/dev/null || true)
  while IFS=$'\t' read -r pane_session pane_pid _pane_command || [[ -n "${pane_session:-}${pane_pid:-}${_pane_command:-}" ]]; do
    [[ "${pane_pid}" =~ ^[0-9]+$ ]] || continue
    if [[ -n "${pane_pids}" ]]; then
      pane_pids+=","
    fi
    pane_pids+="${pane_pid}"
  done <<< "${pane_rows}"
  [[ -n "${pane_pids//[[:space:]]/}" ]] || return 1

  [[ -n "${target_commands}" ]] || return 1

  process_rows=$(ps -eo pid=,ppid=,comm=,args= 2>/dev/null || true)
  [[ -n "${process_rows//[[:space:]]/}" ]] || return 1

  awk -v pane_pids="${pane_pids}" -v target_commands="${target_commands}" '
    BEGIN {
      pane_count = split(pane_pids, panes, ",")
      for (i = 1; i <= pane_count; i++) {
        if (panes[i] != "") {
          pane[panes[i]] = 1
        }
      }

      command_count = split(target_commands, commands, ",")
      for (i = 1; i <= command_count; i++) {
        if (commands[i] != "") {
          wanted[commands[i]] = 1
        }
      }
    }

    {
      pid = $1
      ppid = $2
      comm = $3
      args = $0
      sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]*/, "", args)

      if (pid !~ /^[0-9]+$/) {
        next
      }

      parent[pid] = ppid
      command_name = comm
      sub(/^.*\//, "", command_name)
      matched = wanted[command_name]
      matched_command = command_name

      arg_count = split(args, arg_parts, /[[:space:]]+/)
      for (i = 1; i <= arg_count && !matched; i++) {
        arg_name = arg_parts[i]
        sub(/^.*\//, "", arg_name)
        if (wanted[arg_name]) {
          matched = 1
          matched_command = arg_name
        }
      }

      if (matched) {
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
  ' <<< "${process_rows}"
}

tmux_agent_bar_one_shot_session_has_process() {
  local session="$1" target_commands=""

  target_commands=$(tmux_agent_bar_one_shot_session_commands "${session}" 2>/dev/null || true)
  [[ -n "$(tmux_agent_bar_one_shot_descendant_command "${session}" "${target_commands}" 2>/dev/null || true)" ]]
}

tmux_agent_bar_one_shot_live_agent_command() {
  local session="$1" agent_commands=""

  agent_commands=$(tmux_agent_bar_one_shot_agent_command_csv)
  [[ -n "${agent_commands}" ]] || return 1
  tmux_agent_bar_one_shot_descendant_command "${session}" "${agent_commands}" 2>/dev/null | sed -n '1p'
}

tmux_agent_bar_one_shot_session_state() {
  local session="$1" agent_command="" agent="" tail="" live_state=""

  agent_command=$(tmux_agent_bar_one_shot_live_agent_command "${session}")
  if [[ -z "${agent_command}" ]]; then
    printf '%s\n' "working"
    return 0
  fi

  agent=$(tmux_agent_bar_agent_for_command "${agent_command}" 2>/dev/null || true)
  [[ -n "${agent}" ]] || agent="${agent_command}"

  tail=$(tmux_agent_capture_tail "${session}")
  live_state=$(tmux_agent_infer_state_from_tail "${agent}" "${tail}")
  case "${live_state}" in
    waiting|working)
      printf '%s\n' "${live_state}"
      ;;
    *)
      printf '%s\n' "done"
      ;;
  esac
}

tmux_agent_bar_one_shot_emit() {
  local current="$1" session="" state="" state_file=""

  while IFS= read -r session; do
    [[ -n "${session}" ]] || continue
    [[ "${session}" != "${current}" ]] || continue
    tmux_agent_bar_one_shot_session_is_tracked "${session}" || continue
    state_file=$(tmux_agent_bar_state_file_path "${session}")
    [[ -f "${state_file}" ]] && continue
    _session_has_known_agent_pane "${session}" && continue
    if tmux_agent_bar_one_shot_session_has_process "${session}"; then
      state=$(tmux_agent_bar_one_shot_session_state "${session}")
      tmux_session_status_emit_record "${session}" "one-shot" "${state}" "one_shot" "0"
    fi
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
}

tmux_agent_register_source "one-shot" "tmux_agent_bar_one_shot_emit"
