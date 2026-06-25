#!/usr/bin/env bash

tmux_agent_bar_record_already_seen() {
  local session="$1" seen_session=""

  for seen_session in "${TMUX_AGENT_BAR_SEEN_SESSIONS[@]}"; do
    [[ "${seen_session}" == "${session}" ]] && return 0
  done

  return 1
}

tmux_agent_bar_append_prioritized_record() {
  local state="$1" record="$2"

  case "${state}" in
    waiting) TMUX_AGENT_BAR_WAITING_RECORDS+=("${record}") ;;
    working) TMUX_AGENT_BAR_WORKING_RECORDS+=("${record}") ;;
    done)    TMUX_AGENT_BAR_DONE_RECORDS+=("${record}") ;;
    *)       TMUX_AGENT_BAR_OTHER_RECORDS+=("${record}") ;;
  esac
}

tmux_agent_bar_print_record_bucket() {
  local record=""

  for record in "$@"; do
    printf '%s\n' "${record}"
  done
}

tmux_agent_bar_emit_prioritized_records() {
  local current="${1:-}" filter_current="${2:-1}" source_current=""
  local session="" agent="" state="" source="" updated_at="" record=""
  local -a TMUX_AGENT_BAR_SEEN_SESSIONS=()
  local -a TMUX_AGENT_BAR_WAITING_RECORDS=() TMUX_AGENT_BAR_WORKING_RECORDS=()
  local -a TMUX_AGENT_BAR_DONE_RECORDS=() TMUX_AGENT_BAR_OTHER_RECORDS=()

  source_current="${current}"
  if (( $# >= 3 )); then
    source_current="$3"
  fi

  while IFS=$'\t' read -r session agent state source updated_at || [[ -n "${session:-}${agent:-}${state:-}${source:-}${updated_at:-}" ]]; do
    [[ -n "${session}" ]] || continue
    [[ -n "${state}" ]] || continue
    if [[ "${filter_current}" == "1" && -n "${current}" && "${session}" == "${current}" ]]; then
      continue
    fi
    if tmux_agent_bar_record_already_seen "${session}"; then
      continue
    fi

    TMUX_AGENT_BAR_SEEN_SESSIONS+=("${session}")
    record="${session}"$'\t'"${agent}"$'\t'"${state}"$'\t'"${source}"$'\t'"${updated_at}"
    tmux_agent_bar_append_prioritized_record "${state}" "${record}"
  done < <(tmux_agent_bar_emit_registered_records "${source_current}")

  tmux_agent_bar_print_record_bucket "${TMUX_AGENT_BAR_WAITING_RECORDS[@]}"
  tmux_agent_bar_print_record_bucket "${TMUX_AGENT_BAR_WORKING_RECORDS[@]}"
  tmux_agent_bar_print_record_bucket "${TMUX_AGENT_BAR_DONE_RECORDS[@]}"
  tmux_agent_bar_print_record_bucket "${TMUX_AGENT_BAR_OTHER_RECORDS[@]}"
}

tmux_agent_bar_scan_direction() {
  case "${TMUX_AGENT_BAR_SCAN_DIRECTION:-right-to-left}" in
    left-to-right) printf '%s\n' "left-to-right" ;;
    *)             printf '%s\n' "right-to-left" ;;
  esac
}

tmux_agent_bar_emit_scan_ordered_records() {
  awk -F '\t' -v OFS='\t' '
    function state_priority(state) {
      if (state == "waiting") {
        return 1
      }
      if (state == "done") {
        return 2
      }
      if (state == "working") {
        return 3
      }
      return 4
    }

    {
      seq += 1
      timestamp_group = 1
      timestamp = 0
      if ($5 ~ /^[0-9]+$/) {
        timestamp_group = 0
        timestamp = $5
      }
      print state_priority($3), timestamp_group, timestamp, seq, $0
    }
  ' | sort -t $'\t' -k1,1n -k2,2n -k3,3n -k4,4n | cut -f5-
}

tmux_agent_bar_emit_visual_ordered_records() {
  local direction="" record="" i=0
  local -a scan_ordered_records=()

  direction=$(tmux_agent_bar_scan_direction)
  if [[ "${direction}" == "left-to-right" ]]; then
    tmux_agent_bar_emit_scan_ordered_records
    return 0
  fi

  while IFS= read -r record || [[ -n "${record}" ]]; do
    scan_ordered_records+=("${record}")
  done < <(tmux_agent_bar_emit_scan_ordered_records)

  for (( i = ${#scan_ordered_records[@]} - 1; i >= 0; i-- )); do
    printf '%s\n' "${scan_ordered_records[$i]}"
  done
}
