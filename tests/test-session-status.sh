#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-status-test"
TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT="/dev/null"

# shellcheck source=/dev/null
source "${TARGET_SCRIPT}"
# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

run_case() {
    local name="$1" explicit_state="$2" live_state="$3" has_known_agent_pane="$4" stale_working="$5" agent_mismatch="$6" expected="$7" actual=""

    actual=$(tmux_session_status_resolve_state "${explicit_state}" "${live_state}" "${has_known_agent_pane}" "${stale_working}" "${agent_mismatch}")
    assert_equal "${name}" "${expected}" "${actual}"
}

run_case \
    "explicit done stays done when the live parser sees no prompt state" \
    "done" \
    "" \
    "1" \
    "0" \
    "0" \
    "done"

run_case \
    "explicit done upgrades to waiting on a real waiting prompt" \
    "done" \
    "waiting" \
    "1" \
    "0" \
    "0" \
    "waiting"

run_case \
    "explicit working upgrades to waiting on a real waiting prompt" \
    "working" \
    "waiting" \
    "1" \
    "0" \
    "0" \
    "waiting"

run_case \
  "explicit done recovers to working on a visible live working footer" \
  "done" \
  "working" \
  "1" \
  "0" \
  "0" \
  "working"

run_case \
    "explicit working ignores a non-waiting live done signal" \
    "working" \
    "done" \
    "1" \
    "0" \
    "0" \
    "working"

run_case \
    "explicit waiting ignores a non-waiting live done signal" \
    "waiting" \
    "done" \
    "1" \
    "0" \
    "0" \
    "waiting"

run_case \
    "stale working hook falls back to done without a live signal" \
    "working" \
    "" \
    "1" \
    "1" \
    "0" \
    "done"

run_case \
    "agent mismatch forces done before render" \
    "working" \
    "" \
    "1" \
    "0" \
    "1" \
    "done"

run_case \
    "sessions without explicit state still show waiting when the prompt needs input" \
    "" \
    "waiting" \
    "1" \
    "0" \
    "0" \
    "waiting"

run_case \
    "sessions without explicit state stay hidden when the live parser is neutral" \
    "" \
    "" \
    "1" \
    "0" \
    "0" \
    ""

run_case \
    "sessions without agent panes stay hidden" \
    "" \
    "" \
    "0" \
    "0" \
    "0" \
    ""

run_render_case() {
  local name="$1" available_width="$2" rows="$3" expected="$4" scan_direction="${5:-}" actual=""

  actual=$(
    AVAILABLE_WIDTH="${available_width}" \
    ROWS="${rows}" \
    TMUX_AGENT_BAR_SCAN_DIRECTION="${scan_direction}" \
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"

tmux_session_status_right_available_width() {
  printf '%s\n' "${AVAILABLE_WIDTH}"
}

printf '%b' "${ROWS}" | tmux_session_status_render_records "current"
EOF
  )

  assert_equal "${name}" "${expected}" "${actual}"
}

run_render_case \
    "renderer stays empty for empty input under nounset" \
    "80" \
    "" \
    ""

run_render_case \
    "renderer orders compact status for right-to-left scanning" \
    "80" \
    $'waiting-old\tcodex\twaiting\tlocal_explicit\t10\nwaiting-new\tcodex\twaiting\tlocal_explicit\t40\nworking-a\tcodex\tworking\tlocal_explicit\t30\ndone-early\tcodex\tdone\tlocal_explicit\t20\ndone-late\tcodex\tdone\tlocal_explicit\t50\n' \
    $'#[fg=#82aaff] working-a#[fg=default]  #[fg=#21c7a8] done-late#[fg=default]  #[fg=#21c7a8] done-early#[fg=default]  #[fg=#e3d18a] waiting-new#[fg=default]  #[fg=#e3d18a] waiting-old#[fg=default] '

run_render_case \
    "renderer can optimize compact status for left-to-right scanning" \
    "80" \
    $'waiting-old\tcodex\twaiting\tlocal_explicit\t10\nwaiting-new\tcodex\twaiting\tlocal_explicit\t40\nworking-a\tcodex\tworking\tlocal_explicit\t30\ndone-early\tcodex\tdone\tlocal_explicit\t20\n' \
    $'#[fg=#e3d18a] waiting-old#[fg=default]  #[fg=#e3d18a] waiting-new#[fg=default]  #[fg=#21c7a8] done-early#[fg=default]  #[fg=#82aaff] working-a#[fg=default] ' \
    "left-to-right"

run_render_case \
    "renderer moves recovered working rows behind done and waiting rows" \
    "80" \
    $'waiting-a\tcodex\twaiting\tlocal_explicit\t40\nrecovered-a\tcodex\tworking\tlocal_explicit\t50\ndone-a\tcodex\tdone\tlocal_explicit\t30\n' \
    $'#[fg=#82aaff] recovered-a#[fg=default]  #[fg=#21c7a8] done-a#[fg=default]  #[fg=#e3d18a] waiting-a#[fg=default] '

run_render_case \
    "renderer uses the full available width before showing an ellipsis" \
    "19" \
    $'beta\tcodex\twaiting\tlocal_explicit\t20\nalpha\tcodex\tworking\tlocal_explicit\t10\ngamma\tcodex\tdone\tlocal_explicit\t30\n' \
    $'#[fg=#7f8c98]…#[fg=default]  #[fg=#82aaff] alpha#[fg=default]  #[fg=#e3d18a] beta#[fg=default] '

run_render_case \
    "renderer preserves waiting at the right edge when it needs room for the ellipsis" \
    "17" \
    $'beta\tcodex\twaiting\tlocal_explicit\t20\nalpha\tcodex\tworking\tlocal_explicit\t10\ngamma\tcodex\tdone\tlocal_explicit\t30\n' \
    $'#[fg=#7f8c98]…#[fg=default]  #[fg=#e3d18a] beta#[fg=default] '

run_prioritized_records_case() {
  local actual=""

  actual=$(
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"

tmux_agent_bar_emit_registered_records() {
  local current="$1"

  if [[ "${current}" != "current" ]]; then
    printf 'unexpected current session: %s\n' "${current}" >&2
    exit 1
  fi

  printf '%s\n' $'done-a\tcodex\tdone\tlocal_explicit\t10'
  printf '%s\n' $'working-a\tcodex\tworking\tlocal_explicit\t20'
  printf '%s\n' $'waiting-a\tcodex\twaiting\tlocal_explicit\t30'
  printf '%s\n' $'working-a\tcodex\twaiting\tremote_cache\t40'
  printf '%s\n' $'other-a\tcodex\tpaused\tcustom\t50'
  printf '%s\n' $'current\tcodex\twaiting\tlocal_explicit\t60'
}

tmux_agent_bar_emit_prioritized_records "current"
EOF
  )

  assert_equal \
    "shared record helper keeps first-row precedence and prioritizes states" \
    $'waiting-a\tcodex\twaiting\tlocal_explicit\t30\nworking-a\tcodex\tworking\tlocal_explicit\t20\ndone-a\tcodex\tdone\tlocal_explicit\t10\nother-a\tcodex\tpaused\tcustom\t50' \
    "${actual}"
}

run_prioritized_records_case

run_scan_ordered_records_case() {
  local actual=""

  actual=$(
    TARGET_SCRIPT="${TARGET_SCRIPT}" \
    "${BASH}" <<'EOF'
set -euo pipefail

source "${TARGET_SCRIPT}"

cat <<'ROWS' | tmux_agent_bar_emit_scan_ordered_records
working-z	codex	working	local_explicit	10
working-a	codex	working	local_explicit	999
waiting-b	codex	waiting	local_explicit	40
waiting-a	codex	waiting	local_explicit	40
done-new	codex	done	local_explicit	80
done-old	codex	done	local_explicit	20
ROWS
EOF
  )

  assert_equal \
    "scan ordering is stable within tiers without using working mtimes" \
    $'waiting-a\tcodex\twaiting\tlocal_explicit\t40\nwaiting-b\tcodex\twaiting\tlocal_explicit\t40\ndone-old\tcodex\tdone\tlocal_explicit\t20\ndone-new\tcodex\tdone\tlocal_explicit\t80\nworking-a\tcodex\tworking\tlocal_explicit\t999\nworking-z\tcodex\tworking\tlocal_explicit\t10' \
    "${actual}"
}

run_scan_ordered_records_case

run_current_record_uses_unfiltered_records_case() {
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)

  actual=$(
    CURRENT_SESSION="current" \
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
  local current="$1"

  if [[ -n "${current}" ]]; then
    printf 'current record unexpectedly filtered sources with: %s\n' "${current}" >&2
    exit 1
  fi

  printf '%s\n' $'other\tcodex\twaiting\tlocal_explicit\t10'
  printf '%s\n' $'current\tcodex\tdone\tlocal_explicit\t20'
  printf '%s\n' $'current\tcodex\twaiting\tremote_cache\t30'
}

tmux_session_status_current_state
EOF
  )

  assert_equal \
    "current state uses the first unfiltered matching record" \
    "done" \
    "${actual}"

  rm -rf "${tmp_dir}"
}

run_current_record_uses_unfiltered_records_case

run_available_width_does_not_evaluate_status_left_case() {
  local actual=""

  actual=$(
    tmux() {
      if [[ "${1:-}" == "display-message" ]]; then
        local format="${3:-}"

        if [[ "${format}" == '#{w:#{E:status-left}}' ]]; then
          printf '%s\n' "status-left was evaluated"
          exit 1
        fi

        if [[ "${format}" == '#{client_width}' ]]; then
          printf '%s\n' "120"
          return 0
        fi

        if [[ "${format}" == '#{w:#{E:window-status-current-format}}' ]]; then
          printf '%s\n' "20"
          return 0
        fi

        printf '%s\n' "unexpected format: ${format}" >&2
        exit 1
      fi

      if [[ "${1:-}" == "show-options" ]]; then
        if [[ "${3:-}" == "status-left-length" ]]; then
          printf '%s\n' "30"
          return 0
        fi

        if [[ "${3:-}" == "status-right-length" ]]; then
          printf '%s\n' "1000"
          return 0
        fi

        printf '%s\n' "unexpected option: ${3:-}" >&2
        exit 1
      fi

      printf '%s\n' "unexpected tmux call: $*" >&2
      exit 1
    }

    TMUX_AGENT_BAR_PROBE_TMUX_WIDTH=1 tmux_session_status_right_available_width
  )

  assert_equal "available width calculation does not evaluate status-left" "70" "${actual}"
}

run_available_width_does_not_evaluate_status_left_case

run_available_width_probe_is_opt_in_case() {
  local actual=""

  actual=$(
    tmux() {
      printf '%s\n' "tmux should not be called" >&2
      exit 1
    }

    tmux_session_status_right_available_width || true
  )

  assert_equal "available width calculation skips tmux probes by default" "" "${actual}"
}

run_available_width_probe_is_opt_in_case
