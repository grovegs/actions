#!/usr/bin/env bash
set -euo pipefail

if ! command -v npm > /dev/null 2>&1; then
  echo "::error::npm is not installed or not in PATH"
  exit 1
fi

FIREBASE_VERSION="${FIREBASE_VERSION:-}"
SKIP_LOGIN="${SKIP_LOGIN:-false}"

check_firebase_installed() {
  if command -v firebase > /dev/null 2>&1; then
    return 0
  fi
  return 1
}

get_installed_version() {
  if check_firebase_installed; then
    local version_line
    version_line=$(firebase --version 2>/dev/null | head -1 || echo "")

    if [ -n "${version_line}" ]; then
      echo "${version_line}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo ""
    else
      echo ""
    fi
  else
    echo ""
  fi
}

version_matches() {
  local installed="$1"
  local requested="$2"

  if [ -z "${requested}" ]; then
    return 0
  fi

  if [ "${installed}" = "${requested}" ]; then
    return 0
  fi

  return 1
}

install_firebase() {
  local version="$1"

  echo "::notice::Installing Firebase CLI via npm..."

  local package_spec="firebase-tools"
  if [ -n "${version}" ]; then
    package_spec="firebase-tools@${version}"
    echo "::notice::Installing specific version: ${version}"
  else
    echo "::notice::Installing latest version"
  fi

  if ! npm install -g "${package_spec}"; then
    echo "::error::Failed to install Firebase CLI"
    exit 1
  fi

  if ! check_firebase_installed; then
    echo "::error::Firebase CLI installation completed but firebase command not found"
    echo "::error::The installation may have succeeded but the executable is not in PATH"
    exit 1
  fi

  echo "::notice::✅ Firebase CLI installed successfully"
}

verify_firebase() {
  echo "::notice::Verifying Firebase CLI installation"

  local firebase_path
  firebase_path=$(command -v firebase)

  if [ -z "${firebase_path}" ]; then
    echo "::error::Firebase CLI not found in PATH"
    exit 1
  fi

  echo "::notice::Firebase CLI location: ${firebase_path}"

  local version_output
  version_output=$(firebase --version 2>&1 | head -3 || echo "")

  if [ -n "${version_output}" ]; then
    echo "::notice::Firebase CLI version information:"
    echo "${version_output}" | while IFS= read -r line; do
      echo "::notice::  ${line}"
    done
  fi

  if [ "${SKIP_LOGIN}" = "false" ]; then
    echo "::notice::Checking Firebase authentication status"

    set +e
    local auth_output
    auth_output=$(firebase projects:list 2>&1)
    local auth_exit_code=$?
    set -e

    if [ "${auth_exit_code}" -eq 0 ]; then
      echo "::notice::✅ Firebase authentication verified"
    else
      if echo "${auth_output}" | grep -q "not authenticated\|login"; then
        echo "::warning::Firebase CLI is installed but not authenticated"
        echo "::warning::You may need to provide GOOGLE_APPLICATION_CREDENTIALS or run 'firebase login:ci'"
      else
        echo "::warning::Could not verify Firebase authentication status"
        echo "::debug::${auth_output}"
      fi
    fi
  fi
}

main() {
  echo "::notice::Setting up Firebase CLI"

  if [ -n "${FIREBASE_VERSION}" ]; then
    echo "::notice::Requested version: ${FIREBASE_VERSION}"
  else
    echo "::notice::Requested version: latest"
  fi

  local current_version
  current_version=$(get_installed_version)

  if check_firebase_installed && [ -n "${current_version}" ]; then
    echo "::notice::Firebase CLI is already installed"
    echo "::notice::Installed version: ${current_version}"

    if version_matches "${current_version}" "${FIREBASE_VERSION}"; then
      echo "::notice::Installed version matches requested version, skipping installation"

      local firebase_path
      firebase_path=$(command -v firebase)

      {
        echo "firebase-version=${current_version}"
        echo "firebase-path=${firebase_path}"
      } >> "${GITHUB_OUTPUT}"

      verify_firebase
      return 0
    else
      echo "::notice::Installed version does not match requested version"
      echo "::notice::Reinstalling Firebase CLI"
    fi
  fi

  install_firebase "${FIREBASE_VERSION}"

  local firebase_path
  firebase_path=$(command -v firebase)

  local installed_version
  installed_version=$(get_installed_version)

  if [ -z "${installed_version}" ]; then
    echo "::warning::Could not detect installed Firebase CLI version"
    installed_version="unknown"
  fi

  {
    echo "firebase-version=${installed_version}"
    echo "firebase-path=${firebase_path}"
  } >> "${GITHUB_OUTPUT}"

  verify_firebase

  echo "::notice::✅ Firebase CLI setup completed successfully"
  echo "::notice::  Version: ${installed_version}"
  echo "::notice::  Path: ${firebase_path}"
}

main
