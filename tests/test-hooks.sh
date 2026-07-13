#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
HOOK_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar-hook"
CODEX_HOOK_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar-codex-hook"
TEST_PREFIX="tmux-hook-test"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

make_tmux_stub_dir() {
  local tmp_dir="$1"

  mkdir -p "${tmp_dir}/bin"

  cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "display-message" && "${2:-}" == "-p" ]]; then
  case "${*: -1}" in
    '#{session_name}')
      printf '%s\n' "dev/docs"
      exit 0
      ;;
    '#{pane_id}')
      printf '%s\n' "%42"
      exit 0
      ;;
  esac
fi

exit 1
EOF
  chmod +x "${tmp_dir}/bin/tmux"
}

run_hook_state_dir_case() {
  local tmp_dir="" state_file="" actual=""

  tmp_dir=$(mktemp -d)
  make_tmux_stub_dir "${tmp_dir}"
  state_file="${tmp_dir}/state/dev%2Fdocs"

  actual=$(
    PATH="${tmp_dir}/bin:${PATH}" \
    STATE_DIR="${tmp_dir}/state" \
    "${HOOK_SCRIPT}" working codex
  )

  assert_equal "hook writes explicit state into the overridden state directory" "" "${actual}"

  if [[ ! -f "${state_file}" ]]; then
    fail "hook did not create the explicit state file in STATE_DIR"
  fi

  assert_equal "hook encodes session names with slashes" $'codex\tworking\t%42' "$(<"${state_file}")"
  rm -rf "${tmp_dir}"
}

run_hook_no_stdout_bell_case() {
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)
  make_tmux_stub_dir "${tmp_dir}"

  actual=$(
    PATH="${tmp_dir}/bin:${PATH}" \
    STATE_DIR="${tmp_dir}/state" \
    "${HOOK_SCRIPT}" waiting codex
  )

  assert_equal "hook does not fall back to writing the bell to stdout" "" "${actual}"
  rm -rf "${tmp_dir}"
}

run_codex_hook_mapping_case() {
  local name="$1" event="$2" expected_state="$3"
  local tmp_dir="" state_file="" actual=""

  tmp_dir=$(mktemp -d)
  make_tmux_stub_dir "${tmp_dir}"
  state_file="${tmp_dir}/state/dev%2Fdocs"

  actual=$(
    printf '%s\n' '{"hook_event":"'"${event}"'"}' |
      PATH="${tmp_dir}/bin:${PATH}" \
      STATE_DIR="${tmp_dir}/state" \
      "${CODEX_HOOK_SCRIPT}" "${event}"
  )

  assert_equal "${name} stays quiet on stdout" "" "${actual}"

  if [[ ! -f "${state_file}" ]]; then
    fail "${name} did not create a Codex state file"
  fi

  assert_equal "${name}" $'codex\t'"${expected_state}"$'\t%42' "$(<"${state_file}")"
  rm -rf "${tmp_dir}"
}

run_codex_hook_unknown_event_case() {
  local tmp_dir="" state_dir="" actual=""

  tmp_dir=$(mktemp -d)
  make_tmux_stub_dir "${tmp_dir}"
  state_dir="${tmp_dir}/state"

  actual=$(
    printf '%s\n' '{"hook_event":"UnknownEvent"}' |
      PATH="${tmp_dir}/bin:${PATH}" \
      STATE_DIR="${state_dir}" \
      "${CODEX_HOOK_SCRIPT}" UnknownEvent
  )

  assert_equal "codex hook ignores unknown events" "" "${actual}"

  if [[ -d "${state_dir}" ]] && [[ -n "$(find "${state_dir}" -type f -print -quit)" ]]; then
    fail "codex hook wrote state for an unknown event"
  fi

  rm -rf "${tmp_dir}"
}

run_codex_hook_ignored_event_case() {
  local event="$1" tmp_dir="" state_dir="" actual=""

  tmp_dir=$(mktemp -d)
  make_tmux_stub_dir "${tmp_dir}"
  state_dir="${tmp_dir}/state"

  actual=$(
    printf '%s\n' '{"hook_event":"'"${event}"'"}' |
      PATH="${tmp_dir}/bin:${PATH}" \
      STATE_DIR="${state_dir}" \
      "${CODEX_HOOK_SCRIPT}" "${event}"
  )

  assert_equal "codex hook ignores ${event}" "" "${actual}"

  if [[ -d "${state_dir}" ]] && [[ -n "$(find "${state_dir}" -type f -print -quit)" ]]; then
    fail "codex hook wrote state for ignored event ${event}"
  fi

  rm -rf "${tmp_dir}"
}

run_hook_state_dir_case
run_hook_no_stdout_bell_case
run_codex_hook_mapping_case \
  "codex hook maps PermissionRequest to waiting" \
  "PermissionRequest" \
  "waiting"
run_codex_hook_mapping_case \
  "codex hook maps UserPromptSubmit to working" \
  "UserPromptSubmit" \
  "working"
run_codex_hook_mapping_case \
  "codex hook maps PreToolUse to working" \
  "PreToolUse" \
  "working"
run_codex_hook_mapping_case \
  "codex hook maps Stop to done" \
  "Stop" \
  "done"
run_codex_hook_ignored_event_case "PostToolUse"
run_codex_hook_unknown_event_case
