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

echo "::notice::Using Unity: ${UNITY_EDITOR_PATH:-resolved by Unity CLI from ProjectVersion.txt}"

RESULTS_DIR="${RUNNER_TEMP}/unity-test-results"
mkdir -p "${RESULTS_DIR}"
echo "results-dir=${RESULTS_DIR}" >> "${GITHUB_OUTPUT}"

declare -a TEST_ARGS
TEST_ARGS=(
  "${PROJECT_DIR}"
  --non-interactive
  --no-banner
  --format github
  --report-format nunit,junit
  --retries "${TEST_RETRIES:-0}"
)

if [ -n "${UNITY_EDITOR_PATH}" ]; then
  TEST_ARGS+=(--editor-path "${UNITY_EDITOR_PATH}")
fi

if [ -n "${UNITY_ACCELERATOR:-}" ]; then
  TEST_ARGS+=(--accelerator "${UNITY_ACCELERATOR}")
fi

if [ -n "${TEST_TIMEOUT:-}" ]; then
  TEST_ARGS+=(--timeout "${TEST_TIMEOUT}")
fi

declare -a UNITY_ARGS
UNITY_ARGS=(-nographics)

if [ -n "${UNITY_LICENSE_KEY:-}" ]; then
  UNITY_ARGS+=(
    -username "${UNITY_EMAIL}"
    -password "${UNITY_PASSWORD}"
    -serial "${UNITY_LICENSE_KEY}"
  )
fi

get_result_attribute() {
  local report="$1"
  local attribute="$2"
  local value

  value=$(grep -o '<test-run [^>]*>' "${report}" 2> /dev/null | head -1 | sed -n "s/.* ${attribute}=\"\([0-9]*\)\".*/\1/p")
  echo "${value:-0}"
}

FAILED_MODES=0

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

  echo "::group::🧪 ${mode} tests"
  set +e
  unity test "${TEST_ARGS[@]}" \
    --mode "${mode}" \
    --output "${REPORT}" \
    --junit-output "${RESULTS_DIR}/${mode}.junit.xml" \
    -- "${UNITY_ARGS[@]}"
  EXIT_CODE=$?
  set -e
  echo "::endgroup::"

  PASSED=$(get_result_attribute "${REPORT}" passed)
  FAILED=$(get_result_attribute "${REPORT}" failed)
  SKIPPED=$(get_result_attribute "${REPORT}" skipped)

  case "${EXIT_CODE}" in
    0)
      RESULT="✅ Passed"
      echo "::notice::${mode}: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
      ;;
    8)
      RESULT="❌ Failed"
      FAILED_MODES=$((FAILED_MODES + 1))
      echo "::error::${mode}: ${FAILED} test(s) failed (${PASSED} passed, ${SKIPPED} skipped)"
      ;;
    *)
      RESULT="⚠️ Error (exit ${EXIT_CODE})"
      FAILED_MODES=$((FAILED_MODES + 1))
      echo "::error::${mode} tests did not complete (exit code ${EXIT_CODE}): compile error, license, timeout or editor crash"
      ;;
  esac

  echo "| ${mode} | ${RESULT} | ${PASSED} | ${FAILED} | ${SKIPPED} |" >> "${GITHUB_STEP_SUMMARY}"
done

if [ "${FAILED_MODES}" -gt 0 ]; then
  echo "::error::${FAILED_MODES} test mode(s) failed. Reports: ${RESULTS_DIR}"
  exit 1
fi

echo "::notice::✓ All Unity tests passed. Reports: ${RESULTS_DIR}"
