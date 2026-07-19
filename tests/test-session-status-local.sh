#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-local-test"
TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT="/dev/null"

# shellcheck source=/dev/null
source "${TARGET_SCRIPT}"
# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

TEST_CACHE_HOME=$(mktemp -d)
export XDG_CACHE_HOME="${TEST_CACHE_HOME}"
trap 'rm -rf "${TEST_CACHE_HOME}"' EXIT

run_done_cleanup_case() {
  local name="$1"

  (
    local tmp_dir="" safe_session="docs%2Ffeature" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${safe_session}"

    _session_has_live_agent_process() {
      return 1
    }

    actual=$(tmux_session_status_emit_local_record "docs/feature" "current")
    assert_equal "${name}" "" "${actual}"

    if [[ -e "${STATE_DIR}/${safe_session}" ]]; then
      fail "${name} state file was not removed"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_done_cleanup_case \
    "explicit done local session without a live agent is hidden and clears state"

run_shell_wrapped_done_identity_cleanup_case() {
  local name="$1"

  (
    local tmp_dir="" session="done-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${session}"

    _session_has_live_agent_process() {
      return 1
    }

    _session_tail_identified_agent() {
      printf '%s\n' "codex"
    }

    _session_has_known_agent_pane() {
      return 1
    }

    _state_file_mtime() {
      printf '%s\n' "42"
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal "${name}" "" "${actual}"

    if [[ -e "${STATE_DIR}/${session}" ]]; then
      fail "${name} state file was not removed"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_done_identity_cleanup_case \
    "explicit done shell-wrapped sessions clear when no live agent process remains"

run_shell_wrapped_stale_done_identity_case() {
  local name="$1"

  (
    local tmp_dir="" session="done-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${session}"
    touch -t 202001010000 "${STATE_DIR}/${session}"

    _session_has_live_agent_process() {
      return 1
    }

    _session_tail_identified_agent() {
      printf '%s\n' "codex"
    }

    _session_has_known_agent_pane() {
      return 1
    }

    _session_live_state() {
      printf '%s\n' ""
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal "${name}" "" "${actual}"

    if [[ -e "${STATE_DIR}/${session}" ]]; then
      fail "${name} state file was not removed"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_stale_done_identity_case \
    "stale explicit done shell-wrapped sessions are hidden even when old tail identifies the agent"

run_shell_wrapped_done_no_process_live_tail_case() {
  local name="$1"

  (
    local tmp_dir="" session="done-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${session}"

    _session_has_live_agent_process() {
      return 1
    }

    _session_tail_identified_agent() {
      printf '%s\n' "codex"
    }

    _session_has_known_agent_pane() {
      return 1
    }

    _session_live_state() {
      printf '%s\n' "working"
    }

    _state_file_mtime() {
      printf '%s\n' "42"
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal "${name}" "" "${actual}"

    if [[ -e "${STATE_DIR}/${session}" ]]; then
      fail "${name} state file was not removed"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_done_no_process_live_tail_case \
    "explicit done shell-wrapped sessions ignore old working tail after the agent exits"

run_shell_wrapped_explicit_done_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${session}"

    _session_has_live_agent_process() {
      return 0
    }

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_live_state() {
      printf '%s\n' "working"
    }

    _state_file_mtime() {
      printf '%s\n' "42"
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      $'review-shell\tcodex\tworking\tlocal_explicit\t42' \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_explicit_done_case \
    "shell-wrapped explicit done session recovers to working from the live pane"

run_shell_wrapped_hook_recovery_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${session}"

    _session_has_live_agent_process() {
      return 0
    }

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    tmux_agent_capture_tail() {
      cat <<'EOF'
• Running PostToolUse hook


› Find and fix a bug in @filename

  gpt-5.4 xhigh · ~/src/project
EOF
    }

    _state_file_mtime() {
      printf '%s\n' "42"
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      $'review-shell\tcodex\tworking\tlocal_explicit\t42' \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_hook_recovery_case \
    "shell-wrapped explicit done session recovers to working from a live hook footer"

run_shell_wrapped_fallback_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_has_live_agent_process() {
      return 0
    }

    _session_live_state() {
      printf '%s\n' "working"
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      $'review-shell\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_fallback_case \
    "shell-wrapped live agent sessions without explicit state still render"

run_shell_wrapped_tail_fallback_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    XDG_CACHE_HOME="${tmp_dir}/cache"

    _session_pane_rows() {
      printf '%s\t%s\t%s\t%s\n' "${session}" "%200" "200" "bash"
    }

    _session_agent_command() {
      return 1
    }

    tmux_agent_capture_tail() {
      cat <<'EOF'
› Fix the navigation config

  gpt-5.5 medium · ~/src/project

• Working (1m 12s • esc to interrupt)
EOF
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      $'review-shell\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_tail_fallback_case \
    "shell-wrapped sessions without a local agent process recover from the live tail"

run_shell_wrapped_footerless_tail_fallback_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    XDG_CACHE_HOME="${tmp_dir}/cache"

    _session_pane_rows() {
      printf '%s\t%s\t%s\t%s\n' "${session}" "%200" "200" "bash"
    }

    _session_agent_command() {
      return 1
    }

    tmux_agent_capture_tail() {
      cat <<'EOF'
• Explored
  └ Read writer.ts

• Working (1m 12s • esc to interrupt)

› Fix the navigation config
EOF
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      $'review-shell\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_footerless_tail_fallback_case \
    "shell-wrapped sessions without a local agent process recover from footerless Codex UI tail"

run_shell_wrapped_unidentified_active_tail_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    XDG_CACHE_HOME="${tmp_dir}/cache"

    _session_pane_rows() {
      printf '%s\t%s\t%s\t%s\n' "${session}" "%200" "200" "bash"
    }

    _session_agent_command() {
      return 1
    }

    tmux_agent_capture_tail() {
      cat <<'EOF'
copied transcript:
• Working (1m 12s • esc to interrupt)
EOF
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal "${name}" "" "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_unidentified_active_tail_case \
    "shell-wrapped sessions without agent identity stay hidden even with active-looking text"

run_shell_wrapped_neutral_tail_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    XDG_CACHE_HOME="${tmp_dir}/cache"

    _session_pane_rows() {
      printf '%s\t%s\t%s\t%s\n' "${session}" "%200" "200" "bash"
    }

    _session_agent_command() {
      return 1
    }

    tmux_agent_capture_tail() {
      cat <<'EOF'
› Fix the navigation config

  gpt-5.5 medium · ~/src/project
EOF
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      "" \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_neutral_tail_case \
    "shell-wrapped sessions without a local agent process hide identified neutral tails"

run_shell_wrapped_completed_tail_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    XDG_CACHE_HOME="${tmp_dir}/cache"

    _session_pane_rows() {
      printf '%s\t%s\t%s\t%s\n' "${session}" "%200" "200" "bash"
    }

    _session_agent_command() {
      return 1
    }

    tmux_agent_capture_tail() {
      cat <<'EOF'
• Working (2m 27s • esc to interrupt)

─ Worked for 2m 31s ─


› Use /skills to list available skills

  gpt-5.5 medium · /workspace/project
EOF
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      "" \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_completed_tail_case \
    "shell-wrapped sessions without a local agent process hide completed Codex tails"

run_shell_wrapped_observed_completion_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual="" tail_mode="working" observed_file=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    mkdir -p "${STATE_DIR}"

    _session_pane_rows() {
      printf '%s\t%s\t%s\t%s\n' "${session}" "%200" "200" "bash"
    }

    _session_agent_command() {
      return 1
    }

    tmux_agent_capture_tail() {
      if [[ "${tail_mode}" == "working" ]]; then
        cat <<'EOF'
› Fix the navigation config

  gpt-5.5 medium · ~/src/project

• Working (1m 12s • esc to interrupt)
EOF
        return 0
      fi

      cat <<'EOF'
• Working (2m 27s • esc to interrupt)

─ Worked for 2m 31s ─


› Use /skills to list available skills

  gpt-5.5 medium · /workspace/project
EOF
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name} first renders working" \
      $'review-shell\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    observed_file="$(tmux_agent_bar_observed_sessions_dir)/${session}"
    if [[ ! -f "${observed_file}" ]]; then
      fail "${name} did not record observed active state"
    fi

    tail_mode="done"
    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name} then clears completed fallback marker" \
      "" \
      "${actual}"

    if [[ -e "${observed_file}" ]]; then
      fail "${name} observed marker was not removed"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_observed_completion_case \
    "observed shell-wrapped fallback sessions clear when they complete"

run_shell_wrapped_connector_tail_case() {
  local name="$1"

  (
    local tmp_dir="" session="review-shell" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"

    _session_pane_rows() {
      printf '%s\t%s\t%s\t%s\n' "${session}" "%200" "200" "bash"
    }

    _session_agent_command() {
      return 1
    }

    tmux_agent_capture_tail() {
      cat <<'EOF'
• Working (2m 27s • esc to interrupt)

  gpt-5.5 medium · /workspace/project

Client: Waiting before next attempt
Connector: disconnected
EOF
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal "${name}" "" "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shell_wrapped_connector_tail_case \
    "shell-wrapped connector screens stay hidden instead of rendering stale done"

run_idle_fallback_done_case() {
  local name="$1"

  (
    local tmp_dir="" session="idle-fallback" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_live_state() {
      printf '%s\n' ""
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      "" \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_idle_fallback_done_case \
    "fallback sessions stay hidden when the live pane is neutral"

run_explicit_done_idle_case() {
  local name="$1"

  (
    local tmp_dir="" session="done-idle" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${session}"

    _session_has_live_agent_process() {
      return 0
    }

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_live_state() {
      printf '%s\n' ""
    }

    _state_file_mtime() {
      printf '%s\n' "42"
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name}" \
      $'done-idle\tcodex\tdone\tlocal_explicit\t42' \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_explicit_done_idle_case \
    "explicit done stays done when the live pane is idle"

run_explicit_done_process_exit_case() {
  local name="$1"

  (
    local tmp_dir="" session="done-idle" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tdone\n' > "${STATE_DIR}/${session}"
    _session_has_live_agent_process() {
      return 1
    }

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_live_state() {
      printf '%s\n' ""
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal "${name}" "" "${actual}"

    if [[ -e "${STATE_DIR}/${session}" ]]; then
      fail "${name} state file was not removed"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_explicit_done_process_exit_case \
    "explicit done is hidden when the live agent process exits"

run_pane_scoped_explicit_cleanup_case() {
  local name="$1"

  (
    local tmp_dir="" state_dir="" state_file="" actual=""

    tmp_dir=$(mktemp -d)
    state_dir="${tmp_dir}/state"
    mkdir -p "${tmp_dir}/bin" "${state_dir}"
    state_file="${state_dir}/stale-pane"
    printf 'codex\tdone\t%%new\n' > "${state_file}"

    cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list-sessions" && "${2:-}" == "-F" && "${3:-}" == '#{session_name}' ]]; then
  printf '%s\n' "current"
  printf '%s\n' "stale-pane"
  exit 0
fi

if [[ "${1:-}" == "list-panes" && "${2:-}" == "-a" && "${3:-}" == "-F" ]]; then
  printf '%s\t%s\t%s\t%s\n' "current" "%100" "100" "zsh"
  printf '%s\t%s\t%s\t%s\n' "stale-pane" "%old" "200" "codex"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/tmux"

    actual=$(
      PATH="${tmp_dir}/bin:${PATH}" \
      STATE_DIR="${state_dir}" \
      XDG_CACHE_HOME="${tmp_dir}/cache" \
      tmux_session_status_local_emit_records "current"
    )

    assert_equal "${name}" "" "${actual}"

    if [[ -e "${state_file}" ]]; then
      fail "${name} state file was not removed"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_pane_scoped_explicit_cleanup_case \
    "pane-scoped explicit state ignores live agents in other panes"

run_working_live_inference_case() {
  local name="$1"

  (
    local tmp_dir="" session="live-working" actual="" second_actual="" initial_mtime="" final_mtime=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}"
    printf 'codex\tworking\n' > "${STATE_DIR}/${session}"
    touch -t 202001010000 "${STATE_DIR}/${session}"
    initial_mtime=$(_state_file_mtime "${STATE_DIR}/${session}")

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_has_live_agent_process() {
      return 0
    }

    _session_live_state() {
      printf '%s\n' "working"
    }

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_matches \
      "${name}" \
      $'^live-working\tcodex\tworking\tlocal_explicit\t[0-9]+$' \
      "${actual}"
    final_mtime=$(_state_file_mtime "${STATE_DIR}/${session}")
    assert_equal \
      "${name} does not refresh durable state from live inference" \
      "${initial_mtime}" \
      "${final_mtime}"

    _session_live_state() {
      printf '%s\n' ""
    }

    second_actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal \
      "${name} expires stale working when live inference is neutral" \
      $'live-working\tcodex\tdone\tlocal_explicit\t'"${initial_mtime}" \
      "${second_actual}"

    rm -rf "${tmp_dir}"
  )
}

run_working_live_inference_case \
    "live working renders working without touching explicit state"

run_shadowed_session_case() {
  local name="$1"

  (
    local tmp_dir="" state_dir="" cache_dir="" shadow_file="" actual=""

    tmp_dir=$(mktemp -d)
    state_dir="${tmp_dir}/state"
    cache_dir="${tmp_dir}/cache"
    shadow_file="${cache_dir}/tmux-agent-bar/shadowed-sessions.txt"
    mkdir -p "${state_dir}" "$(dirname "${shadow_file}")"

    STATE_DIR="${state_dir}"
    XDG_CACHE_HOME="${cache_dir}"
    printf 'codex\tworking\n' > "$(tmux_agent_bar_state_file_path "shadowed")"
    printf 'shadowed\n' > "${shadow_file}"

    actual=$(tmux_session_status_emit_local_record "shadowed" "current")
    assert_equal "${name}" "" "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shadowed_session_case \
    "shadowed sessions are suppressed before local rendering"

run_large_snapshot_guard_case() {
  if grep -Fq '${TMUX_AGENT_BAR_LOCAL_PANES_SNAPSHOT//[[:space:]]/}' "${PROJECT_ROOT}/lib/local-collector.sh"; then
    fail "local collector should not strip all whitespace from the pane snapshot"
  fi

  if grep -Fq '${TMUX_AGENT_BAR_LOCAL_PS_SNAPSHOT//[[:space:]]/}' "${PROJECT_ROOT}/lib/local-collector.sh"; then
    fail "local collector should not strip all whitespace from the process snapshot"
  fi

  pass "local collector avoids expensive whitespace stripping on large snapshots"
}

run_large_snapshot_guard_case

run_snapshot_collection_case() {
  local name="$1"

  (
    local tmp_dir="" actual="" list_sessions_calls="" list_panes_all_calls="" list_panes_target_calls="" ps_calls=""

    tmp_dir=$(mktemp -d)
    mkdir -p "${tmp_dir}/bin"

    cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${TMUX_LOG}"

if [[ "${1:-}" == "list-sessions" && "${2:-}" == "-F" && "${3:-}" == '#{session_name}' ]]; then
  printf '%s\n' "current"
  printf '%s\n' "direct-agent"
  printf '%s\n' "wrapped agent"
  exit 0
fi

if [[ "${1:-}" == "list-panes" && "${2:-}" == "-a" && "${3:-}" == "-F" ]]; then
  printf '%s\t%s\t%s\t%s\n' "current" "%100" "100" "zsh"
  printf '%s\t%s\t%s\t%s\n' "direct-agent" "%200" "200" "codex"
  printf '%s\t%s\t%s\t%s\n' "wrapped agent" "%300" "300" "bash"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/tmux"

    cat > "${tmp_dir}/bin/ps" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${PS_LOG}"

if [[ "${1:-}" == "-eo" && "${2:-}" == "pid=,ppid=,ucomm=" ]]; then
  printf '%s\n' "200 1 codex"
  printf '%s\n' "300 1 bash"
  printf '%s\n' "301 300 codex"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/ps"

    _session_live_state() {
      printf '%s\n' "working"
    }

    actual=$(
      PATH="${tmp_dir}/bin:${PATH}" \
      TMUX_LOG="${tmp_dir}/tmux.log" \
      PS_LOG="${tmp_dir}/ps.log" \
      tmux_session_status_local_emit_records "current"
    )

    assert_equal \
      "${name}" \
      $'direct-agent\tcodex\tworking\tlocal_fallback\t0\nwrapped agent\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    list_sessions_calls=$(grep -c '^list-sessions -F ' "${tmp_dir}/tmux.log" || true)
    list_panes_all_calls=$(grep -c '^list-panes -a ' "${tmp_dir}/tmux.log" || true)
    list_panes_target_calls=$(grep -c '^list-panes -t ' "${tmp_dir}/tmux.log" || true)
    ps_calls=$(wc -l < "${tmp_dir}/ps.log" | tr -d '[:space:]')

    assert_equal "${name} uses a single list-sessions snapshot" "1" "${list_sessions_calls}"
    assert_equal "${name} uses a single list-panes snapshot" "1" "${list_panes_all_calls}"
    assert_equal "${name} avoids per-session list-panes calls" "0" "${list_panes_target_calls}"
    assert_equal "${name} uses a single ps snapshot" "1" "${ps_calls}"

    rm -rf "${tmp_dir}"
  )
}

run_snapshot_collection_case \
    "local collector reuses shared snapshots and still finds shell-wrapped agents"

run_runtime_wrapped_collection_case() {
  local name="$1"

  (
    local tmp_dir="" actual="" ps_calls=""

    tmp_dir=$(mktemp -d)
    mkdir -p "${tmp_dir}/bin"

    cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list-sessions" && "${2:-}" == "-F" && "${3:-}" == '#{session_name}' ]]; then
  printf '%s\n' "current"
  printf '%s\n' "picked-agent"
  exit 0
fi

if [[ "${1:-}" == "list-panes" && "${2:-}" == "-a" && "${3:-}" == "-F" ]]; then
  printf '%s\t%s\t%s\t%s\n' "current" "%100" "100" "vim"
  printf '%s\t%s\t%s\t%s\n' "picked-agent" "%200" "200" "bun"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/tmux"

    cat > "${tmp_dir}/bin/ps" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${PS_LOG}"

if [[ "${1:-}" == "-eo" && "${2:-}" == "pid=,ppid=,ucomm=" ]]; then
  printf '%s\n' "200 1 bun"
  printf '%s\n' "201 200 codex"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/ps"

    _session_live_state() {
      printf '%s\n' "working"
    }

    actual=$(
      PATH="${tmp_dir}/bin:${PATH}" \
      PS_LOG="${tmp_dir}/ps.log" \
      tmux_session_status_local_emit_records "current"
    )

    assert_equal \
      "${name}" \
      $'picked-agent\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    ps_calls=$(wc -l < "${tmp_dir}/ps.log" | tr -d '[:space:]')
    assert_equal "${name} uses a single ps snapshot" "1" "${ps_calls}"

    rm -rf "${tmp_dir}"
  )
}

run_runtime_wrapped_collection_case \
    "local collector finds runtime-wrapped agents"

run_suffixed_runtime_wrapped_collection_case() {
  local name="$1"

  (
    local tmp_dir="" actual=""

    tmp_dir=$(mktemp -d)
    mkdir -p "${tmp_dir}/bin"

    cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list-sessions" && "${2:-}" == "-F" && "${3:-}" == '#{session_name}' ]]; then
  printf '%s\n' "current"
  printf '%s\n' "picked-agent"
  exit 0
fi

if [[ "${1:-}" == "list-panes" && "${2:-}" == "-a" && "${3:-}" == "-F" ]]; then
  printf '%s\t%s\t%s\t%s\n' "current" "%100" "100" "vim"
  printf '%s\t%s\t%s\t%s\n' "picked-agent" "%200" "200" "bun"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/tmux"

    cat > "${tmp_dir}/bin/ps" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-eo" && "${2:-}" == "pid=,ppid=,ucomm=" ]]; then
  printf '%s\n' "200 1 bun"
  printf '%s\n' "201 200 codex-aarch64-ap"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/ps"

    _session_live_state() {
      printf '%s\n' "working"
    }

    actual=$(
      PATH="${tmp_dir}/bin:${PATH}" \
      tmux_session_status_local_emit_records "current"
    )

    assert_equal \
      "${name}" \
      $'picked-agent\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_suffixed_runtime_wrapped_collection_case \
    "local collector finds suffixed runtime-wrapped agents"

run_suffixed_direct_command_case() {
  local name="$1"

  (
    local tmp_dir="" actual="" ps_calls=""

    tmp_dir=$(mktemp -d)
    mkdir -p "${tmp_dir}/bin"

    cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list-sessions" && "${2:-}" == "-F" && "${3:-}" == '#{session_name}' ]]; then
  printf '%s\n' "current"
  printf '%s\n' "direct-agent"
  exit 0
fi

if [[ "${1:-}" == "list-panes" && "${2:-}" == "-a" && "${3:-}" == "-F" ]]; then
  printf '%s\t%s\t%s\t%s\n' "current" "%100" "100" "vim"
  printf '%s\t%s\t%s\t%s\n' "direct-agent" "%200" "200" "codex-aarch64-a"
  exit 0
fi

exit 1
EOF
    chmod +x "${tmp_dir}/bin/tmux"

    cat > "${tmp_dir}/bin/ps" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${PS_LOG}"
exit 1
EOF
    chmod +x "${tmp_dir}/bin/ps"

    _session_live_state() {
      printf '%s\n' "working"
    }

    actual=$(
      PATH="${tmp_dir}/bin:${PATH}" \
      PS_LOG="${tmp_dir}/ps.log" \
      tmux_session_status_local_emit_records "current"
    )

    assert_equal \
      "${name}" \
      $'direct-agent\tcodex\tworking\tlocal_fallback\t0' \
      "${actual}"

    if [[ -f "${tmp_dir}/ps.log" ]]; then
      ps_calls=$(wc -l < "${tmp_dir}/ps.log" | tr -d '[:space:]')
    else
      ps_calls="0"
    fi

    assert_equal "${name} skips ps when direct pane commands already identify the agent" "0" "${ps_calls}"

    rm -rf "${tmp_dir}"
  )
}

run_suffixed_direct_command_case \
    "suffixed direct commands render without a process scan"
