#!/usr/bin/env bash

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

tmux_session_status_format_session() {
  local name="$1" state="$2"

  case "${state}" in
    waiting) printf '%s' "#[fg=#e3d18a] ${name}#[fg=default]" ;;
    working) printf '%s' "#[fg=#82aaff] ${name}#[fg=default]" ;;
    *)       printf '%s' "#[fg=#21c7a8] ${name}#[fg=default]" ;;
  esac
}

tmux_session_status_strip_styles() {
  local output="" prefix="" rest="$1"

  while [[ "${rest}" == *"#["* ]]; do
    prefix="${rest%%\#\[*}"
    output+="${prefix}"
    rest="${rest#*\#\[}"
    rest="${rest#*]}"
  done

  output+="${rest}"
  printf '%s\n' "${output}"
}

tmux_session_status_visible_width() {
  local plain=""

  plain=$(tmux_session_status_strip_styles "$1")
  printf '%s\n' "${#plain}"
}

tmux_session_status_tmux_format_width() {
  local format="$1" width=""

  width=$(tmux display-message -p "${format}" 2>/dev/null || true)
  [[ "${width}" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "${width}"
}

tmux_session_status_tmux_option_number() {
  local option="$1" value=""

  value=$(tmux show-options -gv "${option}" 2>/dev/null || true)
  [[ "${value}" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "${value}"
}

tmux_session_status_right_available_width() {
  local client_width="" left_limit="" current_window_width="" right_limit="" available=""

  [[ "${TMUX_AGENT_BAR_PROBE_TMUX_WIDTH:-0}" == "1" ]] || return 1

  client_width=$(tmux_session_status_tmux_format_width '#{client_width}') || return 1
  left_limit=$(tmux_session_status_tmux_option_number 'status-left-length') || return 1
  current_window_width=$(tmux_session_status_tmux_format_width '#{w:#{E:window-status-current-format}}') || return 1
  right_limit=$(tmux_session_status_tmux_option_number 'status-right-length') || return 1

  # Do not evaluate status-left here. It can contain #() commands that call back
  # into tmux-agent-bar, which recursively wedges tmux status rendering.
  available=$(( client_width - left_limit - current_window_width ))
  if (( available > right_limit )); then
    available="${right_limit}"
  fi

  (( available > 0 )) || return 1
  printf '%s\n' "${available}"
}

tmux_session_status_truncation_indicator() {
  printf '%s\n' "#[fg=#7f8c98]…#[fg=default]"
}

tmux_session_status_render_records() {
  local current="$1" session="" _agent="" state="" _source="" _updated_at=""
  local record="" direction=""
  local output="" formatted="" rendered="" available_width="" contribution=0 total_width=0 hidden=0 indicator="" indicator_width=0 last_index=0
  local show_indicator=0 i=0
  local -a accepted_records=() accepted_contributions=() candidate_records=() visual_items=()

  available_width=$(tmux_session_status_right_available_width 2>/dev/null || true)
  indicator=$(tmux_session_status_truncation_indicator)
  direction=$(tmux_agent_bar_scan_direction)

  while IFS=$'\t' read -r session _agent state _source _updated_at || [[ -n "${session:-}${_agent:-}${state:-}${_source:-}${_updated_at:-}" ]]; do
    [[ -n "${session}" ]] || continue
    [[ "${session}" != "${current}" ]] || continue
    [[ -n "${state}" ]] || continue
    if printf '%s\n' "${rendered}" | grep -Fqx "${session}"; then
      continue
    fi

    rendered+="${session}"$'\n'
    candidate_records+=("${session}"$'\t'"${_agent}"$'\t'"${state}"$'\t'"${_source}"$'\t'"${_updated_at}")
  done

  if (( ${#candidate_records[@]} > 0 )); then
    for (( i = 0; i < ${#candidate_records[@]}; i++ )); do
      IFS=$'\t' read -r session _agent state _source _updated_at <<< "${candidate_records[$i]}"
      formatted=$(tmux_session_status_format_session "${session}" "${state}")
      if [[ "${available_width}" =~ ^[0-9]+$ ]]; then
        contribution=$(tmux_session_status_visible_width "${formatted}")
        if (( ${#accepted_records[@]} > 0 )); then
          contribution=$(( contribution + 2 ))
        fi

        if (( total_width + contribution + 1 > available_width )); then
          hidden=$(( hidden + 1 ))
          continue
        fi

        accepted_records+=("${candidate_records[$i]}")
        accepted_contributions+=("${contribution}")
        total_width=$(( total_width + contribution ))
        continue
      fi

      accepted_records+=("${candidate_records[$i]}")
    done
  fi

  if [[ "${available_width}" =~ ^[0-9]+$ ]] && (( hidden > 0 )); then
    indicator_width=$(tmux_session_status_visible_width "${indicator}")
    if (( ${#accepted_records[@]} > 0 )); then
      indicator_width=$(( indicator_width + 2 ))
    fi

    while (( ${#accepted_records[@]} > 0 && total_width + indicator_width + 1 > available_width )); do
      last_index=$(( ${#accepted_records[@]} - 1 ))
      total_width=$(( total_width - accepted_contributions[$last_index] ))
      accepted_records=("${accepted_records[@]:0:${last_index}}")
      accepted_contributions=("${accepted_contributions[@]:0:${last_index}}")
      hidden=$(( hidden + 1 ))
      indicator_width=$(tmux_session_status_visible_width "${indicator}")
      if (( ${#accepted_records[@]} > 0 )); then
        indicator_width=$(( indicator_width + 2 ))
      fi
    done

    if (( total_width + indicator_width + 1 <= available_width )); then
      show_indicator=1
    fi
  fi

  if (( show_indicator == 1 )) && [[ "${direction}" == "right-to-left" ]]; then
    visual_items+=("${indicator}")
  fi
  while IFS=$'\t' read -r session _agent state _source _updated_at || [[ -n "${session:-}${_agent:-}${state:-}${_source:-}${_updated_at:-}" ]]; do
    [[ -n "${session}" ]] || continue
    visual_items+=("$(tmux_session_status_format_session "${session}" "${state}")")
  done < <(tmux_agent_bar_print_record_bucket "${accepted_records[@]-}" | tmux_agent_bar_emit_visual_ordered_records)
  if (( show_indicator == 1 )) && [[ "${direction}" == "left-to-right" ]]; then
    visual_items+=("${indicator}")
  fi

  if (( ${#visual_items[@]} > 0 )); then
    output="${visual_items[0]}"
    for (( last_index = 1; last_index < ${#visual_items[@]}; last_index++ )); do
      output+="  ${visual_items[$last_index]}"
    done
  fi

  if [[ -n "${output}" ]]; then
    printf '%s ' "${output}"
  fi
}

tmux_session_status_prune_orphan_state_files() {
  local state_dir="" state_file="" safe_name="" real_name=""

  state_dir=$(tmux_agent_bar_state_dir)
  [[ -d "${state_dir}" ]] || return 0

  for state_file in "${state_dir}"/*; do
    [[ -f "${state_file}" ]] || continue
    safe_name=$(basename "${state_file}")
    [[ "${safe_name}" == .* ]] && continue
    real_name=$(tmux_agent_bar_decode_session_name "${safe_name}")
    tmux has-session -t "${real_name}" 2>/dev/null || rm -f "${state_file}"
  done
}
