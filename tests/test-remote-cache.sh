#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-remote-cache-test"
TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT="/dev/null"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

run_case() {
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}/cache/tmux-agent-bar" "${tmp_dir}/config"

  cat > "${tmp_dir}/cache/tmux-agent-bar/remote-rows.tsv" <<'EOF'
# generated elsewhere
remote-alpha	codex	working	remote_cache	10

remote-beta	claude	done	remote_cache	20
EOF

  actual=$(
    XDG_CACHE_HOME="${tmp_dir}/cache" \
    XDG_CONFIG_HOME="${tmp_dir}/config" \
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"

tmux_session_status_local_emit_records() {
  :
}

tmux_agent_bar_emit_registered_records "current"
EOF
  )

  assert_equal \
    "remote cache source emits normalized rows and ignores blanks/comments" \
    $'remote-alpha\tcodex\tworking\tremote_cache\t10\nremote-beta\tclaude\tdone\tremote_cache\t20' \
    "${actual}"

  rm -rf "${tmp_dir}"
}

run_case
