#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-registration-test"
TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT="/dev/null"
TEST_XDG_CONFIG_HOME="$(mktemp -d)"
export XDG_CONFIG_HOME="${TEST_XDG_CONFIG_HOME}"
trap 'rm -rf "${TEST_XDG_CONFIG_HOME}"' EXIT

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"
# shellcheck source=/dev/null
source "${TARGET_SCRIPT}"

run_agent_registration_case() {
  local actual=""

  custom_classifier() {
    local line="$1"
    [[ "${line}" == *"custom wait"* ]] && printf '%s\n' "waiting" || printf '%s\n' ""
  }

  tmux_agent_register_command "custom" "custom-agent"
  tmux_agent_register_classifier "custom" "custom_classifier"
  actual=$(tmux_agent_infer_state_from_tail "custom" $'line one\ncustom wait\n')
  assert_equal "custom agent classifier registration works" "waiting" "${actual}"
}

run_source_registration_case() {
  local actual=""

  tmux_session_status_local_emit_records() {
    :
  }

  tmux_agent_bar_local_emit_records() {
    :
  }

  tmux_agent_bar_remote_cache_emit_records() {
    :
  }

  tmux_agent_bar_legacy_overlay_emit() {
    :
  }

  custom_emit() {
    printf '%s\n' $'alpha\tcustom\tworking\tcustom_source\t10'
  }

  tmux_agent_register_source "custom-source" "custom_emit"
  actual=$(tmux_agent_bar_emit_registered_records "current" | tail -n 1)
  assert_equal "custom source registration works" $'alpha\tcustom\tworking\tcustom_source\t10' "${actual}"
}

run_unknown_explicit_agent_case() {
  local tmp_dir="" actual=""

  (
    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'aider\tworking\n' > "${STATE_DIR}/notes"

    _session_has_known_agent_pane() {
      return 1
    }

    actual=$(tmux_session_status_emit_local_record "notes" "current")
    assert_matches "unknown explicit-only agents still render" $'^notes\taider\tworking\tlocal_explicit\t[0-9]+$' "${actual}"
    rm -rf "${tmp_dir}"
  )
}

run_agent_registration_case
run_source_registration_case
run_unknown_explicit_agent_case
