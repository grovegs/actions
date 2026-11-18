#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=run_unity_tests.sh
source "${GITHUB_ACTION_PATH}/scripts/run_unity_tests.sh"

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

echo "::notice::Using Unity: ${UNITY_EDITOR_PATH}"

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

if [ "${#TEST_RETRIES}" -gt 2 ]; then
  echo "::error::TEST_RETRIES must be below 100, got '${TEST_RETRIES}'"
  exit 1
fi

case "${TEST_GRAPHICS:-false}" in
  true | false) ;;
  *)
    echo "::error::TEST_GRAPHICS must be true or false, got '${TEST_GRAPHICS}'"
    exit 1
    ;;
esac

declare -a UNITY_ARGS
UNITY_ARGS=()

if [ "${TEST_GRAPHICS:-false}" != "true" ]; then
  UNITY_ARGS+=(-nographics -testCategory "!Graphics")
fi

if [ -n "${UNITY_ACCELERATOR:-}" ]; then
  ACCELERATOR="${UNITY_ACCELERATOR}"
  if [[ "${ACCELERATOR}" != *:* ]]; then
    ACCELERATOR="${ACCELERATOR}:10080"
  fi
  UNITY_ARGS+=(-EnableCacheServer -cacheServerEndpoint "${ACCELERATOR}")
fi

if [ -n "${UNITY_LICENSE_KEY:-}" ]; then
  UNITY_ARGS+=(
    -username "${UNITY_EMAIL}"
    -password "${UNITY_PASSWORD}"
    -serial "${UNITY_LICENSE_KEY}"
  )
fi

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
  ATTEMPT=0
  CRASH_RETRIED=0
  RUN=0
  RAN_MODES=$((RAN_MODES + 1))

  while true; do
    rm -f "${REPORT}"
    RUN=$((RUN + 1))
    LOG_FILE="${LOGS_DIR}/${mode}-${RUN}.log"

    echo "::group::🧪 ${mode} tests"
    set +e
    run_unity_tests "${LOG_FILE}" \
      -runTests \
      -testPlatform "${mode}" \
      -testResults "${REPORT}" \
      ${UNITY_ARGS[@]+"${UNITY_ARGS[@]}"}
    EXIT_CODE=$?
    set -e
    echo "::endgroup::"

    TOTAL=$(get_result_attribute "${REPORT}" total)
    PASSED=$(get_result_attribute "${REPORT}" passed)
    FAILED=$(get_result_attribute "${REPORT}" failed)
    SKIPPED=$(get_result_attribute "${REPORT}" skipped)

    if [ ! -f "${REPORT}" ] || ! grep -q '<test-run ' "${REPORT}"; then
      OUTCOME="error"
    elif [ "${FAILED}" -gt 0 ]; then
      OUTCOME="failed"
    elif [ "${EXIT_CODE}" -eq 0 ]; then
      OUTCOME="passed"
    else
      OUTCOME="error"
    fi

    if [ "${OUTCOME}" = "error" ] && [ "${EXIT_CODE}" -gt 128 ] && [ "${CRASH_RETRIED}" -eq 0 ]; then
      CRASH_RETRIED=1
      echo "::warning::${mode}: the Unity editor crashed (exit code ${EXIT_CODE}) before reporting results. Running the mode once more"
      continue
    fi

    if [ "${OUTCOME}" != "failed" ] || [ "${ATTEMPT}" -ge "${TEST_RETRIES}" ]; then
      break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    echo "::warning::${mode}: ${FAILED} test(s) failed. Running the mode again (retry ${ATTEMPT} of ${TEST_RETRIES})"
  done

  case "${OUTCOME}" in
    passed)
      RESULT="✅ Passed"
      echo "::notice::${mode}: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
      if [ "${TOTAL}" -eq 0 ]; then
        RESULT="⚠️ No tests"
        echo "::warning::${mode}: no tests ran. Check the test mode, the test assemblies and the category filter"
      fi
      ;;
    failed)
      RESULT="❌ Failed"
      FAILED_MODES=$((FAILED_MODES + 1))
      echo "::error::${mode}: ${FAILED} test(s) failed (${PASSED} passed, ${SKIPPED} skipped)"
      FAILED_TESTS=$(list_failed_tests "${REPORT}")
      if [ -n "${FAILED_TESTS}" ]; then
        echo "::group::❌ Failed ${mode} tests"
        echo "${FAILED_TESTS}"
        echo "::endgroup::"
      fi
      ;;
    *)
      RESULT="⚠️ Error (exit ${EXIT_CODE})"
      FAILED_MODES=$((FAILED_MODES + 1))
      echo "::error::${mode} tests did not complete (exit code ${EXIT_CODE}): compile error, license, timeout or editor crash. Log: ${LOG_FILE}"
      ;;
  esac

  echo "| ${mode} | ${RESULT} | ${PASSED} | ${FAILED} | ${SKIPPED} |" >> "${GITHUB_STEP_SUMMARY}"

  if [ "${OUTCOME}" = "failed" ] && [ -n "${FAILED_TESTS:-}" ]; then
    FAILED_SUMMARY="${FAILED_SUMMARY}
<details><summary>Failed ${mode} tests</summary>

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
