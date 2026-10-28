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

declare -a CANDIDATE_DIRS
CANDIDATE_DIRS=(
  "${HOME}/.unity/bin"
  "${HOME}/.local/bin"
  "${HOME}/bin"
  "/usr/local/bin"
  "/opt/homebrew/bin"
)

find_unity_cli() {
  local dir
  local found

  for dir in "${CANDIDATE_DIRS[@]}"; do
    if [ -x "${dir}/unity" ] && [ ! -d "${dir}/unity" ]; then
      echo "${dir}/unity"
      return 0
    fi
  done

  found=$(find "${HOME}" -maxdepth 5 -type f -name unity -perm -u+x 2> /dev/null | head -n 1 || true)

  if [ -n "${found}" ]; then
    echo "${found}"
    return 0
  fi

  return 1
}

if command -v unity > /dev/null 2>&1; then
  echo "::notice::Unity CLI already installed: $(unity --version)"
  exit 0
fi

if UNITY_CLI=$(find_unity_cli); then
  dirname "${UNITY_CLI}" >> "${GITHUB_PATH}"
  echo "::notice::Unity CLI already installed: $("${UNITY_CLI}" --version)"
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

if ! UNITY_CLI=$(find_unity_cli); then
  echo "::error::Unity CLI binary not found after installation. Looked in ${CANDIDATE_DIRS[*]} and under ${HOME}"
  exit 1
fi

dirname "${UNITY_CLI}" >> "${GITHUB_PATH}"
echo "::notice::Installed Unity CLI $("${UNITY_CLI}" --version) at ${UNITY_CLI}"
