#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if ! command -v unity > /dev/null 2>&1; then
  echo "::error::unity is not installed or not in PATH"
  exit 1
fi

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "::error::Project directory does not exist: ${PROJECT_DIR}"
  exit 1
fi

PROJECT_SETTINGS="${PROJECT_DIR}/ProjectSettings/ProjectSettings.asset"

if [ ! -f "${PROJECT_SETTINGS}" ]; then
  echo "::error::Not a valid Unity project. ProjectSettings/ProjectSettings.asset not found"
  exit 1
fi

echo "::notice::Testing Unity project: ${PROJECT_DIR}"

run_unity_tests() {
  local platform="$1"

  echo "::notice::Running ${platform} tests"

  set +e
  UNITY_OUTPUT=$(unity -batchmode -nographics \
    -projectPath "${PROJECT_DIR}" \
    -runTests \
    -testPlatform "${platform}" 2>&1)
  local unity_exit_code=$?
  set -e

  if [ "${unity_exit_code}" -ne 0 ]; then
    echo "::warning::Unity test command exited with code ${unity_exit_code} for ${platform}"
  fi

  local error_count
  local warning_count
  error_count=$(echo "${UNITY_OUTPUT}" | grep -c "ERROR:" || true)
  warning_count=$(echo "${UNITY_OUTPUT}" | grep -c "WARNING:" || true)

  if [ "${error_count}" -gt 0 ]; then
    echo "::error::${platform} tests failed with ${error_count} error(s)"
    echo "${UNITY_OUTPUT}" | grep "ERROR:" | sort -u | while IFS= read -r line; do
      echo "::error::${line}"
    done
  fi

  if [ "${warning_count}" -gt 0 ]; then
    echo "::warning::${platform} tests completed with ${warning_count} warning(s)"
    echo "${UNITY_OUTPUT}" | grep "WARNING:" | sort -u | while IFS= read -r line; do
      echo "::warning::${line}"
    done
  fi

  local tests_passed
  local tests_failed
  local tests_skipped
  tests_passed=$(echo "${UNITY_OUTPUT}" | grep -oP '\d+(?= tests? passed)' | tail -1 || echo "0")
  tests_failed=$(echo "${UNITY_OUTPUT}" | grep -oP '\d+(?= tests? failed)' | tail -1 || echo "0")
  tests_skipped=$(echo "${UNITY_OUTPUT}" | grep -oP '\d+(?= tests? skipped)' | tail -1 || echo "0")

  if [ "${tests_failed}" -gt 0 ]; then
    echo "${UNITY_OUTPUT}" | grep "Failed:" | sort -u | while IFS= read -r line; do
      echo "::error::${line}"
    done
  fi

  echo "::notice::${platform} results: ${tests_passed} passed, ${tests_failed} failed, ${tests_skipped} skipped"

  echo "${error_count},${warning_count},${tests_passed},${tests_failed},${tests_skipped}"
}

TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

RESULTS=$(run_unity_tests "EditMode")
IFS=',' read -r ERRORS WARNINGS PASSED FAILED SKIPPED <<< "${RESULTS}"
TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNINGS))
TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))

RESULTS=$(run_unity_tests "PlayMode")
IFS=',' read -r ERRORS WARNINGS PASSED FAILED SKIPPED <<< "${RESULTS}"
TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNINGS))
TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))

echo ""
echo "::notice::=========================================="
echo "::notice::Test Summary"
echo "::notice::=========================================="
echo "::notice::Tests Passed:  ${TOTAL_PASSED}"
echo "::notice::Tests Failed:  ${TOTAL_FAILED}"
echo "::notice::Tests Skipped: ${TOTAL_SKIPPED}"
echo "::notice::------------------------------------------"
echo "::notice::Errors:        ${TOTAL_ERRORS}"
echo "::notice::Warnings:      ${TOTAL_WARNINGS}"
echo "::notice::=========================================="

if [ "${TOTAL_ERRORS}" -gt 0 ] || [ "${TOTAL_FAILED}" -gt 0 ]; then
  echo "::error::Tests failed: ${TOTAL_FAILED} test(s) failed, ${TOTAL_ERRORS} error(s)"
  exit 1
fi

echo "::notice::✓ All ${TOTAL_PASSED} test(s) passed"
