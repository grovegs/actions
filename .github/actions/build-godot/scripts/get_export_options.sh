#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PLATFORM:-}" ]; then
  echo "::error::PLATFORM environment variable is required"
  exit 1
fi

if [ -z "${VERSION:-}" ]; then
  echo "::error::VERSION environment variable is required"
  exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "${VERSION}"

if [[ -z "${MAJOR}" || -z "${MINOR}" || -z "${PATCH}" ]]; then
  echo "::error::Invalid version format. Expected format: major.minor.patch (e.g., 1.0.0)"
  exit 1
fi

case "${PLATFORM}" in
  Android)
    VERSION_NUMBER=$(printf "%d%03d%04d" "${MAJOR}" "${MINOR}" "${PATCH}")
    echo "::notice::Creating Android export options"
    EXPORT_OPTIONS=(
      "version/code=${VERSION_NUMBER}"
      "version/name=${VERSION}"
    )
    ;;
  iOS)
    if [ -z "${IOS_TEAM_ID:-}" ]; then
      echo "::error::IOS_TEAM_ID is required for iOS platform"
      exit 1
    fi
    echo "::notice::Creating iOS export options"
    EXPORT_OPTIONS=(
      "application/short_version=${VERSION}"
      "application/version=${VERSION}"
      "application/app_store_team_id=${IOS_TEAM_ID}"
    )
    ;;
  *)
    echo "::error::Unsupported platform: ${PLATFORM}"
    exit 1
    ;;
esac

{
  echo "::notice::Setting export options: ${EXPORT_OPTIONS[*]}"
  echo "export-options=${EXPORT_OPTIONS[*]}"
} >> "${GITHUB_OUTPUT}"
