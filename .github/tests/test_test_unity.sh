#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTION="${ROOT}/.github/actions/test-unity"
WORK="$(mktemp -d)"
FAILURES=0

mkdir -p "${WORK}/project/ProjectSettings" "${WORK}/temp"
touch "${WORK}/project/ProjectSettings/ProjectSettings.asset"

if [ "$(uname)" = "Darwin" ]; then
  EDITOR_ROOT="${WORK}/Unity.app"
  EDITOR="${EDITOR_ROOT}/Contents/MacOS/Unity"
else
  EDITOR_ROOT="${WORK}/Unity"
  EDITOR="${EDITOR_ROOT}"
fi

mkdir -p "$(dirname "${EDITOR}")" "${WORK}/bin"
printf '#!/usr/bin/env bash\n' > "${EDITOR}"
chmod +x "${EDITOR}"

cat > "${WORK}/bin/unity" << 'CLI_SCRIPT'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  echo "1.0.1"
  exit 0
fi
echo "ARGS: $*" >> "${FAKE_LOG}"
report=""
log=""
retries=0
while [ $# -gt 0 ]; do
  case "$1" in
    --output) report="$2" ;;
    --retries) retries="$2" ;;
    -logFile) log="$2" ;;
  esac
  shift
done
echo "editor log" > "${log}"
run=$(grep -c "ARGS" "${FAKE_LOG}")
behavior="${FAKE_BEHAVIOR:-pass}"
if [ "${behavior}" = "stop-once" ] && [ "${run}" -gt 1 ]; then behavior="pass"; fi
write_failed() {
  {
    printf '<test-run id="2" total="3" passed="2" failed="1" skipped="0">\n'
    printf '<test-case id="1" fullname="Game.Tests.Breaks" result="Failed">\n'
    printf '<failure><message><![CDATA[  Expected: 1\n  But was:  2\n]]></message></failure>\n'
    printf '</test-case>\n</test-run>\n'
  } > "$1"
}
case "${behavior}" in
  pass)
    printf '<test-run id="2" total="3" passed="3" failed="0" skipped="0">\n' > "${report}"
    ;;
  fail)
    write_failed "${report}"
    attempt=2
    while [ "${attempt}" -le "$((retries + 1))" ]; do
      write_failed "${report%.xml}.attempt-${attempt}.xml"
      attempt=$((attempt + 1))
    done
    exit 8
    ;;
  flaky)
    write_failed "${report}"
    printf '<test-run id="2" total="1" passed="1" failed="0" skipped="0">\n' > "${report%.xml}.attempt-2.xml"
    echo "{}" > "${report%.xml}.retries.json"
    ;;
  stop | stop-once)
    exit 6
    ;;
  compile)
    echo "Assets/A.cs(1,1): error CS1002: ; expected" >> "${log}"
    exit 6
    ;;
  timeout)
    exit 14
    ;;
  zero)
    printf '<test-run id="2" total="0" passed="0" failed="0" skipped="0">\n' > "${report}"
    ;;
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

run_tests() {
  : > "${WORK}/fake.log"
  : > "${WORK}/summary"
  : > "${WORK}/output"
  env \
    FAKE_LOG="${WORK}/fake.log" \
    GITHUB_ACTION_PATH="${ACTION}" \
    RUNNER_TEMP="${WORK}/temp" \
    GITHUB_OUTPUT="${WORK}/output" \
    GITHUB_STEP_SUMMARY="${WORK}/summary" \
    PROJECT_DIR="${WORK}/project" \
    UNITY_EXECUTABLE="${EDITOR}" \
    PATH="${WORK}/bin:${PATH}" \
    "$@" bash "${ACTION}/scripts/test_project.sh" > "${WORK}/stdout" 2>&1
}

expect() {
  local name="$1"
  local expected_exit="$2"
  local expected_runs="$3"
  local expected_text="$4"
  shift 4
  local actual_exit=0
  local actual_runs

  run_tests "$@" || actual_exit=$?
  actual_runs=$(grep -c "ARGS" "${WORK}/fake.log" || true)

  if [ "${actual_exit}" -ne "${expected_exit}" ] || [ "${actual_runs}" -ne "${expected_runs}" ] || ! grep -q -- "${expected_text}" "${WORK}/stdout" "${WORK}/summary" "${WORK}/fake.log"; then
    echo "${name}: exit ${actual_exit} (want ${expected_exit}), ${actual_runs} run(s) (want ${expected_runs}), text '${expected_text}'"
    sed 's/^/    /' "${WORK}/stdout" | grep -E "::(error|warning|notice)" || true
    FAILURES=$((FAILURES + 1))
  fi
}

expect "pass" 0 1 "EditMode: 3 passed" TEST_MODES=EditMode
expect "both modes" 0 2 "PlayMode: 3 passed" TEST_MODES="EditMode, PlayMode"
expect "editor and report are passed to the CLI" 0 1 "test ${WORK}/project --mode EditMode --output ${WORK}/temp/unity-test-results/EditMode.xml --editor-path ${EDITOR_ROOT} " TEST_MODES=EditMode
expect "license arguments" 0 1 "-nographics -testCategory !Graphics -username a@b.c -password secret -serial KEY" TEST_MODES=EditMode UNITY_EMAIL=a@b.c UNITY_PASSWORD=secret UNITY_LICENSE_KEY=KEY
expect "graphics on leaves the filter out" 0 1 "EditMode-1.log$" TEST_MODES=EditMode TEST_GRAPHICS=true
expect "summary names the skipped category" 0 1 "Graphics" TEST_MODES=EditMode
expect "timeout, retries and accelerator are passed" 0 1 "--timeout 60 --retries 2 --accelerator cache:10080 -- " TEST_MODES=EditMode TEST_TIMEOUT=60 TEST_RETRIES=2 UNITY_ACCELERATOR=cache:10080
expect "failure lists the test and its message" 1 1 "Game.Tests.Breaks: Expected: 1 | But was:  2" TEST_MODES=EditMode FAKE_BEHAVIOR=fail
expect "flaky test passes with a warning" 0 1 "1 test(s) passed only after a retry" TEST_MODES=EditMode TEST_RETRIES=1 FAKE_BEHAVIOR=flaky
expect "flaky test is counted as passed" 0 1 "EditMode: 3 passed, 0 failed" TEST_MODES=EditMode TEST_RETRIES=1 FAKE_BEHAVIOR=flaky
expect "retries run out" 1 1 "EditMode: 1 test(s) failed" TEST_MODES=EditMode TEST_RETRIES=2 FAKE_BEHAVIOR=fail
expect "stopped editor recovers" 0 2 "stopped before reporting" TEST_MODES=EditMode FAKE_BEHAVIOR=stop-once
expect "stopped twice fails" 1 2 "did not complete" TEST_MODES=EditMode FAKE_BEHAVIOR=stop
expect "compile error is not run again" 1 1 "did not complete" TEST_MODES=EditMode FAKE_BEHAVIOR=compile
expect "timeout fails without a rerun" 1 1 "did not finish within 5 seconds" TEST_MODES=EditMode TEST_TIMEOUT=5 FAKE_BEHAVIOR=timeout
expect "zero tests warns" 0 1 "no tests ran" TEST_MODES=EditMode FAKE_BEHAVIOR=zero
expect "no mode fails" 1 0 "No test mode ran" TEST_MODES=" , "
expect "retries must be small" 1 0 "must be 10 or lower" TEST_MODES=EditMode TEST_RETRIES=11
expect "timeout must be a number" 1 0 "whole number of seconds" TEST_MODES=EditMode TEST_TIMEOUT=5m
expect "graphics must be true or false" 1 0 "must be true or false" TEST_MODES=EditMode TEST_GRAPHICS=yes

if [ -n "$(ls "${WORK}/temp/unity-test-results" | grep -v -E '\.(xml|json)$' || true)" ]; then
  echo "The results directory holds files that are not reports"
  FAILURES=$((FAILURES + 1))
fi

: > "${WORK}/fake.log"
env \
  FAKE_LOG="${WORK}/fake.log" FAKE_BEHAVIOR=hang \
  GITHUB_ACTION_PATH="${ACTION}" RUNNER_TEMP="${WORK}/temp" \
  GITHUB_OUTPUT="${WORK}/output" GITHUB_STEP_SUMMARY="${WORK}/summary" \
  PROJECT_DIR="${WORK}/project" UNITY_EXECUTABLE="${EDITOR}" TEST_MODES=EditMode PATH="${WORK}/bin:${PATH}" \
  bash "${ACTION}/scripts/test_project.sh" > /dev/null 2>&1 &
SCRIPT_PID=$!
sleep 4
CHILD_PID=$(awk '/CHILD/ { print $2 }' "${WORK}/fake.log")
kill -TERM "${SCRIPT_PID}"
sleep 9

if kill -0 "${SCRIPT_PID}" 2> /dev/null || { [ -n "${CHILD_PID}" ] && kill -0 "${CHILD_PID}" 2> /dev/null; }; then
  echo "cancel: the script or the editor's child survived"
  FAILURES=$((FAILURES + 1))
fi
wait "${SCRIPT_PID}" 2> /dev/null || true

if [ -z "${CHILD_PID}" ]; then
  echo "cancel: the fake editor never started"
  FAILURES=$((FAILURES + 1))
fi

if [ "${FAILURES}" -gt 0 ]; then
  echo "${FAILURES} test-unity check(s) failed"
  exit 1
fi

echo "✅ test-unity runs, retries, reports and stops as expected"
