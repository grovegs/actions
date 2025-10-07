#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "::error::Usage: $0 <project_dir>"
  exit 1
fi

project_dir="$1"

if [ ! -d "${project_dir}" ]; then
  echo "::error::Directory '${project_dir}' does not exist."
  exit 1
fi

project_settings="${project_dir}/ProjectSettings/ProjectSettings.asset"
if [ ! -f "${project_settings}" ]; then
  echo "::error::Not a valid Unity project. ProjectSettings/ProjectSettings.asset not found."
  exit 1
fi

run_unity_tests() {
  local platform="$1"

  unity_output=$(unity -batchmode -nographics \
    -projectPath "${project_dir}" \
    -runTests \
    -testPlatform "${platform}" 2>&1 || true)

  local error_count
  local warning_count
  error_count=$(echo "${unity_output}" | grep -c "ERROR:" || true)
  warning_count=$(echo "${unity_output}" | grep -c "WARNING:" || true)

  if [ "${error_count}" -gt 0 ]; then
    echo "::error::${platform} tests failed with ${error_count} error(s)."
    echo "${unity_output}" | grep "ERROR:" | uniq | while read -r line; do
      echo "::error::${line}"
    done
  fi

  if [ "${warning_count}" -gt 0 ]; then
    echo "::warning::${platform} tests completed with ${warning_count} warning(s)."
    echo "${unity_output}" | grep "WARNING:" | uniq | while read -r line; do
      echo "::warning::${line}"
    done
  fi

  local tests_passed
  local tests_failed
  local tests_skipped
  tests_passed=$(echo "${unity_output}" | grep -oP '\d+(?= tests? passed)' | tail -1 || echo "0")
  tests_failed=$(echo "${unity_output}" | grep -oP '\d+(?= tests? failed)' | tail -1 || echo "0")
  tests_skipped=$(echo "${unity_output}" | grep -oP '\d+(?= tests? skipped)' | tail -1 || echo "0")

  if [ "${tests_failed}" -gt 0 ]; then
    echo "${unity_output}" | grep "Failed:" | uniq | while read -r line; do
      echo "::error::${line}"
    done
  fi

  echo "${error_count},${warning_count},${tests_passed},${tests_failed},${tests_skipped}"
}

total_errors=0
total_warnings=0
total_passed=0
total_failed=0
total_skipped=0

results=$(run_unity_tests "EditMode")
IFS=',' read -r errors warnings passed failed skipped <<< "${results}"
total_errors=$((total_errors + errors))
total_warnings=$((total_warnings + warnings))
total_passed=$((total_passed + passed))
total_failed=$((total_failed + failed))
total_skipped=$((total_skipped + skipped))

results=$(run_unity_tests "PlayMode")
IFS=',' read -r errors warnings passed failed skipped <<< "${results}"
total_errors=$((total_errors + errors))
total_warnings=$((total_warnings + warnings))
total_passed=$((total_passed + passed))
total_failed=$((total_failed + failed))
total_skipped=$((total_skipped + skipped))

if [ "${total_errors}" -gt 0 ] || [ "${total_failed}" -gt 0 ]; then
  echo "::error::Summary: ${total_failed} test(s) failed, ${total_errors} error(s), ${total_warnings} warning(s)."
  exit 1
else
  echo "::notice::Summary: All ${total_passed} test(s) passed, ${total_warnings} warning(s)."
  exit 0
fi
