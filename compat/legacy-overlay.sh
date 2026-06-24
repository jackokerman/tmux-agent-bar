#!/usr/bin/env bash

tmux_agent_bar_legacy_overlay_script() {
  printf '%s\n' "${TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT:-${TMUX_SESSION_STATUS_OVERLAY_SCRIPT:-${HOME}/.config/tmux/session-status-overlay.sh}}"
}

tmux_agent_bar_legacy_overlay_refresh() {
  if declare -F tmux_agent_overlay_maybe_refresh >/dev/null 2>&1; then
    tmux_agent_overlay_maybe_refresh || true
  fi
}

tmux_agent_bar_legacy_overlay_emit() {
  local current="$1"

  if declare -F tmux_agent_overlay_emit_records >/dev/null 2>&1; then
    tmux_agent_overlay_emit_records "${current}" 2>/dev/null || true
  fi
}

tmux_agent_bar_load_legacy_overlay() {
  local overlay_script=""

  overlay_script=$(tmux_agent_bar_legacy_overlay_script)
  [[ -r "${overlay_script}" ]] || return 0

  # shellcheck source=/dev/null
  source "${overlay_script}"

  if declare -F tmux_agent_overlay_maybe_refresh >/dev/null 2>&1 || declare -F tmux_agent_overlay_emit_records >/dev/null 2>&1; then
    tmux_agent_register_source "legacy-overlay" "tmux_agent_bar_legacy_overlay_emit" "tmux_agent_bar_legacy_overlay_refresh"
  fi
}

tmux_agent_bar_load_legacy_overlay
