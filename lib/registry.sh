#!/usr/bin/env bash

KNOWN_AGENT_COMMANDS=()
TMUX_AGENT_BAR_AGENT_NAMES=()
TMUX_AGENT_BAR_AGENT_COMMANDS=()
TMUX_AGENT_BAR_AGENT_CLASSIFIERS=()

TMUX_AGENT_BAR_SOURCE_NAMES=()
TMUX_AGENT_BAR_SOURCE_EMIT_FNS=()
TMUX_AGENT_BAR_SOURCE_REFRESH_FNS=()

tmux_agent_bar_agent_index() {
  local agent="$1" index=""

  for index in "${!TMUX_AGENT_BAR_AGENT_NAMES[@]}"; do
    if [[ "${TMUX_AGENT_BAR_AGENT_NAMES[${index}]}" == "${agent}" ]]; then
      printf '%s\n' "${index}"
      return 0
    fi
  done

  return 1
}

tmux_agent_bar_source_index() {
  local name="$1" index=""

  for index in "${!TMUX_AGENT_BAR_SOURCE_NAMES[@]}"; do
    if [[ "${TMUX_AGENT_BAR_SOURCE_NAMES[${index}]}" == "${name}" ]]; then
      printf '%s\n' "${index}"
      return 0
    fi
  done

  return 1
}

tmux_agent_bar_rebuild_known_commands() {
  local cmd=""

  KNOWN_AGENT_COMMANDS=()

  for cmd in "${TMUX_AGENT_BAR_AGENT_COMMANDS[@]}"; do
    [[ -n "${cmd}" ]] || continue
    KNOWN_AGENT_COMMANDS+=("${cmd}")
  done
}

tmux_agent_register_command() {
  local agent="$1" command="$2" index=""

  if index=$(tmux_agent_bar_agent_index "${agent}" 2>/dev/null); then
    TMUX_AGENT_BAR_AGENT_COMMANDS[${index}]="${command}"
  else
    TMUX_AGENT_BAR_AGENT_NAMES+=("${agent}")
    TMUX_AGENT_BAR_AGENT_COMMANDS+=("${command}")
    TMUX_AGENT_BAR_AGENT_CLASSIFIERS+=("")
  fi

  tmux_agent_bar_rebuild_known_commands
}

tmux_agent_register_classifier() {
  local agent="$1" classifier="$2" index=""

  if index=$(tmux_agent_bar_agent_index "${agent}" 2>/dev/null); then
    TMUX_AGENT_BAR_AGENT_CLASSIFIERS[${index}]="${classifier}"
  else
    TMUX_AGENT_BAR_AGENT_NAMES+=("${agent}")
    TMUX_AGENT_BAR_AGENT_COMMANDS+=("")
    TMUX_AGENT_BAR_AGENT_CLASSIFIERS+=("${classifier}")
  fi
}

tmux_agent_bar_classifier_for_agent() {
  local agent="$1" index=""

  index=$(tmux_agent_bar_agent_index "${agent}") || return 1
  [[ -n "${TMUX_AGENT_BAR_AGENT_CLASSIFIERS[${index}]}" ]] || return 1

  printf '%s\n' "${TMUX_AGENT_BAR_AGENT_CLASSIFIERS[${index}]}"
}

tmux_agent_bar_command_for_agent() {
  local agent="$1" index=""

  index=$(tmux_agent_bar_agent_index "${agent}") || return 1
  [[ -n "${TMUX_AGENT_BAR_AGENT_COMMANDS[${index}]}" ]] || return 1

  printf '%s\n' "${TMUX_AGENT_BAR_AGENT_COMMANDS[${index}]}"
}

tmux_agent_bar_agent_for_command() {
  local command="$1" index=""

  for index in "${!TMUX_AGENT_BAR_AGENT_COMMANDS[@]}"; do
    if [[ "${TMUX_AGENT_BAR_AGENT_COMMANDS[${index}]}" == "${command}" ]]; then
      printf '%s\n' "${TMUX_AGENT_BAR_AGENT_NAMES[${index}]}"
      return 0
    fi
  done

  return 1
}

tmux_agent_register_source() {
  local name="$1" emit_fn="$2" refresh_fn="${3:-}" index=""

  if index=$(tmux_agent_bar_source_index "${name}" 2>/dev/null); then
    TMUX_AGENT_BAR_SOURCE_EMIT_FNS[${index}]="${emit_fn}"
    TMUX_AGENT_BAR_SOURCE_REFRESH_FNS[${index}]="${refresh_fn}"
    return 0
  fi

  TMUX_AGENT_BAR_SOURCE_NAMES+=("${name}")
  TMUX_AGENT_BAR_SOURCE_EMIT_FNS+=("${emit_fn}")
  TMUX_AGENT_BAR_SOURCE_REFRESH_FNS+=("${refresh_fn}")
}

tmux_agent_bar_maybe_refresh_sources() {
  local index="" refresh_fn=""

  for index in "${!TMUX_AGENT_BAR_SOURCE_NAMES[@]}"; do
    refresh_fn="${TMUX_AGENT_BAR_SOURCE_REFRESH_FNS[${index}]}"
    [[ -n "${refresh_fn}" ]] || continue
    declare -F "${refresh_fn}" >/dev/null 2>&1 || continue
    "${refresh_fn}" || true
  done
}

tmux_agent_bar_emit_registered_records() {
  local current="$1" index="" emit_fn=""

  for index in "${!TMUX_AGENT_BAR_SOURCE_NAMES[@]}"; do
    emit_fn="${TMUX_AGENT_BAR_SOURCE_EMIT_FNS[${index}]}"
    [[ -n "${emit_fn}" ]] || continue
    declare -F "${emit_fn}" >/dev/null 2>&1 || continue
    "${emit_fn}" "${current}" 2>/dev/null || true
  done
}
