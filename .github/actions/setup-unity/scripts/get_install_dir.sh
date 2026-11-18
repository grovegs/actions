#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_VERSION:-}" ]; then
  echo "::error::UNITY_VERSION environment variable is required"
  exit 1
fi

UNITY_PATH_INPUT="${UNITY_PATH:-}"
UNITY_PATH_INPUT="${UNITY_PATH_INPUT/#\~/$HOME}"

read_cli_path() {
  local output="$1"
  local tab
  local value

  tab=$(printf '\t')

  case "${output}" in
    *"${tab}"*)
      value=$(printf '%s\n' "${output}" | awk -F '\t' '$1 == "path" { print $2; exit }')
      if [ -z "${value}" ]; then
        value=$(printf '%s\n' "${output}" | awk -F '\t' 'NR > 1 && NF >= 2 { print $2; exit }')
      fi
      printf '%s\n' "${value}"
      ;;
    *)
      printf '%s\n' "${output}" | head -n 1
      ;;
  esac
}

if [ -n "${UNITY_PATH_INPUT}" ]; then
  INSTALL_ROOT="${UNITY_PATH_INPUT}"
else
  INSTALL_ROOT=$(read_cli_path "$(unity install-path --get --quiet --no-banner 2> /dev/null || echo "")")
fi

if [ -z "${INSTALL_ROOT}" ]; then
  echo "::error::Could not determine the Unity editor install path"
  exit 1
fi

echo "::notice::Unity editor install directory: ${INSTALL_ROOT}/${UNITY_VERSION}"
echo "install-dir=${INSTALL_ROOT}/${UNITY_VERSION}" >> "${GITHUB_OUTPUT}"
