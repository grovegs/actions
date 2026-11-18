#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTION="${ROOT}/.github/actions/build-unity"
WORK="$(mktemp -d)"
FAILURES=0

mkdir -p "${WORK}/bin" "${WORK}/temp" "${WORK}/project"

if [ "$(uname)" = "Darwin" ]; then
  EDITOR_ROOT="${WORK}/Unity.app"
  EDITOR="${EDITOR_ROOT}/Contents/MacOS/Unity"
else
  EDITOR_ROOT="${WORK}/Unity"
  EDITOR="${EDITOR_ROOT}"
fi

cat > "${WORK}/bin/unity" << 'CLI_SCRIPT'
#!/usr/bin/env bash
: > "${FAKE_LOG}"
for argument in "$@"; do
  echo "ARG: ${argument}" >> "${FAKE_LOG}"
done
editor_args=""
while [ $# -gt 0 ]; do
  case "$1" in
    --args) editor_args="$2" ;;
  esac
  shift
done
eval "set -- ${editor_args}"
for argument in "$@"; do
  echo "EDITOR: ${argument}" >> "${FAKE_LOG}"
done
case "${FAKE_BEHAVIOR:-pass}" in
  fail) exit 6 ;;
  timeout) exit 14 ;;
  hang)
    sleep 300 &
    child=$!
    echo "CHILD ${child}" >> "${FAKE_LOG}"
    trap 'kill "${child}"; exit 130' INT TERM
    wait
    ;;
esac
CLI_SCRIPT
chmod +x "${WORK}/bin/unity"

cat > "${WORK}/run.sh" << 'RUN_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
source "${ACTION}/scripts/run_unity_build.sh"
run_unity_build Android Build.Run "${RUNNER_TEMP}/build.log" -nographics -password "it's a \"secret\" \$HOME" -outputPath "/tmp/with space/app.aab"
RUN_SCRIPT

run_build() {
  : > "${WORK}/output"
  env \
    ACTION="${ACTION}" \
    FAKE_LOG="${WORK}/fake.log" \
    PATH="${WORK}/bin:${PATH}" \
    RUNNER_TEMP="${WORK}/temp" \
    GITHUB_OUTPUT="${WORK}/output" \
    PROJECT_DIR="${WORK}/project" \
    UNITY_EDITOR_PATH="${EDITOR}" \
    "$@" bash "${WORK}/run.sh" > "${WORK}/stdout" 2>&1
}

expect() {
  local name="$1"
  local expected_exit="$2"
  local expected_text="$3"
  shift 3
  local actual_exit=0

  run_build "$@" || actual_exit=$?

  if [ "${actual_exit}" -ne "${expected_exit}" ] || ! grep -q -F -- "${expected_text}" "${WORK}/stdout" "${WORK}/fake.log" "${WORK}/output"; then
    echo "${name}: exit ${actual_exit} (want ${expected_exit}), text '${expected_text}'"
    FAILURES=$((FAILURES + 1))
  fi
}

expect "target is passed" 0 "ARG: Android"
expect "method is passed" 0 "ARG: Build.Run"
expect "editor bundle is passed" 0 "ARG: ${EDITOR_ROOT}"
expect "editor path output keeps the executable" 0 "editor-path=${EDITOR}"
expect "quotes and dollars survive" 0 "EDITOR: it's a \"secret\" \$HOME"
expect "spaces survive" 0 "EDITOR: /tmp/with space/app.aab"
expect "no provenance by default" 0 "ARG: --no-provenance"
expect "provenance path" 0 "ARG: ${WORK}/p.json" BUILD_PROVENANCE_FILE="${WORK}/p.json"
expect "timeout is passed" 0 "ARG: 90" BUILD_TIMEOUT=90
expect "accelerator is passed" 0 "ARG: cache:10080" UNITY_ACCELERATOR=cache:10080
expect "failure keeps the exit code" 6 "ARG: Android" FAKE_BEHAVIOR=fail
expect "timeout is reported" 14 "did not finish within 90 seconds" BUILD_TIMEOUT=90 FAKE_BEHAVIOR=timeout
expect "timeout must be a number" 1 "whole number of seconds" BUILD_TIMEOUT=5m

env \
  ACTION="${ACTION}" FAKE_LOG="${WORK}/fake.log" FAKE_BEHAVIOR=hang PATH="${WORK}/bin:${PATH}" \
  RUNNER_TEMP="${WORK}/temp" GITHUB_OUTPUT="${WORK}/output" PROJECT_DIR="${WORK}/project" \
  UNITY_EDITOR_PATH="${EDITOR}" bash "${WORK}/run.sh" > /dev/null 2>&1 &
SCRIPT_PID=$!
sleep 3
CHILD_PID=$(awk '/CHILD/ { print $2 }' "${WORK}/fake.log")
kill -TERM "${SCRIPT_PID}"
sleep 3

if kill -0 "${SCRIPT_PID}" 2> /dev/null || { [ -n "${CHILD_PID}" ] && kill -0 "${CHILD_PID}" 2> /dev/null; }; then
  echo "cancel: the script or the editor's child survived"
  FAILURES=$((FAILURES + 1))
fi
wait "${SCRIPT_PID}" 2> /dev/null || true

if [ -z "${CHILD_PID}" ]; then
  echo "cancel: the stand-in CLI never started"
  FAILURES=$((FAILURES + 1))
fi

rm -rf "${WORK}"

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} build-unity check(s) failed"
  exit 1
fi

echo "✅ build-unity passes its arguments and stops as expected"
