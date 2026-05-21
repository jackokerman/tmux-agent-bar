#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-current-state-test"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

run_case() {
  local name="$1" current_session="$2" rows="$3" expected="$4"
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)

  actual=$(
    CURRENT_SESSION="${current_session}" \
    ROWS="${rows}" \
    XDG_CONFIG_HOME="${tmp_dir}/config" \
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"

tmux_session_status_current_session() {
  printf '%s\n' "${CURRENT_SESSION}"
}

tmux_agent_bar_maybe_refresh_sources() {
  :
}

tmux_agent_bar_emit_registered_records() {
  printf '%b' "${ROWS}"
}

tmux_session_status_current_state
EOF
  )

  assert_equal "${name}" "${expected}" "${actual}"
  rm -rf "${tmp_dir}"
}

run_case \
  "current state returns the matching current-session state" \
  "current" \
  $'other\tcodex\tdone\tlocal_explicit\t10\ncurrent\tcodex\tworking\tlocal_explicit\t20\n' \
  "working"

run_case \
  "current state prefers the first matching current-session record" \
  "current" \
  $'current\tcodex\twaiting\tlocal_explicit\t20\ncurrent\tcodex\tdone\tremote_mirror\t30\n' \
  "waiting"

run_case \
  "current state stays empty when no current-session record exists" \
  "current" \
  $'other\tcodex\tworking\tlocal_explicit\t10\n' \
  ""
