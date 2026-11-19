#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${TEST_MODES:-}" ]; then
  echo "::error::TEST_MODES environment variable is required"
  exit 1
fi

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "::error::Project directory does not exist: ${PROJECT_DIR}"
  exit 1
fi

if [ ! -f "${PROJECT_DIR}/ProjectSettings/ProjectSettings.asset" ]; then
  echo "::error::Not a valid Unity project. ProjectSettings/ProjectSettings.asset not found"
  exit 1
fi

if ! command -v unity > /dev/null 2>&1; then
  echo "::error::Unity CLI is not installed. Run setup-unity before test-unity"
  exit 1
fi

if [ -n "${UNITY_LICENSE_KEY:-}" ]; then
  if [ -z "${UNITY_EMAIL:-}" ] || [ -z "${UNITY_PASSWORD:-}" ]; then
    echo "::error::unity-email and unity-password are required with unity-license-key"
    exit 1
  fi
  echo "::add-mask::${UNITY_EMAIL}"
  echo "::add-mask::${UNITY_PASSWORD}"
  echo "::add-mask::${UNITY_LICENSE_KEY}"
fi

UNITY_PATH_INPUT="${UNITY_PATH_INPUT:-}"
UNITY_PATH_INPUT="${UNITY_PATH_INPUT/#\~/$HOME}"

if [ -n "${UNITY_PATH_INPUT}" ]; then
  UNITY_VERSION=$(grep "m_EditorVersion:" "${PROJECT_DIR}/ProjectSettings/ProjectVersion.txt" | cut -d' ' -f2 | tr -d '\r')
  if [ "$(uname)" = "Darwin" ]; then
    UNITY_EDITOR_PATH="${UNITY_PATH_INPUT}/${UNITY_VERSION}/Unity.app"
  else
    UNITY_EDITOR_PATH="${UNITY_PATH_INPUT}/${UNITY_VERSION}/Editor/Unity"
  fi
else
  UNITY_EDITOR_PATH="${UNITY_EXECUTABLE:-}"
  UNITY_EDITOR_PATH="${UNITY_EDITOR_PATH%/Contents/MacOS/Unity}"
fi

if [ -n "${UNITY_EDITOR_PATH}" ] && [ ! -e "${UNITY_EDITOR_PATH}" ]; then
  echo "::error::Unity not found at: ${UNITY_EDITOR_PATH}"
  exit 1
fi

if [ -z "${UNITY_EDITOR_PATH}" ]; then
  echo "::error::Unity editor not found. Run setup-unity before test-unity or set unity-path"
  exit 1
fi

if [ "$(uname)" = "Darwin" ]; then
  UNITY_EDITOR_EXECUTABLE="${UNITY_EDITOR_PATH}/Contents/MacOS/Unity"
else
  UNITY_EDITOR_EXECUTABLE="${UNITY_EDITOR_PATH}"
fi

if [ ! -x "${UNITY_EDITOR_EXECUTABLE}" ]; then
  echo "::error::Unity executable not found: ${UNITY_EDITOR_EXECUTABLE}"
  exit 1
fi

echo "::notice::Using Unity: ${UNITY_EDITOR_PATH} with Unity CLI $(unity --version 2> /dev/null || echo unknown)"

RESULTS_DIR="${RUNNER_TEMP}/unity-test-results"
LOGS_DIR="${RUNNER_TEMP}/unity-test-logs"
mkdir -p "${RESULTS_DIR}" "${LOGS_DIR}"
echo "results-dir=${RESULTS_DIR}" >> "${GITHUB_OUTPUT}"

echo "editor-path=${UNITY_EDITOR_EXECUTABLE}" >> "${GITHUB_OUTPUT}"

TEST_RETRIES="${TEST_RETRIES:-0}"

case "${TEST_RETRIES}" in
  "" | *[!0-9]*)
    echo "::error::TEST_RETRIES must be a whole number, got '${TEST_RETRIES}'"
    exit 1
    ;;
esac

if [ "${#TEST_RETRIES}" -gt 2 ] || [ "${TEST_RETRIES}" -gt 10 ]; then
  echo "::error::TEST_RETRIES must be 10 or lower, got '${TEST_RETRIES}'"
  exit 1
fi

TEST_TIMEOUT="${TEST_TIMEOUT:-}"

case "${TEST_TIMEOUT}" in
  *[!0-9]*)
    echo "::error::TEST_TIMEOUT must be a whole number of seconds, got '${TEST_TIMEOUT}'"
    exit 1
    ;;
esac

case "${TEST_GRAPHICS:-false}" in
  true | false) ;;
  *)
    echo "::error::TEST_GRAPHICS must be true or false, got '${TEST_GRAPHICS}'"
    exit 1
    ;;
esac

declare -a CLI_ARGS
CLI_ARGS=(--editor-path "${UNITY_EDITOR_PATH}" --non-interactive --no-banner)

if [ -n "${TEST_TIMEOUT}" ] && [ "${TEST_TIMEOUT}" -gt 0 ]; then
  CLI_ARGS+=(--timeout "${TEST_TIMEOUT}")
fi

if [ "${TEST_RETRIES}" -gt 0 ]; then
  CLI_ARGS+=(--retries "${TEST_RETRIES}")
fi

if [ -n "${UNITY_ACCELERATOR:-}" ]; then
  CLI_ARGS+=(--accelerator "${UNITY_ACCELERATOR}")
fi

declare -a UNITY_ARGS
UNITY_ARGS=()

if [ "${TEST_GRAPHICS:-false}" != "true" ]; then
  UNITY_ARGS+=(-nographics -testCategory "!Graphics")
fi

if [ -n "${UNITY_LICENSE_KEY:-}" ]; then
  UNITY_ARGS+=(
    -username "${UNITY_EMAIL}"
    -password "${UNITY_PASSWORD}"
    -serial "${UNITY_LICENSE_KEY}"
  )
fi

CLI_PID=""

stop_unity_tests() {
  local signal="$1"

  trap - INT TERM

  if [ -n "${CLI_PID}" ] && kill -0 "${CLI_PID}" 2> /dev/null; then
    echo "::warning::Cancelled. Stopping the Unity CLI and the editor it started"
    kill "-${signal}" "${CLI_PID}" 2> /dev/null || true
    wait "${CLI_PID}" 2> /dev/null || true
  fi

  if [ "${signal}" = "INT" ]; then
    exit 130
  fi

  exit 143
}

trap 'stop_unity_tests INT' INT
trap 'stop_unity_tests TERM' TERM

run_unity_cli() {
  local mode="$1"
  local report="$2"
  local log_file="$3"
  local exit_code=0

  unity test "${PROJECT_DIR}" \
    --mode "${mode}" \
    --output "${report}" \
    "${CLI_ARGS[@]}" \
    -- \
    -logFile "${log_file}" \
    ${UNITY_ARGS[@]+"${UNITY_ARGS[@]}"} &
  CLI_PID=$!

  wait "${CLI_PID}" || exit_code=$?
  CLI_PID=""

  return "${exit_code}"
}

has_compile_errors() {
  local log_file="$1"

  [ -f "${log_file}" ] && grep -q -E "error CS[0-9]+|Scripts have compiler errors" "${log_file}"
}

get_last_report() {
  local report="$1"
  local attempt="$((TEST_RETRIES + 1))"

  while [ "${attempt}" -gt 1 ]; do
    if [ -f "${report%.xml}.attempt-${attempt}.xml" ]; then
      echo "${report%.xml}.attempt-${attempt}.xml"
      return 0
    fi
    attempt=$((attempt - 1))
  done

  echo "${report}"
}

list_failed_tests() {
  local report="$1"

  if [ ! -f "${report}" ]; then
    return 0
  fi

  awk '
    BEGIN { RS = ">" }
    function flush() {
      if (name != "") {
        print name
      }
      name = ""
      in_failure = 0
      collecting = 0
    }
    {
      record = $0
      if (collecting) {
        text = text ">" record
        if (record ~ /\]\]$/ || record ~ /<\/message$/) {
          sub(/^>/, "", text)
          sub(/^[[:space:]]*<!\[CDATA\[/, "", text)
          sub(/\]\]$/, "", text)
          sub(/<\/message$/, "", text)
          sub(/\]\]$/, "", text)
          count = split(text, lines, "\n")
          text = ""
          for (i = 1; i <= count; i++) {
            line = lines[i]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line != "") {
              text = (text == "") ? line : text " | " line
            }
          }
          if (length(text) > 300) {
            text = substr(text, 1, 300) "..."
          }
          print name ": " text
          name = ""
          in_failure = 0
          collecting = 0
        }
        next
      }
      if (record ~ /<test-case[[:space:]]/) {
        flush()
        if (record ~ /result="Failed"/ && match(record, /fullname="[^"]*"/)) {
          name = substr(record, RSTART + 10, RLENGTH - 11)
        }
        if (record ~ /\/$/) {
          flush()
        }
        next
      }
      if (record ~ /<\/test-case$/) {
        flush()
        next
      }
      if (name != "" && record ~ /<failure$/) {
        in_failure = 1
        next
      }
      if (name != "" && record ~ /<\/failure$/) {
        in_failure = 0
        next
      }
      if (in_failure && record ~ /<message$/) {
        collecting = 1
        text = ""
        next
      }
      if (in_failure && record ~ /<message\/$/) {
        flush()
        next
      }
    }
    END { flush() }
  ' "${report}" | sed -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e 's/&apos;/'"'"'/g' -e 's/&amp;/\&/g'
}

get_result_attribute() {
  local report="$1"
  local attribute="$2"
  local value

  value=$(grep -o '<test-run [^>]*>' "${report}" 2> /dev/null | head -1 | sed -n "s/.* ${attribute}=\"\([0-9]*\)\".*/\1/p")
  echo "${value:-0}"
}

FAILED_MODES=0
RAN_MODES=0
FAILED_SUMMARY=""
FAILED_TESTS=""
FAILED_TITLE=""

{
  echo "### 🧪 Unity Test Results"
  echo ""
  echo "| Mode | Result | Passed | Failed | Skipped |"
  echo "| ---- | ------ | ------ | ------ | ------- |"
} >> "${GITHUB_STEP_SUMMARY}"

IFS=',' read -ra MODE_ARRAY <<< "${TEST_MODES}"
for mode in "${MODE_ARRAY[@]}"; do
  mode=$(echo "${mode}" | xargs)
  if [ -z "${mode}" ]; then
    continue
  fi

  REPORT="${RESULTS_DIR}/${mode}.xml"
  RERAN=0
  RUN=0
  RAN_MODES=$((RAN_MODES + 1))

  while true; do
    rm -f "${REPORT}" "${REPORT%.xml}".attempt-*.xml "${REPORT%.xml}.retries.json"
    RUN=$((RUN + 1))
    LOG_FILE="${LOGS_DIR}/${mode}-${RUN}.log"
    rm -f "${LOG_FILE}"

    echo "::group::🧪 ${mode} tests"
    EXIT_CODE=0
    run_unity_cli "${mode}" "${REPORT}" "${LOG_FILE}" || EXIT_CODE=$?
    echo "::endgroup::"

    LAST_REPORT=$(get_last_report "${REPORT}")
    TOTAL=$(get_result_attribute "${REPORT}" total)
    SKIPPED=$(get_result_attribute "${REPORT}" skipped)
    FIRST_FAILED=$(get_result_attribute "${REPORT}" failed)
    FAILED=$(get_result_attribute "${LAST_REPORT}" failed)
    FLAKY=$((FIRST_FAILED - FAILED))
    PASSED=$(($(get_result_attribute "${REPORT}" passed) + FLAKY))

    if [ ! -f "${REPORT}" ] || ! grep -q '<test-run ' "${REPORT}"; then
      OUTCOME="error"
    elif [ "${EXIT_CODE}" -eq 0 ]; then
      OUTCOME="passed"
    elif [ "${EXIT_CODE}" -eq 8 ]; then
      OUTCOME="failed"
    else
      OUTCOME="error"
    fi

    if [ "${EXIT_CODE}" -eq 14 ]; then
      OUTCOME="timeout"
      break
    fi

    if [ "${OUTCOME}" = "error" ] && [ "${EXIT_CODE}" -eq 6 ] && [ "${RERAN}" -eq 0 ] && [ -f "${LOG_FILE}" ] && ! has_compile_errors "${LOG_FILE}"; then
      RERAN=1
      echo "::warning::${mode}: the Unity editor stopped before reporting results. Running the mode once more"
      continue
    fi

    break
  done

  case "${OUTCOME}" in
    passed)
      RESULT="✅ Passed"
      echo "::notice::${mode}: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
      if [ "${TOTAL}" -eq 0 ]; then
        RESULT="⚠️ No tests"
        echo "::warning::${mode}: no tests ran. Check the test mode, the test assemblies and the category filter"
      fi
      if [ "${FLAKY}" -gt 0 ]; then
        RESULT="⚠️ Passed after a retry"
        echo "::warning::${mode}: ${FLAKY} test(s) passed only after a retry"
        FAILED_TESTS=$(list_failed_tests "${REPORT}")
        FAILED_TITLE="Flaky ${mode} tests, first attempt"
      fi
      ;;
    failed)
      RESULT="❌ Failed"
      FAILED_MODES=$((FAILED_MODES + 1))
      echo "::error::${mode}: ${FAILED} test(s) failed (${PASSED} passed, ${SKIPPED} skipped)"
      FAILED_TESTS=$(list_failed_tests "${LAST_REPORT}")
      FAILED_TITLE="Failed ${mode} tests"
      ;;
    timeout)
      RESULT="⚠️ Timed out"
      FAILED_MODES=$((FAILED_MODES + 1))
      echo "::error::${mode} tests did not finish within ${TEST_TIMEOUT} seconds. Log: ${LOG_FILE}"
      ;;
    *)
      RESULT="⚠️ Error (exit ${EXIT_CODE})"
      FAILED_MODES=$((FAILED_MODES + 1))
      echo "::error::${mode} tests did not complete (Unity CLI exit code ${EXIT_CODE}): compile error, license, a project that is already open, or an editor crash. Log: ${LOG_FILE}"
      ;;
  esac

  if [ -n "${FAILED_TESTS}" ]; then
    echo "::group::${FAILED_TITLE}"
    echo "${FAILED_TESTS}"
    echo "::endgroup::"
  fi

  if [ "${OUTCOME}" = "timeout" ] || [ "${OUTCOME}" = "error" ]; then
    if [ -f "${LOG_FILE}" ]; then
      echo "::group::Last lines of the editor log"
      tail -n 80 "${LOG_FILE}"
      echo "::endgroup::"
    fi
  fi

  echo "| ${mode} | ${RESULT} | ${PASSED} | ${FAILED} | ${SKIPPED} |" >> "${GITHUB_STEP_SUMMARY}"

  if [ -n "${FAILED_TESTS}" ]; then
    FAILED_SUMMARY="${FAILED_SUMMARY}
<details><summary>${FAILED_TITLE}</summary>

\`\`\`text
${FAILED_TESTS}
\`\`\`

</details>
"
  fi
  FAILED_TESTS=""
done

if [ "${TEST_GRAPHICS:-false}" != "true" ]; then
  {
    echo ""
    echo "The editor ran without a graphics device, so tests in the \`Graphics\` category were not run and are not counted above."
  } >> "${GITHUB_STEP_SUMMARY}"
fi

if [ -n "${FAILED_SUMMARY}" ]; then
  echo "${FAILED_SUMMARY}" >> "${GITHUB_STEP_SUMMARY}"
fi

if [ "${RAN_MODES}" -eq 0 ]; then
  echo "::error::No test mode ran. TEST_MODES was '${TEST_MODES}'"
  exit 1
fi

if [ "${FAILED_MODES}" -gt 0 ]; then
  echo "::error::${FAILED_MODES} test mode(s) failed. Reports: ${RESULTS_DIR}"
  exit 1
fi

echo "::notice::✓ All Unity tests passed. Reports: ${RESULTS_DIR}"
