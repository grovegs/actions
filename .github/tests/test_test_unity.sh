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

mkdir -p "$(dirname "${EDITOR}")"

cat > "${EDITOR}" << 'EDITOR_SCRIPT'
#!/usr/bin/env bash
echo "ARGS: $*" >> "${FAKE_LOG}"
report=""
while [ $# -gt 0 ]; do
  case "$1" in
    -testResults) report="$2" ;;
  esac
  shift
done
run=$(grep -c "ARGS" "${FAKE_LOG}")
behavior="${FAKE_BEHAVIOR:-pass}"
if [ "${behavior}" = "fail-once" ] && [ "${run}" -gt 1 ]; then behavior="pass"; fi
if [ "${behavior}" = "crash-once" ] && [ "${run}" -gt 1 ]; then behavior="pass"; fi
case "${behavior}" in
  pass)
    printf '<test-run id="2" total="3" passed="3" failed="0" skipped="0">\n' > "${report}"
    ;;
  fail | fail-once)
    {
      printf '<test-run id="2" total="3" passed="2" failed="1" skipped="0">\n'
      printf '<test-case id="1" fullname="Game.Tests.Breaks" result="Failed">\n'
      printf '<failure><message><![CDATA[  Expected: 1\n  But was:  2\n]]></message></failure>\n'
      printf '</test-case>\n</test-run>\n'
    } > "${report}"
    exit 2
    ;;
  crash | crash-once)
    kill -BUS $$
    ;;
  zero)
    printf '<test-run id="2" total="0" passed="0" failed="0" skipped="0">\n' > "${report}"
    ;;
  hang)
    sleep 300 &
    echo "CHILD $!" >> "${FAKE_LOG}"
    wait
    ;;
esac
EDITOR_SCRIPT
chmod +x "${EDITOR}"

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
expect "license arguments" 0 1 "-nographics -testCategory !Graphics -username a@b.c -password secret -serial KEY" TEST_MODES=EditMode UNITY_EMAIL=a@b.c UNITY_PASSWORD=secret UNITY_LICENSE_KEY=KEY
expect "graphics on leaves the filter out" 0 1 "-testResults ${WORK}/temp/unity-test-results/EditMode.xml$" TEST_MODES=EditMode TEST_GRAPHICS=true
expect "summary names the skipped category" 0 1 "Graphics" TEST_MODES=EditMode
expect "failure lists the test and its message" 1 1 "Game.Tests.Breaks: Expected: 1 | But was:  2" TEST_MODES=EditMode FAKE_BEHAVIOR=fail
expect "retry passes" 0 2 "retry 1 of 1" TEST_MODES=EditMode TEST_RETRIES=1 FAKE_BEHAVIOR=fail-once
expect "retries run out" 1 3 "EditMode: 1 test(s) failed" TEST_MODES=EditMode TEST_RETRIES=2 FAKE_BEHAVIOR=fail
expect "crash recovers" 0 2 "crashed" TEST_MODES=EditMode FAKE_BEHAVIOR=crash-once
expect "crash twice fails" 1 2 "did not complete" TEST_MODES=EditMode FAKE_BEHAVIOR=crash
expect "zero tests warns" 0 1 "no tests ran" TEST_MODES=EditMode FAKE_BEHAVIOR=zero
expect "no mode fails" 1 0 "No test mode ran" TEST_MODES=" , "
expect "retries must be small" 1 0 "must be below 100" TEST_MODES=EditMode TEST_RETRIES=99999999999999999999
expect "graphics must be true or false" 1 0 "must be true or false" TEST_MODES=EditMode TEST_GRAPHICS=yes

if [ -n "$(ls "${WORK}/temp/unity-test-results" | grep -v '\.xml$' || true)" ]; then
  echo "The results directory holds files that are not reports"
  FAILURES=$((FAILURES + 1))
fi

: > "${WORK}/fake.log"
env \
  FAKE_LOG="${WORK}/fake.log" FAKE_BEHAVIOR=hang \
  GITHUB_ACTION_PATH="${ACTION}" RUNNER_TEMP="${WORK}/temp" \
  GITHUB_OUTPUT="${WORK}/output" GITHUB_STEP_SUMMARY="${WORK}/summary" \
  PROJECT_DIR="${WORK}/project" UNITY_EXECUTABLE="${EDITOR}" TEST_MODES=EditMode \
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
