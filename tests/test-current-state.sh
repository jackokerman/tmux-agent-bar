#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-current-state-test"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

run_case() {
  local name="$1" current_session="$2" target_session="$3" rows="$4" expected="$5"
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)

  actual=$(
    CURRENT_SESSION="${current_session}" \
    ROWS="${rows}" \
    TARGET_SESSION="${target_session}" \
    XDG_CONFIG_HOME="${tmp_dir}/config" \
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"

tmux_session_status_current_session() {
  if [[ -n "${1:-}" ]]; then
    printf '%s\n' "${1}"
    return 0
  fi

  printf '%s\n' "${CURRENT_SESSION}"
}

tmux_agent_bar_maybe_refresh_sources() {
  :
}

tmux_agent_bar_emit_registered_records() {
  printf '%b' "${ROWS}"
}

tmux_session_status_current_state "${TARGET_SESSION}"
EOF
  )

  assert_equal "${name}" "${expected}" "${actual}"
  rm -rf "${tmp_dir}"
}

run_case \
  "current state returns the matching current-session state" \
  "current" \
  "" \
  $'other\tcodex\tdone\tlocal_explicit\t10\ncurrent\tcodex\tworking\tlocal_explicit\t20\n' \
  "working"

run_case \
  "current state prefers the first matching current-session record" \
  "current" \
  "" \
  $'current\tcodex\twaiting\tlocal_explicit\t20\ncurrent\tcodex\tdone\tremote_mirror\t30\n' \
  "waiting"

run_case \
  "current state stays empty when no current-session record exists" \
  "current" \
  "" \
  $'other\tcodex\tworking\tlocal_explicit\t10\n' \
  ""

run_case \
  "current state can target an explicit session without relying on the ambient tmux session" \
  "other" \
  "tmux-agent-bar" \
  $'other\tcodex\tdone\tlocal_explicit\t10\ntmux-agent-bar\tcodex\twaiting\tlocal_explicit\t20\n' \
  "waiting"

run_target_resolution_case() {
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}/bin"

  cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "display-message" && "${2:-}" == "-p" && "${3:-}" == "-t" && "${4:-}" == '$23' ]]; then
  printf '%s\n' "tmux-agent-bar"
  exit 0
fi
exit 1
EOF
  chmod +x "${tmp_dir}/bin/tmux"

  actual=$(
    PATH="${tmp_dir}/bin:${PATH}" \
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"
tmux_session_status_current_session '$23'
EOF
  )

  assert_equal \
    "current session resolves an explicit tmux target before matching records" \
    "tmux-agent-bar" \
    "${actual}"

  rm -rf "${tmp_dir}"
}

run_target_resolution_case
