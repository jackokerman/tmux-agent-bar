#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="one-shot-source-test"
TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT="/dev/null"
TEST_XDG_CONFIG_HOME="$(mktemp -d)"
export XDG_CONFIG_HOME="${TEST_XDG_CONFIG_HOME}"
trap 'rm -rf "${TEST_XDG_CONFIG_HOME}"' EXIT

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"
# shellcheck source=/dev/null
source "${TARGET_SCRIPT}"

write_one_shot_config() {
  mkdir -p "${XDG_CONFIG_HOME}/tmux-agent-bar"
  printf '%s\n' "$@" > "${XDG_CONFIG_HOME}/tmux-agent-bar/one-shot.tsv"
}

run_configured_session_emit_case() {
  local actual=""

  (
    write_one_shot_config $'Review\treview-session'

    tmux() {
      if [[ "${1:-}" == "list-sessions" ]]; then
        printf '%s\n' "Review"
        printf '%s\n' "Notes"
        return 0
      fi

      if [[ "${1:-}" == "list-panes" && "${2:-}" == "-t" && "${3:-}" == "Review" ]]; then
        printf '%s\t%s\t%s\n' "Review" "100" "bash"
        return 0
      fi

      if [[ "${1:-}" == "list-panes" && "${2:-}" == "-t" && "${3:-}" == "Notes" ]]; then
        printf '%s\t%s\t%s\n' "Notes" "200" "zsh"
        return 0
      fi

      return 1
    }

    ps() {
      if [[ "${1:-}" == "-eo" ]]; then
        printf '%s\n' "100 1 bash /home/user/.local/bin/one-shot review-session"
        printf '%s\n' "101 100 review-session"
        printf '%s\n' "200 1 zsh"
        return 0
      fi

      command ps "$@"
    }

    actual=$(tmux_agent_bar_one_shot_emit "current")
    assert_equal \
      "configured one-shot sessions emit while running" \
      $'Review\tone-shot\tworking\tone_shot\t0' \
      "${actual}"
  )
}

run_current_session_hidden_case() {
  local actual=""

  (
    write_one_shot_config $'Review\treview-session'

    tmux() {
      if [[ "${1:-}" == "list-sessions" ]]; then
        printf '%s\n' "Review"
        return 0
      fi

      if [[ "${1:-}" == "list-panes" ]]; then
        printf '%s\t%s\t%s\n' "Review" "100" "review-session"
        return 0
      fi

      return 1
    }

    ps() {
      if [[ "${1:-}" == "-eo" ]]; then
        printf '%s\n' "100 1 review-session"
        return 0
      fi

      command ps "$@"
    }

    actual=$(tmux_agent_bar_one_shot_emit "Review")
    assert_equal "one-shot source hides the current session" "" "${actual}"
  )
}

run_unconfigured_session_ignored_case() {
  local actual=""

  (
    write_one_shot_config $'Review\treview-session'

    tmux() {
      if [[ "${1:-}" == "list-sessions" ]]; then
        printf '%s\n' "Notes"
        return 0
      fi

      if [[ "${1:-}" == "list-panes" ]]; then
        printf '%s\t%s\t%s\n' "Notes" "200" "zsh"
        return 0
      fi

      return 1
    }

    ps() {
      if [[ "${1:-}" == "-eo" ]]; then
        printf '%s\n' "200 1 zsh"
        return 0
      fi

      command ps "$@"
    }

    actual=$(tmux_agent_bar_one_shot_emit "current")
    assert_equal "one-shot source ignores unconfigured sessions" "" "${actual}"
  )
}

run_agent_tail_state_case() {
  local actual=""

  (
    write_one_shot_config $'Playground\tplayground-session'

    tmux() {
      if [[ "${1:-}" == "list-sessions" ]]; then
        printf '%s\n' "Playground"
        return 0
      fi

      if [[ "${1:-}" == "list-panes" && "${2:-}" == "-t" && "${3:-}" == "Playground" ]]; then
        printf '%s\t%s\t%s\n' "Playground" "100" "bash"
        return 0
      fi

      if [[ "${1:-}" == "capture-pane" ]]; then
        printf '%s\n' "• Working (12s)"
        return 0
      fi

      return 1
    }

    ps() {
      if [[ "${1:-}" == "-eo" ]]; then
        printf '%s\n' "100 1 bash /home/user/.local/bin/one-shot playground-session"
        printf '%s\n' "101 100 codex --model test"
        return 0
      fi

      command ps "$@"
    }

    actual=$(tmux_agent_bar_one_shot_emit "current")
    assert_equal \
      "one-shot source uses live agent tail state" \
      $'Playground\tone-shot\tworking\tone_shot\t0' \
      "${actual}"
  )
}

run_shadow_refresh_case() {
  local actual=""

  (
    local tmp_dir="" shadow_file=""

    write_one_shot_config \
      $'Playground\tplayground-session' \
      $'Review\treview-session'

    tmp_dir=$(mktemp -d)
    XDG_CACHE_HOME="${tmp_dir}/cache"
    shadow_file="${XDG_CACHE_HOME}/tmux-agent-bar/shadowed-sessions.txt"
    mkdir -p "$(dirname "${shadow_file}")"

    cat > "${shadow_file}" <<'EOF'
external-source
# tmux-agent-bar one-shot begin
stale session
# tmux-agent-bar one-shot end
EOF

    tmux_agent_bar_one_shot_refresh_shadowed_sessions
    actual=$(<"${shadow_file}")

    assert_equal \
      "one-shot refresh preserves external shadow entries" \
      "$(cat <<'EOF'
external-source
# tmux-agent-bar one-shot begin
Playground
Review
# tmux-agent-bar one-shot end
EOF
)" \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_no_config_removes_managed_shadow_block_case() {
  local actual=""

  (
    local tmp_dir="" shadow_file=""

    rm -f "${XDG_CONFIG_HOME}/tmux-agent-bar/one-shot.tsv"

    tmp_dir=$(mktemp -d)
    XDG_CACHE_HOME="${tmp_dir}/cache"
    shadow_file="${XDG_CACHE_HOME}/tmux-agent-bar/shadowed-sessions.txt"
    mkdir -p "$(dirname "${shadow_file}")"

    cat > "${shadow_file}" <<'EOF'
external-source
# tmux-agent-bar one-shot begin
stale session
# tmux-agent-bar one-shot end
EOF

    tmux_agent_bar_one_shot_refresh_shadowed_sessions
    actual=$(<"${shadow_file}")

    assert_equal \
      "one-shot refresh removes stale managed shadow block without config" \
      "external-source" \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_configured_session_emit_case
run_current_session_hidden_case
run_unconfigured_session_ignored_case
run_agent_tail_state_case
run_shadow_refresh_case
run_no_config_removes_managed_shadow_block_case
