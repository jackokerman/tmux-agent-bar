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

run_stale_working_helper_case() {
  local actual=""

  (
    # shellcheck source=/dev/null
    source "${TARGET_SCRIPT}"

    date() {
      if [[ "${1:-}" == "+%s" ]]; then
        printf '%s\n' "130"
        return 0
      fi

      command date "$@"
    }

    if tmux_agent_bar_remote_state_is_stale_working "100" "20"; then
      actual+="stale"
    else
      actual+="fresh"
    fi

    if tmux_agent_bar_remote_state_is_stale_working "120" "20"; then
      actual+=$'\n'"stale"
    else
      actual+=$'\n'"fresh"
    fi

    if tmux_agent_bar_remote_state_is_stale_working "not-a-mtime" "20"; then
      actual+=$'\n'"stale"
    else
      actual+=$'\n'"invalid"
    fi

    if tmux_agent_bar_remote_state_is_stale_working "100" "40"; then
      actual+=$'\n'"stale"
    else
      actual+=$'\n'"ttl-override"
    fi

    assert_equal \
      "remote stale-working helper compares numeric mtimes with a bounded ttl" \
      $'stale\nfresh\ninvalid\nttl-override' \
      "${actual}"
  )
}

run_case
run_stale_working_helper_case
