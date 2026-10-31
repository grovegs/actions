#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_EDITOR_PATH:-}" ]; then
  echo "::error::UNITY_EDITOR_PATH environment variable is required"
  exit 1
fi

if [ -z "${UNITY_EMAIL:-}" ]; then
  echo "::error::UNITY_EMAIL environment variable is required"
  exit 1
fi

if [ -z "${UNITY_PASSWORD:-}" ]; then
  echo "::error::UNITY_PASSWORD environment variable is required"
  exit 1
fi

LOG_FILE="${RUNNER_TEMP}/unity-return-license.log"
: > "${LOG_FILE}"

echo "::notice::Returning Unity license..."
if ! "${UNITY_EDITOR_PATH}" \
  -batchmode \
  -quit \
  -nographics \
  -returnlicense \
  -username "${UNITY_EMAIL}" \
  -password "${UNITY_PASSWORD}" \
  -logFile "${LOG_FILE}"; then
  echo "::group::Unity return license log"
  cat "${LOG_FILE}" 2> /dev/null || echo "Log not found: ${LOG_FILE}"
  echo "::endgroup::"
  echo "::warning::Failed to return the Unity license. Return it from the Unity ID dashboard if activations run out"
  exit 0
fi

echo "::notice::Returned Unity license"
