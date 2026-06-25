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
  printf '%s\n' $'waiting-old\tcodex\twaiting\ttest_source\t'"$(( now - 120 ))"
  printf '%s\n' $'waiting-new\tcodex\twaiting\ttest_source\t'"$(( now - 60 ))"
  printf '%s\n' $'working-session\tcodex\tworking\ttest_source\t'"$(( now - 30 ))"
  printf '%s\n' $'done-old\tclaude\tdone\ttest_source\t'"$(( now - 300 ))"
  printf '%s\n' $'done-new\tclaude\tdone\ttest_source\t'"$(( now - 180 ))"
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
  assert_equal "picker switches using the hidden full target" "waiting-old" "${switched_target}"
  assert_equal \
    "picker formats scan-ordered rows and filters the current session" \
    $'waiting-old\twaiting\twaiting-old\tcodex\ttest_source\t2m\nwaiting-new\twaiting\twaiting-new\tcodex\ttest_source\t1m\ndone-old\tdone\tdone-old\tclaude\ttest_source\t5m\ndone-new\tdone\tdone-new\tclaude\ttest_source\t3m\nworking-session\tworking\tworking-session\tcodex\ttest_source\t30s' \
    "${fzf_input}"
  assert_matches "picker configures fzf hidden target column" '--with-nth=2\.\.' "${fzf_args}"
  assert_matches "picker configures ctrl-r reload" 'ctrl-r:reload' "${fzf_args}"

  rm -rf "${tmp_dir}"
}

run_switch_selection_case

run_rows_compact_display_labels_case() {
  local tmp_dir="" actual=""

  tmp_dir=$(mktemp -d)
  mkdir -p "${tmp_dir}/bin" "${tmp_dir}/config/tmux-agent-bar/sources"

  cat > "${tmp_dir}/bin/date" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "+%s" ]]; then
  printf '%s\n' "1700000000"
  exit 0
fi

exit 1
EOF
  chmod +x "${tmp_dir}/bin/date"

  cat > "${tmp_dir}/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exit 1
EOF
  chmod +x "${tmp_dir}/bin/tmux"

  cat > "${tmp_dir}/config/tmux-agent-bar/sources/test.sh" <<'EOF'
#!/usr/bin/env bash

tmux_agent_bar_test_emit_records() {
  local now=""

  now=$(date +%s)
  printf '%s\n' $'remote/src/project\tcodex\twaiting\ttest_source\t'"$(( now - 180 ))"
  printf '%s\n' $'other/src/project\tcodex\twaiting\ttest_source\t'"$(( now - 120 ))"
  printf '%s\n' $'local/project\tcodex\twaiting\ttest_source\t'"$(( now - 60 ))"
  printf '%s\n' $'project\tcodex\twaiting\ttest_source\t'"$(( now - 30 ))"
  printf '%s\n' $'current\tcodex\tworking\ttest_source\t30'
}

tmux_agent_register_source "test" "tmux_agent_bar_test_emit_records"
EOF

  actual=$(
    HOME="${tmp_dir}/home" \
    PATH="${tmp_dir}/bin:/usr/bin:/bin" \
    XDG_CONFIG_HOME="${tmp_dir}/config" \
    "${BASH}" "${TARGET_SCRIPT}" --rows current
  )

  assert_equal \
    "picker compacts path-like labels and expands parents only to disambiguate" \
    $'remote/src/project\twaiting\tremote/src/project\tcodex\ttest_source\t3m\nother/src/project\twaiting\tother/src/project\tcodex\ttest_source\t2m\nlocal/project\twaiting\tlocal/project\tcodex\ttest_source\t1m\nproject\twaiting\tproject\tcodex\ttest_source\t30s' \
    "${actual}"

  rm -rf "${tmp_dir}"
}

run_rows_compact_display_labels_case
