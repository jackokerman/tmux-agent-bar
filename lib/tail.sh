#!/usr/bin/env bash

if ! declare -F tmux_agent_bar_classifier_for_agent >/dev/null 2>&1; then
  TMUX_AGENT_BAR_REPO_DIR="${TMUX_AGENT_BAR_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  # shellcheck source=/dev/null
  source "${TMUX_AGENT_BAR_REPO_DIR}/lib/util.sh"
  # shellcheck source=/dev/null
  source "${TMUX_AGENT_BAR_REPO_DIR}/lib/state.sh"
  # shellcheck source=/dev/null
  source "${TMUX_AGENT_BAR_REPO_DIR}/lib/registry.sh"
  # shellcheck source=/dev/null
  source "${TMUX_AGENT_BAR_REPO_DIR}/agents/claude.sh"
  # shellcheck source=/dev/null
  source "${TMUX_AGENT_BAR_REPO_DIR}/agents/codex.sh"
fi

tmux_agent_capture_tail() {
  local session="$1" lines="${2:-40}"
  tmux capture-pane -pt "${session}" 2>/dev/null | tail -n "${lines}" || true
}

tmux_agent_reverse_lines() {
  awk '{ lines[NR] = $0 } END { for (i = NR; i >= 1; i--) print lines[i] }'
}

tmux_agent_line_is_question_waiting() {
  local line="$1"

  case "${line}" in
    *"tab to add notes"*|*"enter to submit answer"*|*"←/→ to navigate questions"*)
      return 0
      ;;
  esac

  [[ "${line}" == *"Question "* && "${line}" == *"unanswered"* ]]
}

tmux_agent_line_is_plan_waiting() {
  local line="$1"

  case "${line}" in
    *"Implement this plan?"*|*"Yes, implement this plan"*|*"No, stay in Plan mode"*|*"Press enter to confirm or esc to go back"*)
      return 0
      ;;
  esac

  return 1
}

tmux_agent_line_is_approval_waiting() {
  local line="$1"

  case "${line}" in
    *"Do you want me to "*|*"Would you like to run the following command?"*|*"Press enter to confirm or esc to cancel"*|*"permission prompt"*)
      return 0
      ;;
  esac

  return 1
}

tmux_agent_line_is_waiting() {
  local line="$1"

  tmux_agent_line_is_question_waiting "${line}" ||
    tmux_agent_line_is_plan_waiting "${line}" ||
    tmux_agent_line_is_approval_waiting "${line}"
}

tmux_codex_line_is_waiting() {
  tmux_agent_line_is_waiting "$1"
}

tmux_codex_running_hook_name() {
  local line="$1"

  [[ "${line}" =~ ^[[:space:]]*•[[:space:]]Running[[:space:]](.+)[[:space:]]hook$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

tmux_codex_completed_hook_name() {
  local line="$1"

  [[ "${line}" =~ ^[[:space:]]*(.+)[[:space:]]hook[[:space:]]\(completed\)$ ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

tmux_codex_line_is_turn_complete_boundary() {
  local line="$1"

  [[ "${line}" == *"Worked for "* ]]
}

tmux_agent_line_is_external_terminal_boundary() {
  local line="$1"

  case "${line}" in
    "Client: Waiting before next attempt"*|"Connector: disconnected"*)
      return 0
      ;;
  esac

  return 1
}

tmux_codex_line_is_status_footer() {
  local line="$1"

  [[ "${line}" =~ ^[[:space:]]*(gpt|o[0-9]|codex)[^[:space:]]*.*[[:space:]]·[[:space:]] ]]
}

tmux_codex_tail_has_agent_identity() {
  local tail="$1" line="" marker_count=0

  while IFS= read -r line; do
    if tmux_codex_line_is_status_footer "${line}"; then
      return 0
    fi

    case "${line}" in
      "• Explored"*|"• Edited "*|"• Ran "*|"• Read "*|"• Search "*|"› "*|"  └ "*)
        (( marker_count += 1 ))
        ;;
    esac
  done < <(printf '%s\n' "${tail}" | tmux_agent_reverse_lines)

  (( marker_count >= 2 ))
}

tmux_codex_line_is_working() {
  local line="$1"

  if tmux_agent_line_is_working "${line}"; then
    return 0
  fi

  if tmux_codex_running_hook_name "${line}" >/dev/null 2>&1; then
    return 0
  fi

  case "${line}" in
    *"• Waiting for background terminal"*|*"• Messages to be submitted after next tool call"*)
      return 0
      ;;
  esac

  return 1
}

tmux_agent_line_is_working() {
  local line="$1"

  case "${line}" in
    *"• Working ("*)
      return 0
      ;;
  esac

  return 1
}

tmux_agent_classify_line() {
  local line="$1"

  if tmux_agent_line_is_waiting "${line}"; then
    printf '%s\n' "waiting"
    return 0
  fi

  if tmux_agent_line_is_working "${line}"; then
    printf '%s\n' "working"
    return 0
  fi

  printf '%s\n' ""
}

tmux_codex_classify_line() {
  local line="$1"

  # Waiting prompts need attention, so they take precedence over the generic
  # in-progress marker when both appear in the same footer block.
  if tmux_codex_line_is_waiting "${line}"; then
    printf '%s\n' "waiting"
    return 0
  fi

  if tmux_codex_line_is_working "${line}"; then
    printf '%s\n' "working"
    return 0
  fi

  printf '%s\n' ""
}

tmux_codex_infer_state_from_tail() {
  local tail="$1" line="" state="" hook="" completed_hooks=""

  while IFS= read -r line; do
    if tmux_codex_line_is_turn_complete_boundary "${line}" ||
       tmux_agent_line_is_external_terminal_boundary "${line}"; then
      printf '%s\n' ""
      return 0
    fi

    hook=$(tmux_codex_completed_hook_name "${line}" 2>/dev/null || true)
    if [[ -n "${hook}" ]]; then
      completed_hooks+=$'\n'"${hook}"
      continue
    fi

    state=$(tmux_codex_classify_line "${line}")
    [[ -n "${state}" ]] || continue

    if [[ "${state}" == "working" ]]; then
      hook=$(tmux_codex_running_hook_name "${line}" 2>/dev/null || true)
      if [[ -n "${hook}" ]] && printf '%s\n' "${completed_hooks}" | grep -Fqx "${hook}"; then
        continue
      fi
    fi

    printf '%s\n' "${state}"
    return 0
  done < <(printf '%s\n' "${tail}" | tmux_agent_reverse_lines)

  printf '%s\n' ""
}

tmux_agent_infer_state_from_tail_with_classifier() {
  local tail="$1" classifier="$2" line="" state=""

  while IFS= read -r line; do
    state=$("${classifier}" "${line}")
    if [[ -n "${state}" ]]; then
      printf '%s\n' "${state}"
      return 0
    fi
  done < <(printf '%s\n' "${tail}" | tmux_agent_reverse_lines)

  printf '%s\n' ""
}

tmux_agent_infer_state_from_tail() {
  local agent="$1" tail="$2" classifier="" custom_infer=""

  custom_infer="tmux_${agent}_infer_state_from_tail"
  if declare -F "${custom_infer}" >/dev/null 2>&1; then
    "${custom_infer}" "${tail}"
    return 0
  fi

  classifier=$(tmux_agent_bar_classifier_for_agent "${agent}" 2>/dev/null || true)
  [[ -n "${classifier}" ]] || {
    printf '%s\n' ""
    return 0
  }

  tmux_agent_infer_state_from_tail_with_classifier "${tail}" "${classifier}"
}

tmux_agent_infer_agent_state_from_tail() {
  local tail="$1" agent="" state="" identity_check=""

  for agent in "${TMUX_AGENT_BAR_AGENT_NAMES[@]}"; do
    [[ -n "${agent}" ]] || continue

    identity_check="tmux_${agent}_tail_has_agent_identity"
    declare -F "${identity_check}" >/dev/null 2>&1 || continue
    if ! "${identity_check}" "${tail}"; then
      continue
    fi

    state=$(tmux_agent_infer_state_from_tail "${agent}" "${tail}")
    if [[ -n "${state}" ]]; then
      printf '%s\t%s\n' "${agent}" "${state}"
      return 0
    fi
  done

  return 1
}

tmux_agent_session_live_state() {
  local session="$1" agent="$2" tail=""

  [[ -n "${agent}" ]] || {
    printf '%s\n' ""
    return 0
  }

  tail=$(tmux_agent_capture_tail "${session}")
  tmux_agent_infer_state_from_tail "${agent}" "${tail}"
}

tmux_agent_session_inferred_agent_state() {
  local session="$1" tail=""

  tail=$(tmux_agent_capture_tail "${session}")
  [[ -n "${tail}" ]] || return 1

  tmux_agent_infer_agent_state_from_tail "${tail}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    infer-session)
      tmux_agent_session_live_state "${2:-}" "${3:-}"
      ;;
    infer-tail)
      agent="${2:-}"
      tail=$(cat)
      tmux_agent_infer_state_from_tail "${agent}" "${tail}"
      ;;
    *)
      echo "usage: ${0##*/} <infer-session session agent|infer-tail agent>" >&2
      exit 2
      ;;
  esac
fi
