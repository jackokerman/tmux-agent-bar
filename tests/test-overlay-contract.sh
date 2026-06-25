#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-overlay-test"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

run_case() {
  local name="$1" expected="$2" local_rows="$3" overlay_body="$4" require_marker="${5:-0}"
  local tmp_dir="" overlay_script="" marker_file="" actual="" config_dir=""

  tmp_dir=$(mktemp -d)
  overlay_script="${tmp_dir}/overlay.sh"
  marker_file="${tmp_dir}/refresh-marker"
  config_dir="${tmp_dir}/config"
  mkdir -p "${config_dir}"

  if [[ -n "${overlay_body}" ]]; then
    printf '%s\n' "${overlay_body}" > "${overlay_script}"
  else
    rm -f "${overlay_script}"
  fi

  actual=$(
    CURRENT_SESSION="current" \
    LOCAL_ROWS="${local_rows}" \
    OVERLAY_MARKER="${marker_file}" \
    TMUX_SESSION_STATUS_OVERLAY_SCRIPT="${overlay_script}" \
    XDG_CONFIG_HOME="${config_dir}" \
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"

tmux_session_status_right_available_width() {
  return 1
}

tmux_session_status_current_session() {
  printf '%s\n' "${CURRENT_SESSION}"
}

tmux_session_status_local_emit_records() {
  printf '%b' "${LOCAL_ROWS}"
}

tmux_session_status_prune_orphan_state_files() {
  :
}

tmux_session_status_main
EOF
  )

  assert_equal "${name}" "${expected}" "${actual}"

  if [[ "${require_marker}" == "1" ]] && [[ ! -f "${marker_file}" ]]; then
    fail "${name} refresh hook was not called"
  fi

  rm -rf "${tmp_dir}"
}

run_case \
  "overlay records render and local records win on duplicate labels" \
  $'#[fg=#e3d18a] shared#[fg=default]  #[fg=#82aaff] local-only#[fg=default]  #[fg=#21c7a8] overlay-only#[fg=default] ' \
  $'local-only\tcodex\tworking\tlocal_explicit\t10\nshared\tcodex\twaiting\tlocal_explicit\t20\ncurrent\tcodex\tworking\tlocal_explicit\t30\n' \
  $'tmux_agent_overlay_maybe_refresh() {\n  : > "${OVERLAY_MARKER}"\n}\n\ntmux_agent_overlay_emit_records() {\n  printf \'shared\\tcodex\\tdone\\tremote_mirror\\t40\\n\'\n  printf \'overlay-only\\tclaude\\tdone\\tremote_mirror\\t50\\n\'\n}\n' \
  "1"

run_case \
  "session status works without any overlay script" \
  $'#[fg=#21c7a8] solo#[fg=default] ' \
  $'current\tcodex\tworking\tlocal_explicit\t10\nsolo\tclaude\tdone\tlocal_fallback\t0\n' \
  ""
