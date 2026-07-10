#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-state-contract-test"
TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT="/dev/null"
TEST_HOME=$(mktemp -d)

export XDG_CONFIG_HOME="${TEST_HOME}/config"
mkdir -p "${XDG_CONFIG_HOME}"
trap 'rm -rf "${TEST_HOME}"' EXIT

# shellcheck source=/dev/null
source "${TARGET_SCRIPT}"
# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

_contract_enabled() {
  [[ "${1:-0}" == "1" ]]
}

_session_has_live_agent_process() {
  _contract_enabled "${CONTRACT_LIVE_PROCESS:-0}"
}

_session_has_known_agent_pane() {
  _contract_enabled "${CONTRACT_HAS_KNOWN_AGENT_PANE:-0}"
}

_session_agent_command() {
  [[ -n "${CONTRACT_LIVE_AGENT:-}" ]] || return 1
  printf '%s\n' "${CONTRACT_LIVE_AGENT}"
}

_session_live_state() {
  printf '%s\n' "${CONTRACT_LIVE_STATE:-}"
}

_state_file_has_stale_working() {
  _contract_enabled "${CONTRACT_STALE_WORKING:-0}"
}

_state_file_mtime() {
  printf '%s\n' "42"
}

_session_tail_inferred_agent_state() {
  [[ -n "${CONTRACT_TAIL_AGENT:-}" ]] || return 1
  [[ -n "${CONTRACT_TAIL_STATE:-}" ]] || return 1
  printf '%s\t%s\n' "${CONTRACT_TAIL_AGENT}" "${CONTRACT_TAIL_STATE}"
}

_session_tail_identifies_agent() {
  local _session="$1" agent="$2"

  [[ -n "${CONTRACT_TAIL_IDENTIFIES_AGENT:-}" ]] || return 1
  [[ "${CONTRACT_TAIL_IDENTIFIES_AGENT}" == "${agent}" ]]
}

assert_contract_side_effect() {
  local name="$1" effect="$2" state_file="$3" observed_file="$4" expected_agent="$5" actual_agent=""

  case "${effect}" in
    none)
      return 0
      ;;
    delete_state)
      if [[ -e "${state_file}" ]]; then
        fail "${name} did not delete explicit state"
      fi
      ;;
    keep_state)
      if [[ ! -f "${state_file}" ]]; then
        fail "${name} removed explicit state"
      fi
      ;;
    write_observed)
      if [[ ! -f "${observed_file}" ]]; then
        fail "${name} did not write observed fallback state"
      fi
      IFS= read -r actual_agent < "${observed_file}" || true
      assert_equal "${name} observed fallback agent" "${expected_agent}" "${actual_agent}"
      ;;
    clear_observed)
      if [[ -e "${observed_file}" ]]; then
        fail "${name} did not clear observed fallback state"
      fi
      ;;
    *)
      fail "${name} has unknown side effect expectation: ${effect}"
      ;;
  esac
}

run_local_contract_case() {
  local name="$1" explicit_agent="$2" explicit_state="$3" live_process="$4" has_known_agent_pane="$5"
  local live_agent="$6" live_state="$7" stale_working="$8" tail_agent="$9" tail_state="${10}"
  local tail_identifies_agent="${11}" observed_agent="${12}" shadowed="${13}" expected="${14}" expected_effect="${15}"

  (
    local tmp_dir="" session="contract-session" state_file="" observed_file="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}" "$(tmux_agent_bar_cache_dir)"

    TMUX_AGENT_BAR_LOCAL_SNAPSHOTS_READY=0
    CONTRACT_LIVE_PROCESS="${live_process}"
    CONTRACT_HAS_KNOWN_AGENT_PANE="${has_known_agent_pane}"
    CONTRACT_LIVE_AGENT="${live_agent}"
    CONTRACT_LIVE_STATE="${live_state}"
    CONTRACT_STALE_WORKING="${stale_working}"
    CONTRACT_TAIL_AGENT="${tail_agent}"
    CONTRACT_TAIL_STATE="${tail_state}"
    CONTRACT_TAIL_IDENTIFIES_AGENT="${tail_identifies_agent}"

    state_file=$(tmux_agent_bar_state_file_path "${session}")
    observed_file="$(_session_observed_agent_file "${session}")"

    if [[ -n "${explicit_agent}" || -n "${explicit_state}" ]]; then
      printf '%s\t%s\n' "${explicit_agent}" "${explicit_state}" > "${state_file}"
    fi

    if [[ -n "${observed_agent}" ]]; then
      _session_mark_observed_agent "${session}" "${observed_agent}"
    fi

    if [[ "${shadowed}" == "1" ]]; then
      printf '%s\n' "${session}" > "$(tmux_agent_bar_shadowed_sessions_file)"
    fi

    actual=$(tmux_session_status_emit_local_record "${session}" "current")
    assert_equal "${name}" "${expected}" "${actual}"
    assert_contract_side_effect "${name}" "${expected_effect}" "${state_file}" "${observed_file}" "${tail_agent}"

    rm -rf "${tmp_dir}"
  )
}

run_local_contract_case \
  "explicit done without a live same-agent process hides and deletes state" \
  "codex" \
  "done" \
  "0" \
  "0" \
  "" \
  "" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  "" \
  "delete_state"

run_local_contract_case \
  "explicit done with same-agent tail identity but no live process hides and deletes state" \
  "codex" \
  "done" \
  "0" \
  "0" \
  "" \
  "" \
  "0" \
  "" \
  "" \
  "codex" \
  "" \
  "0" \
  "" \
  "delete_state"

run_local_contract_case \
  "explicit done with visible same-agent working renders working" \
  "codex" \
  "done" \
  "1" \
  "1" \
  "codex" \
  "working" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  $'contract-session\tcodex\tworking\tlocal_explicit\t42' \
  "keep_state"

run_local_contract_case \
  "explicit working with visible waiting renders done" \
  "codex" \
  "working" \
  "1" \
  "1" \
  "codex" \
  "waiting" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  $'contract-session\tcodex\tdone\tlocal_explicit\t42' \
  "keep_state"

run_local_contract_case \
  "explicit done with visible waiting renders done" \
  "codex" \
  "done" \
  "1" \
  "1" \
  "codex" \
  "waiting" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  $'contract-session\tcodex\tdone\tlocal_explicit\t42' \
  "keep_state"

run_local_contract_case \
  "stale explicit working with neutral live evidence renders done without deleting state" \
  "codex" \
  "working" \
  "1" \
  "1" \
  "codex" \
  "" \
  "1" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  $'contract-session\tcodex\tdone\tlocal_explicit\t42' \
  "keep_state"

run_local_contract_case \
  "explicit row with a different live registered agent resolves to done" \
  "codex" \
  "working" \
  "1" \
  "1" \
  "claude" \
  "" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  $'contract-session\tclaude\tdone\tlocal_explicit\t42' \
  "keep_state"

run_local_contract_case \
  "direct live agent pane with neutral evidence stays hidden without explicit state" \
  "" \
  "" \
  "1" \
  "1" \
  "codex" \
  "" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  "" \
  "none"

run_local_contract_case \
  "direct live agent pane with waiting evidence emits done fallback" \
  "" \
  "" \
  "1" \
  "1" \
  "codex" \
  "waiting" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  $'contract-session\tcodex\tdone\tlocal_fallback\t0' \
  "none"

run_local_contract_case \
  "direct live agent pane with working evidence emits local fallback" \
  "" \
  "" \
  "1" \
  "1" \
  "codex" \
  "working" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  $'contract-session\tcodex\tworking\tlocal_fallback\t0' \
  "none"

run_local_contract_case \
  "shell-wrapped identified active tail emits local fallback and writes observed state" \
  "" \
  "" \
  "0" \
  "0" \
  "" \
  "" \
  "0" \
  "codex" \
  "working" \
  "" \
  "" \
  "0" \
  $'contract-session\tcodex\tworking\tlocal_fallback\t0' \
  "write_observed"

run_local_contract_case \
  "shell-wrapped unidentified active-looking tail stays hidden" \
  "" \
  "" \
  "0" \
  "0" \
  "" \
  "" \
  "0" \
  "" \
  "working" \
  "" \
  "" \
  "0" \
  "" \
  "none"

run_local_contract_case \
  "shell-wrapped connector boundary above stale transcript stays hidden" \
  "" \
  "" \
  "0" \
  "0" \
  "" \
  "" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "0" \
  "" \
  "none"

run_local_contract_case \
  "observed shell-wrapped session with same-agent neutral tail clears observed state" \
  "" \
  "" \
  "0" \
  "0" \
  "" \
  "" \
  "0" \
  "" \
  "" \
  "codex" \
  "codex" \
  "0" \
  "" \
  "clear_observed"

run_local_contract_case \
  "shadowed explicit local session hides before stale cleanup" \
  "codex" \
  "done" \
  "0" \
  "0" \
  "" \
  "" \
  "0" \
  "" \
  "" \
  "" \
  "" \
  "1" \
  "" \
  "keep_state"

run_source_precedence_contract_case() {
  local actual=""

  (
    tmux_agent_bar_emit_registered_records() {
      printf '%s\n' $'source-owned\tcodex\tworking\tlocal_explicit\t10'
      printf '%s\n' $'source-owned\tcodex\tdone\tgeneric_source\t20'
      printf '%s\n' $'source-only\tcodex\twaiting\tgeneric_source\t30'
    }

    actual=$(tmux_agent_bar_emit_prioritized_records "current")
    assert_equal \
      "duplicate local and source-provided rows preserve first-row precedence" \
      $'source-owned\tcodex\tworking\tlocal_explicit\t10\nsource-only\tcodex\tdone\tgeneric_source\t30' \
      "${actual}"
  )
}

run_source_precedence_contract_case

run_cached_contract_case() {
  local tmp_dir="" state_marker="" render_marker="" actual=""

  tmp_dir=$(mktemp -d)
  state_marker="${tmp_dir}/current-state-refresh-called"
  render_marker="${tmp_dir}/render-refresh-called"

  (
    tmux_session_status_current_session() {
      printf '%s\n' "current"
    }

    tmux_agent_bar_maybe_refresh_sources() {
      : > "${state_marker}"
    }

    tmux_agent_bar_emit_registered_records() {
      printf '%s\n' $'current\tcodex\tworking\tlocal_explicit\t10'
      printf '%s\n' $'other\tcodex\tdone\tlocal_explicit\t20'
    }

    actual=$(tmux_session_status_current_state_cached)
    assert_equal "cached current-state path does not run source refresh hooks" "working" "${actual}"
  )

  if [[ -e "${state_marker}" ]]; then
    fail "cached current-state path refreshed sources"
  fi

  (
    tmux_session_status_current_session() {
      printf '%s\n' "current"
    }

    tmux_agent_bar_maybe_refresh_sources() {
      : > "${render_marker}"
    }

    tmux_agent_bar_emit_registered_records() {
      printf '%s\n' $'current\tcodex\tworking\tlocal_explicit\t10'
      printf '%s\n' $'other\tcodex\tdone\tlocal_explicit\t20'
    }

    actual=$(tmux_session_status_main_cached)
    if [[ -z "${actual}" ]]; then
      fail "cached render path did not render source rows"
    fi
    pass "cached render path does not run source refresh hooks"
  )

  if [[ -e "${render_marker}" ]]; then
    fail "cached render path refreshed sources"
  fi

  rm -rf "${tmp_dir}"
}

run_cached_contract_case

run_generic_adapter_boundary_contract_case() {
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}/bin" "${tmp_dir}/state" "${tmp_dir}/cache/tmux-agent-bar"

  cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list-sessions" && "${2:-}" == "-F" && "${3:-}" == '#{session_name}' ]]; then
  printf '%s\n' "current"
  printf '%s\n' "adapter-owned"
  exit 0
fi

if [[ "${1:-}" == "list-panes" && "${2:-}" == "-a" && "${3:-}" == "-F" ]]; then
  printf '%s\t%s\t%s\n' "current" "100" "zsh"
  printf '%s\t%s\t%s\n' "adapter-owned" "200" "codex"
  exit 0
fi

printf 'unexpected tmux probe: %s\n' "$*" >&2
exit 1
EOF
  chmod +x "${tmp_dir}/bin/tmux"

  printf 'codex\tdone\n' > "${tmp_dir}/state/adapter-owned"
  printf 'adapter-owned\n' > "${tmp_dir}/cache/tmux-agent-bar/shadowed-sessions.txt"
  printf '%s\n' $'adapter-owned\tcodex\tworking\tgeneric_cache\t77' > "${tmp_dir}/cache/tmux-agent-bar/remote-rows.tsv"

  actual=$(
    PATH="${tmp_dir}/bin:${PATH}" \
    STATE_DIR="${tmp_dir}/state" \
    XDG_CACHE_HOME="${tmp_dir}/cache" \
    tmux_agent_bar_emit_prioritized_records "current" "0" ""
  )

  assert_equal \
    "generic adapter rows and shadowing artifacts are enough for core selection" \
    $'adapter-owned\tcodex\tworking\tgeneric_cache\t77' \
    "${actual}"

  rm -rf "${tmp_dir}"
}

run_generic_adapter_boundary_contract_case
