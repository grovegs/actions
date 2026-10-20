#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_VERSION:-}" ]; then
  echo "::error::UNITY_VERSION environment variable is required"
  exit 1
fi

UNITY_PATH_INPUT="${UNITY_PATH:-}"
UNITY_PATH_INPUT="${UNITY_PATH_INPUT/#\~/$HOME}"

if [ -n "${UNITY_PATH_INPUT}" ]; then
  INSTALL_ROOT="${UNITY_PATH_INPUT}"
else
  INSTALL_ROOT=$(unity install-path --get --quiet --no-banner 2> /dev/null || echo "")
fi

if [ -z "${INSTALL_ROOT}" ]; then
  echo "::error::Could not determine the Unity editor install path"
  exit 1
fi

echo "::notice::Unity editor install directory: ${INSTALL_ROOT}/${UNITY_VERSION}"
echo "install-dir=${INSTALL_ROOT}/${UNITY_VERSION}" >> "${GITHUB_OUTPUT}"
