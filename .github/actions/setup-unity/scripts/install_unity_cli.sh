#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_CLI_CHANNEL:-}" ]; then
  echo "::error::UNITY_CLI_CHANNEL environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_TEMP:-}" ]; then
  echo "::error::RUNNER_TEMP environment variable is required"
  exit 1
fi

UNITY_CLI_BIN_DIR="${HOME}/.unity/bin"

if command -v unity > /dev/null 2>&1; then
  echo "::notice::Unity CLI already installed: $(unity --version)"
  exit 0
fi

if [ -x "${UNITY_CLI_BIN_DIR}/unity" ]; then
  echo "${UNITY_CLI_BIN_DIR}" >> "${GITHUB_PATH}"
  echo "::notice::Unity CLI already installed: $("${UNITY_CLI_BIN_DIR}/unity" --version)"
  exit 0
fi

INSTALLER_DIR="${RUNNER_TEMP}/unity-cli-installer"
INSTALLER_FILE="${INSTALLER_DIR}/install.sh"

mkdir -p "${INSTALLER_DIR}"

echo "::notice::Downloading Unity CLI installer (${UNITY_CLI_CHANNEL} channel)"
if ! curl --fail --location --silent --show-error --retry 3 --output "${INSTALLER_FILE}" \
  "https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.sh"; then
  echo "::error::Failed to download Unity CLI installer"
  exit 1
fi

if ! UNITY_CLI_CHANNEL="${UNITY_CLI_CHANNEL}" bash "${INSTALLER_FILE}"; then
  echo "::error::Unity CLI installation failed"
  exit 1
fi

rm -rf "${INSTALLER_DIR}"

if [ ! -x "${UNITY_CLI_BIN_DIR}/unity" ]; then
  echo "::error::Unity CLI binary not found at ${UNITY_CLI_BIN_DIR}/unity after installation"
  exit 1
fi

echo "${UNITY_CLI_BIN_DIR}" >> "${GITHUB_PATH}"
echo "::notice::Installed Unity CLI $("${UNITY_CLI_BIN_DIR}/unity" --version)"
