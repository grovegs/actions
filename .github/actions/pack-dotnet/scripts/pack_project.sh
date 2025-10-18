#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_PATH:-}" ]; then
  echo "::error::PROJECT_PATH environment variable is required"
  exit 1
fi

if [ -z "${BUILD_CONFIGURATION:-}" ]; then
  echo "::error::BUILD_CONFIGURATION environment variable is required"
  exit 1
fi

if [ -z "${PACKAGE_VERSION:-}" ]; then
  echo "::error::PACKAGE_VERSION environment variable is required"
  exit 1
fi

if [ -z "${PACKAGE_NAME:-}" ]; then
  echo "::error::PACKAGE_NAME environment variable is required"
  exit 1
fi

declare -a MODIFIED_FILES

update_version_in_file() {
  local file="$1"
  local updated=false

  if grep -q "<Version>" "${file}"; then
    if ! grep -q "<Version>\$(.*)</Version>" "${file}"; then
      sed -i.bak "s|<Version>.*</Version>|<Version>${PACKAGE_VERSION}</Version>|g" "${file}"
      updated=true
    fi
  fi

  if grep -q "<AssemblyVersion>" "${file}"; then
    if ! grep -q "<AssemblyVersion>\$(.*)</AssemblyVersion>" "${file}"; then
      sed -i.bak "s|<AssemblyVersion>.*</AssemblyVersion>|<AssemblyVersion>${PACKAGE_VERSION}</AssemblyVersion>|g" "${file}"
      updated=true
    fi
  fi

  if grep -q "<FileVersion>" "${file}"; then
    if ! grep -q "<FileVersion>\$(.*)</FileVersion>" "${file}"; then
      sed -i.bak "s|<FileVersion>.*</FileVersion>|<FileVersion>${PACKAGE_VERSION}</FileVersion>|g" "${file}"
      updated=true
    fi
  fi

  if grep -q "<InformationalVersion>" "${file}"; then
    if ! grep -q "<InformationalVersion>\$(.*)</InformationalVersion>" "${file}"; then
      sed -i.bak "s|<InformationalVersion>.*</InformationalVersion>|<InformationalVersion>${PACKAGE_VERSION}</InformationalVersion>|g" "${file}"
      updated=true
    fi
  fi

  if grep -q "<PackageVersion>" "${file}"; then
    if ! grep -q "<PackageVersion>\$(.*)</PackageVersion>" "${file}"; then
      sed -i.bak "s|<PackageVersion>.*</PackageVersion>|<PackageVersion>${PACKAGE_VERSION}</PackageVersion>|g" "${file}"
      updated=true
    fi
  fi

  rm -f "${file}.bak"

  echo "${updated}"
}

if [ -n "${DIRECTORY_BUILD_PROPS:-}" ]; then
  if [ -f "${DIRECTORY_BUILD_PROPS}" ]; then
    echo "::notice::Updating version in ${DIRECTORY_BUILD_PROPS}"

    PROPS_UPDATED=$(update_version_in_file "${DIRECTORY_BUILD_PROPS}")

    if [ "${PROPS_UPDATED}" = "true" ]; then
      echo "  ✓ Updated version to ${PACKAGE_VERSION}"
      MODIFIED_FILES+=("${DIRECTORY_BUILD_PROPS}")
    else
      echo "  ℹ No direct version values to update (properties use references)"
    fi
  else
    echo "::warning::Directory.Build.props file not found at '${DIRECTORY_BUILD_PROPS}'"
  fi
fi

if [ ! -d "${PROJECT_PATH}" ]; then
  echo "::error::Project directory '${PROJECT_PATH}' does not exist"
  exit 1
fi

if [ "${PROJECT_PATH}" = "." ]; then
  PROJECT_NAME="$(basename "$(pwd)")"
else
  PROJECT_NAME="$(basename "${PROJECT_PATH}")"
fi

PROJECT_FILE="${PROJECT_PATH}/${PROJECT_NAME}.csproj"

if [ ! -f "${PROJECT_FILE}" ]; then
  echo "::error::Project file '${PROJECT_FILE}' does not exist"
  exit 1
fi

echo "::notice::Checking for version properties in ${PROJECT_FILE}"

CSPROJ_UPDATED=$(update_version_in_file "${PROJECT_FILE}")

if [ "${CSPROJ_UPDATED}" = "true" ]; then
  echo "  ✓ Updated version in ${PROJECT_FILE}"
  MODIFIED_FILES+=("${PROJECT_FILE}")
else
  echo "  ℹ No direct version values to update (properties use references)"
fi

NUPKGS_DIR="${HOME}/.nupkgs"
if ! mkdir -p "${NUPKGS_DIR}"; then
  echo "::error::Failed to create directory '${NUPKGS_DIR}'"
  exit 1
fi

PACKAGE_FILE="${NUPKGS_DIR}/${PACKAGE_NAME}.nupkg"

echo "::notice::Packing project ${PROJECT_FILE}"
echo "  Configuration: ${BUILD_CONFIGURATION}"
echo "  Version: ${PACKAGE_VERSION}"
echo "  Output: ${PACKAGE_FILE}"

if ! dotnet pack \
  --no-build \
  --nologo \
  --output "${NUPKGS_DIR}" \
  --configuration "${BUILD_CONFIGURATION}" \
  /p:Version="${PACKAGE_VERSION}" \
  /p:AssemblyVersion="${PACKAGE_VERSION}" \
  /p:FileVersion="${PACKAGE_VERSION}" \
  /p:InformationalVersion="${PACKAGE_VERSION}" \
  /p:PackageVersion="${PACKAGE_VERSION}" \
  "${PROJECT_FILE}" > /dev/null; then
  echo "::error::Failed to pack project '${PROJECT_FILE}'"
  exit 1
fi

SOURCE_FILE=$(find "${NUPKGS_DIR}" -name "*.nupkg" -type f -print -quit)

if [ -z "${SOURCE_FILE}" ]; then
  echo "::error::No .nupkg file found in ${NUPKGS_DIR}"
  exit 1
fi

if ! mv "${SOURCE_FILE}" "${PACKAGE_FILE}"; then
  echo "::error::Failed to rename '${SOURCE_FILE}' to '${PACKAGE_FILE}'"
  exit 1
fi

echo "::notice::✓ Successfully created package: ${PACKAGE_FILE}"

{
  echo "package=${PACKAGE_FILE}"

  echo "modified-files<<EOF"
  if [ ${#MODIFIED_FILES[@]} -gt 0 ]; then
    printf '%s\n' "${MODIFIED_FILES[@]}"
  fi
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
