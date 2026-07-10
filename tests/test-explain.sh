#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar"
TEST_PREFIX="tmux-explain-test"
TMUX_AGENT_BAR_LEGACY_OVERLAY_SCRIPT="/dev/null"
TEST_HOME=$(mktemp -d)

export XDG_CONFIG_HOME="${TEST_HOME}/config"
mkdir -p "${XDG_CONFIG_HOME}"
trap 'rm -rf "${TEST_HOME}"' EXIT

# shellcheck source=/dev/null
source "${TARGET_SCRIPT}"
# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

explain_field() {
  local output="$1" key="$2" line=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "${key}="* ]]; then
      printf '%s\n' "${line#*=}"
      return 0
    fi
  done <<< "${output}"

  return 1
}

assert_explain_field() {
  local name="$1" output="$2" key="$3" expected="$4" actual=""

  actual=$(explain_field "${output}" "${key}" 2>/dev/null || true)
  assert_equal "${name} ${key}" "${expected}" "${actual}"
}

assert_explain_not_matches() {
  local name="$1" pattern="$2" output="$3"

  if [[ "${output}" =~ ${pattern} ]]; then
    fail "${name}"
  fi

  pass "${name}"
}

run_cli_dispatch_case() {
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}/state" "${tmp_dir}/config"
  printf 'custom\tdone\n' > "${tmp_dir}/state/cli-session"

  actual=$(
    STATE_DIR="${tmp_dir}/state" \
    XDG_CONFIG_HOME="${tmp_dir}/config" \
    XDG_CACHE_HOME="${tmp_dir}/cache" \
    "${TARGET_SCRIPT}" explain-cached "cli-session"
  )

  assert_explain_field "CLI explain-cached dispatches" "${actual}" "session" "cli-session"
  assert_explain_field "CLI explain-cached dispatches" "${actual}" "source" "local_explicit"
  assert_explain_field "CLI explain-cached dispatches" "${actual}" "state" "done"
  assert_explain_field "CLI explain-cached dispatches" "${actual}" "source_refresh_status" "skipped"

  rm -rf "${tmp_dir}"
}

run_cli_dispatch_case

run_local_explicit_case() {
  (
    local tmp_dir="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"
    printf 'codex\tdone\n' > "$(tmux_agent_bar_state_file_path "explicit-session")"

    _session_has_live_agent_process() {
      return 0
    }

    _session_has_known_agent_pane() {
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

    actual=$(tmux_session_status_explain_cached "explicit-session")
    assert_explain_field "local explicit explain" "${actual}" "selected_record" $'explicit-session\tcodex\tdone\tlocal_explicit\t42'
    assert_explain_field "local explicit explain" "${actual}" "source" "local_explicit"
    assert_explain_field "local explicit explain" "${actual}" "resolution" "selected"
    assert_explain_field "local explicit explain" "${actual}" "side_effects" "none"
    assert_explain_field "local explicit explain" "${actual}" "selected_reason" "local_explicit"

    rm -rf "${tmp_dir}"
  )
}

run_local_explicit_case

run_local_fallback_case() {
  (
    local tmp_dir="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"

    _session_has_known_agent_pane() {
      return 0
    }

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_live_state() {
      printf '%s\n' "waiting"
    }

    actual=$(tmux_session_status_explain_cached "fallback-session")
    assert_explain_field "local fallback explain" "${actual}" "selected_record" $'fallback-session\tcodex\tdone\tlocal_fallback\t0'
    assert_explain_field "local fallback explain" "${actual}" "source" "local_fallback"
    assert_explain_field "local fallback explain" "${actual}" "live_agent" "codex"
    assert_explain_field "local fallback explain" "${actual}" "side_effects" "none"
    assert_explain_field "local fallback explain" "${actual}" "selected_reason" "live_fallback"

    rm -rf "${tmp_dir}"
  )
}

run_local_fallback_case

run_stale_working_case() {
  (
    local tmp_dir="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"
    printf 'codex\tworking\n' > "$(tmux_agent_bar_state_file_path "stale-session")"

    _session_has_live_agent_process() {
      return 0
    }

    _session_has_known_agent_pane() {
      return 0
    }

    _session_agent_command() {
      printf '%s\n' "codex"
    }

    _session_live_state() {
      printf '%s\n' ""
    }

    _state_file_has_stale_working() {
      return 0
    }

    _state_file_mtime() {
      printf '%s\n' "42"
    }

    actual=$(tmux_session_status_explain_cached "stale-session")
    assert_explain_field "stale working explain" "${actual}" "state" "done"
    assert_explain_field "stale working explain" "${actual}" "stale_working" "true"
    assert_explain_field "stale working explain" "${actual}" "selected_record" $'stale-session\tcodex\tdone\tlocal_explicit\t42'

    rm -rf "${tmp_dir}"
  )
}

run_stale_working_case

run_hidden_no_agent_case() {
  (
    local tmp_dir="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"

    _session_has_known_agent_pane() {
      return 1
    }

    _session_tail_inferred_agent_state() {
      return 1
    }

    _session_tail_identified_agent() {
      return 1
    }

    actual=$(tmux_session_status_explain_cached "hidden-session")
    assert_explain_field "hidden no-agent explain" "${actual}" "selected_record" ""
    assert_explain_field "hidden no-agent explain" "${actual}" "resolution" "hidden"
    assert_explain_field "hidden no-agent explain" "${actual}" "side_effects" "none"
    assert_explain_field "hidden no-agent explain" "${actual}" "selected_reason" "no_local_evidence"

    rm -rf "${tmp_dir}"
  )
}

run_hidden_no_agent_case

run_shadowed_source_case() {
  (
    local tmp_dir="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}" "$(tmux_agent_bar_cache_dir)"
    printf 'codex\tdone\n' > "$(tmux_agent_bar_state_file_path "shadowed-session")"
    printf 'shadowed-session\n' > "$(tmux_agent_bar_shadowed_sessions_file)"
    printf '%s\n' $'shadowed-session\tcodex\tworking\tgeneric_cache\t77' > "$(tmux_agent_bar_remote_rows_file)"

    actual=$(tmux_session_status_explain_cached "shadowed-session")
    assert_explain_field "shadowed source explain" "${actual}" "selected_record" $'shadowed-session\tcodex\tworking\tgeneric_cache\t77'
    assert_explain_field "shadowed source explain" "${actual}" "source" "generic_cache"
    assert_explain_field "shadowed source explain" "${actual}" "shadowed" "true"
    assert_explain_field "shadowed source explain" "${actual}" "selected_reason" "source_record"
    assert_explain_field "shadowed source explain" "${actual}" "source_freshness" "timestamped"
    assert_explain_not_matches "explain output stays transport-agnostic" "ssh|host|launcher" "${actual}"

    rm -rf "${tmp_dir}"
  )
}

run_shadowed_source_case

run_cached_refresh_case() {
  (
    local tmp_dir="" marker="" actual=""

    tmp_dir=$(mktemp -d)
    marker="${tmp_dir}/refresh-called"
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"

    _session_has_known_agent_pane() {
      return 1
    }

    _session_tail_inferred_agent_state() {
      return 1
    }

    _session_tail_identified_agent() {
      return 1
    }

    tmux_agent_bar_refresh_probe_emit() {
      printf '%s\n' $'refresh-target\tcodex\twaiting\tgeneric_source\t20'
    }

    tmux_agent_bar_refresh_probe_refresh() {
      : > "${marker}"
    }

    tmux_agent_register_source "refresh-probe" "tmux_agent_bar_refresh_probe_emit" "tmux_agent_bar_refresh_probe_refresh"

    actual=$(tmux_session_status_explain_cached "refresh-target")
    assert_explain_field "cached explain skips refresh" "${actual}" "source" "generic_source"
    assert_explain_field "cached explain normalizes waiting source rows" "${actual}" "state" "done"
    assert_explain_field "cached explain skips refresh" "${actual}" "source_refresh_status" "skipped"

    if [[ -e "${marker}" ]]; then
      fail "cached explain ran source refresh hook"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_cached_refresh_case

run_no_delete_side_effect_case() {
  (
    local tmp_dir="" state_file="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"
    state_file=$(tmux_agent_bar_state_file_path "done-session")
    printf 'codex\tdone\n' > "${state_file}"

    _session_has_live_agent_process() {
      return 1
    }

    actual=$(tmux_session_status_explain_cached "done-session")
    assert_explain_field "explain predicts stale explicit cleanup" "${actual}" "side_effects" "delete_explicit_state"

    if [[ ! -f "${state_file}" ]]; then
      fail "explain deleted explicit state"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_no_delete_side_effect_case

run_no_write_observed_side_effect_case() {
  (
    local tmp_dir="" observed_file="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"
    observed_file="$(_session_observed_agent_file "tail-session")"

    _session_has_known_agent_pane() {
      return 1
    }

    _session_tail_inferred_agent_state() {
      printf '%s\t%s\n' "codex" "waiting"
    }

    actual=$(tmux_session_status_explain_cached "tail-session")
    assert_explain_field "explain predicts observed write" "${actual}" "side_effects" "write_observed_agent"

    if [[ -e "${observed_file}" ]]; then
      fail "explain wrote observed state"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_no_write_observed_side_effect_case

run_no_clear_observed_side_effect_case() {
  (
    local tmp_dir="" observed_file="" actual=""

    tmp_dir=$(mktemp -d)
    STATE_DIR="${tmp_dir}/state"
    XDG_CACHE_HOME="${tmp_dir}/cache"
    export STATE_DIR XDG_CACHE_HOME
    mkdir -p "${STATE_DIR}"
    _session_mark_observed_agent "observed-session" "codex"
    observed_file="$(_session_observed_agent_file "observed-session")"

    _session_has_known_agent_pane() {
      return 1
    }

    _session_tail_inferred_agent_state() {
      return 1
    }

    _session_tail_identified_agent() {
      printf '%s\n' "codex"
    }

    actual=$(tmux_session_status_explain_cached "observed-session")
    assert_explain_field "explain predicts observed clear" "${actual}" "side_effects" "clear_observed_agent"

    if [[ ! -f "${observed_file}" ]]; then
      fail "explain cleared observed state"
    fi

    rm -rf "${tmp_dir}"
  )
}

run_no_clear_observed_side_effect_case
