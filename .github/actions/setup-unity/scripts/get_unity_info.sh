#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_PATH:-}" ]; then
  echo "::error::PROJECT_PATH environment variable is required"
  exit 1
fi

extract_version_info() {
  local full_version="$1"
  local version=""
  local changeset=""

  if [[ "${full_version}" =~ ^([0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+)[[:space:]]*\(([a-f0-9]{12})\)[[:space:]]*$ ]]; then
    version="${BASH_REMATCH[1]}"
    changeset="${BASH_REMATCH[2]}"
  elif [[ "${full_version}" =~ ^([0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+)$ ]]; then
    echo "::error::Unity version must include changeset in parentheses such as 6000.1.9f1 (ed7b183fd33d)" >&2
    echo "::error::Provided version: ${full_version}" >&2
    echo "::error::You can find the full version with changeset in your project's ProjectSettings/ProjectVersion.txt file" >&2
    exit 1
  else
    echo "::error::Invalid Unity version format: ${full_version}" >&2
    echo "::error::Expected format: major.minor.patch[stage][build] (changeset) such as 6000.1.9f1 (ed7b183fd33d)" >&2
    exit 1
  fi

  echo "${version}|${changeset}"
}

read_from_project_version() {
  local project_version_file="${PROJECT_PATH}/ProjectSettings/ProjectVersion.txt"

  if [ ! -f "${project_version_file}" ]; then
    echo "::error::ProjectVersion.txt not found at: ${project_version_file}" >&2
    echo "::error::Please ensure the project path is correct or provide explicit unity-version" >&2
    exit 1
  fi

  if [ ! -r "${project_version_file}" ]; then
    echo "::error::Cannot read file: ${project_version_file}" >&2
    echo "::error::Please check file permissions" >&2
    exit 1
  fi

  echo "::notice::Reading Unity version from ${project_version_file}" >&2

  local version=""
  local changeset=""

  version=$(grep "^m_EditorVersion:" "${project_version_file}" | sed -E 's/^m_EditorVersion:[[:space:]]*//' | tr -d '\r\n ')
  changeset=$(grep "^m_EditorVersionWithRevision:" "${project_version_file}" | sed -E 's/.*\(([a-f0-9]{12})\).*/\1/' | tr -d '\r\n ')

  if [ -z "${version}" ]; then
    echo "::error::Failed to extract Unity version from ${project_version_file}" >&2
    echo "::error::Please check the file format or provide explicit unity-version" >&2
    exit 1
  fi

  if [ -z "${changeset}" ] || [ "${changeset}" = "${version}" ]; then
    echo "::error::Failed to extract Unity changeset from ${project_version_file}" >&2
    echo "::error::The file may not contain changeset information. Please provide explicit unity-version with changeset" >&2
    exit 1
  fi

  echo "${version}|${changeset}"
}

validate_version_format() {
  local version="$1"
  local changeset="$2"

  if ! [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+[a-z][0-9]+$ ]]; then
    echo "::error::Invalid Unity version format: ${version}"
    echo "::error::Expected format: major.minor.patch[stage][build] such as 6000.1.9f1 or 2023.3.1f1"
    exit 1
  fi

  if ! [[ "${changeset}" =~ ^[a-f0-9]{12}$ ]]; then
    echo "::error::Invalid Unity changeset format: ${changeset}"
    echo "::error::Expected format: 12-character hexadecimal string such as ed7b183fd33d"
    exit 1
  fi
}

UNITY_VERSION_INPUT="${UNITY_VERSION_INPUT:-}"

if [ -n "${UNITY_VERSION_INPUT}" ]; then
  echo "::notice::Using provided Unity version: ${UNITY_VERSION_INPUT}"

  VERSION_INFO=$(extract_version_info "${UNITY_VERSION_INPUT}")
  VERSION=$(echo "${VERSION_INFO}" | cut -d'|' -f1)
  CHANGESET=$(echo "${VERSION_INFO}" | cut -d'|' -f2)
else
  echo "::notice::No Unity version provided, reading from ProjectVersion.txt"

  if [ ! -d "${PROJECT_PATH}" ]; then
    echo "::error::Project path does not exist: ${PROJECT_PATH}"
    exit 1
  fi

  VERSION_INFO=$(read_from_project_version)
  VERSION=$(echo "${VERSION_INFO}" | cut -d'|' -f1)
  CHANGESET=$(echo "${VERSION_INFO}" | cut -d'|' -f2)
fi

validate_version_format "${VERSION}" "${CHANGESET}"

echo "::notice::Unity version: ${VERSION}"
echo "::notice::Unity changeset: ${CHANGESET}"

{
  echo "version=${VERSION}"
  echo "changeset=${CHANGESET}"
} >> "${GITHUB_OUTPUT}"
