#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TARGET_SCRIPT="${PROJECT_ROOT}/bin/tmux-agent-bar-picker"
TEST_PREFIX="tmux-picker-test"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/tests/testlib.sh"

run_missing_fzf_case() {
  local tmp_dir="" actual="" exit_code=0

  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}/bin"

  cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "display-message" ]]; then
  printf '%s\n' "current"
  exit 0
fi

exit 1
EOF
  chmod +x "${tmp_dir}/bin/tmux"

  actual=$(
    PATH="${tmp_dir}/bin:/usr/bin:/bin" \
    TMUX="/tmp/tmux-test" \
    "${BASH}" "${TARGET_SCRIPT}" 2>&1
  ) || exit_code=$?

  assert_equal "picker exits non-zero when fzf is missing" "1" "${exit_code}"
  assert_equal "picker reports missing fzf clearly" "tmux-agent-bar-picker: fzf is required" "${actual}"

  rm -rf "${tmp_dir}"
}

run_missing_fzf_case

run_outside_tmux_case() {
  local actual="" exit_code=0

  actual=$(
    PATH="${PATH}" \
    TMUX="" \
    "${BASH}" "${TARGET_SCRIPT}" 2>&1
  ) || exit_code=$?

  assert_equal "picker exits non-zero outside tmux" "1" "${exit_code}"
  assert_equal "picker reports outside tmux clearly" "tmux-agent-bar-picker: must be run inside tmux" "${actual}"
}

run_outside_tmux_case

run_switch_selection_case() {
  local tmp_dir="" actual="" switched_target="" fzf_input="" fzf_args=""

  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}/bin" "${tmp_dir}/config/tmux-agent-bar/sources"

  cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${TMUX_CALLS}"

if [[ "${1:-}" == "display-message" ]]; then
  printf '%s\n' "current"
  exit 0
fi

if [[ "${1:-}" == "switch-client" && "${2:-}" == "-t" ]]; then
  printf '%s\n' "${3:-}" > "${SWITCHED_TARGET}"
  exit 0
fi

exit 1
EOF
  chmod +x "${tmp_dir}/bin/tmux"

  cat > "${tmp_dir}/bin/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "${FZF_ARGS}"
cat > "${FZF_INPUT}"
head -n 1 "${FZF_INPUT}"
EOF
  chmod +x "${tmp_dir}/bin/fzf"

  cat > "${tmp_dir}/config/tmux-agent-bar/sources/test.sh" <<'EOF'
#!/usr/bin/env bash

tmux_agent_bar_test_emit_records() {
  local now=""

  now=$(date +%s)
  printf '%s\n' $'remote/src/project\tcodex\twaiting\ttest_source\t'"$(( now - 60 ))"
  printf '%s\n' $'done-session\tclaude\tdone\ttest_source\t0'
  printf '%s\n' $'current\tcodex\tworking\ttest_source\t30'
}

tmux_agent_register_source "test" "tmux_agent_bar_test_emit_records"
EOF

  actual=$(
    PATH="${tmp_dir}/bin:${PATH}" \
    XDG_CONFIG_HOME="${tmp_dir}/config" \
    TMUX="/tmp/tmux-test" \
    TMUX_CALLS="${tmp_dir}/tmux-calls" \
    FZF_ARGS="${tmp_dir}/fzf-args" \
    FZF_INPUT="${tmp_dir}/fzf-input" \
    SWITCHED_TARGET="${tmp_dir}/switched-target" \
    "${BASH}" "${TARGET_SCRIPT}"
  )

  switched_target=$(<"${tmp_dir}/switched-target")
  fzf_input=$(<"${tmp_dir}/fzf-input")
  fzf_args=$(<"${tmp_dir}/fzf-args")

  assert_equal "picker does not print on successful switch" "" "${actual}"
  assert_equal "picker switches using the hidden full target" "remote/src/project" "${switched_target}"
  assert_equal \
    "picker formats prioritized rows and filters the current session" \
    $'remote/src/project\twaiting\tremote/src/project\tcodex\ttest_source\t1m\ndone-session\tdone\tdone-session\tclaude\ttest_source\t-' \
    "${fzf_input}"
  assert_matches "picker configures fzf hidden target column" '--with-nth=2\.\.' "${fzf_args}"
  assert_matches "picker configures ctrl-r reload" 'ctrl-r:reload' "${fzf_args}"

  rm -rf "${tmp_dir}"
}

run_switch_selection_case
