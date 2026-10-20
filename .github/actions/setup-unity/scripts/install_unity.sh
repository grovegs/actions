#!/usr/bin/env bash
set -euo pipefail

if [ -z "${UNITY_VERSION:-}" ]; then
  echo "::error::UNITY_VERSION environment variable is required"
  exit 1
fi

if [ -z "${UNITY_CHANGESET:-}" ]; then
  echo "::error::UNITY_CHANGESET environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

if ! command -v unity > /dev/null 2>&1; then
  echo "::error::Unity CLI is not installed or not in PATH"
  exit 1
fi

export UNITY_NON_INTERACTIVE=1
export UNITY_NO_BANNER=1
export UNITY_NO_UPDATE_CHECK=1

UNITY_PATH_INPUT="${UNITY_PATH:-}"
UNITY_PATH_INPUT="${UNITY_PATH_INPUT/#\~/$HOME}"
UNITY_MODULES="${UNITY_MODULES:-}"
UNITY_CHILD_MODULES="${UNITY_CHILD_MODULES:-false}"
PREVIOUS_INSTALL_PATH=""

declare -a MODULE_ARGS
MODULE_ARGS=()
IFS=',' read -ra MODULE_ARRAY <<< "${UNITY_MODULES}"
for module in ${MODULE_ARRAY[@]+"${MODULE_ARRAY[@]}"}; do
  module_trimmed=$(echo "${module}" | xargs)
  if [ -n "${module_trimmed}" ]; then
    MODULE_ARGS+=(--module "${module_trimmed}")
  fi
done

declare -a CHILD_MODULE_ARGS
if [ "${UNITY_CHILD_MODULES}" = "true" ]; then
  CHILD_MODULE_ARGS=(--child-modules)
else
  CHILD_MODULE_ARGS=(--no-child-modules)
fi

get_editor_executable() {
  local editor_dir="$1"

  case "${RUNNER_OS}" in
    "macOS") echo "${editor_dir}/Unity.app/Contents/MacOS/Unity" ;;
    "Linux") echo "${editor_dir}/Editor/Unity" ;;
  esac
}

get_editor_bundle() {
  local editor_dir="$1"

  case "${RUNNER_OS}" in
    "macOS") echo "${editor_dir}/Unity.app" ;;
    "Linux") echo "${editor_dir}/Editor/Unity" ;;
  esac
}

get_unregistered_editor_dirs() {
  if [ -n "${UNITY_PATH_INPUT}" ]; then
    echo "${UNITY_PATH_INPUT}/${UNITY_VERSION}"
    return 0
  fi

  local cli_install_path
  cli_install_path=$(unity install-path --get --quiet 2> /dev/null || echo "")
  if [ -n "${cli_install_path}" ]; then
    echo "${cli_install_path}/${UNITY_VERSION}"
  fi

  case "${RUNNER_OS}" in
    "macOS") echo "/Applications/Unity/Editor/${UNITY_VERSION}" ;;
    "Linux") echo "${HOME}/Unity/Editor/${UNITY_VERSION}" ;;
  esac
}

find_registered_editor() {
  unity editors path "${UNITY_VERSION}" --quiet 2> /dev/null || true
}

restore_install_path() {
  if [ -n "${PREVIOUS_INSTALL_PATH}" ]; then
    unity install-path --set "${PREVIOUS_INSTALL_PATH}" --quiet || true
  fi
}
trap restore_install_path EXIT

install_editor() {
  if [ -n "${UNITY_PATH_INPUT}" ]; then
    PREVIOUS_INSTALL_PATH=$(unity install-path --get --quiet 2> /dev/null || echo "")
    mkdir -p "${UNITY_PATH_INPUT}"
    unity install-path --set "${UNITY_PATH_INPUT}" --quiet
    echo "::notice::Installing into custom directory: ${UNITY_PATH_INPUT}"
  fi

  echo "::notice::Installing Unity ${UNITY_VERSION} (${UNITY_CHANGESET}) ${UNITY_MODULES:+with modules: ${UNITY_MODULES}}"

  if ! unity install "${UNITY_VERSION}" \
    --changeset "${UNITY_CHANGESET}" \
    ${MODULE_ARGS[@]+"${MODULE_ARGS[@]}"} \
    "${CHILD_MODULE_ARGS[@]}" \
    --yes \
    --accept-eula; then
    echo "::error::Failed to install Unity ${UNITY_VERSION}"
    exit 1
  fi
}

install_missing_modules() {
  if [ "${#MODULE_ARGS[@]}" -eq 0 ]; then
    return 0
  fi

  local installed_modules
  installed_modules=$(unity modules list "${UNITY_VERSION}" --format tsv 2> /dev/null | awk -F'\t' '$4 == "Installed" { print $1 }')

  local -a missing_args
  missing_args=()
  local module_trimmed
  for module in ${MODULE_ARRAY[@]+"${MODULE_ARRAY[@]}"}; do
    module_trimmed=$(echo "${module}" | xargs)
    if [ -z "${module_trimmed}" ]; then
      continue
    fi

    if echo "${installed_modules}" | grep -qx "${module_trimmed}"; then
      echo "::notice::✅ Module already installed: ${module_trimmed}"
    else
      missing_args+=(--module "${module_trimmed}")
    fi
  done

  if [ "${#missing_args[@]}" -eq 0 ]; then
    return 0
  fi

  echo "::notice::Installing missing modules: ${missing_args[*]}"

  if ! unity install-modules \
    --editor-version "${UNITY_VERSION}" \
    "${missing_args[@]}" \
    "${CHILD_MODULE_ARGS[@]}" \
    --yes \
    --accept-eula; then
    echo "::error::Failed to install modules for Unity ${UNITY_VERSION}: ${UNITY_MODULES}"
    exit 1
  fi
}

echo "::notice::Unity CLI $(unity --version)"

EDITOR_DIR=$(find_registered_editor)

if [ -z "${EDITOR_DIR}" ]; then
  while IFS= read -r candidate_dir; do
    if [ ! -x "$(get_editor_executable "${candidate_dir}")" ]; then
      continue
    fi

    echo "::notice::Registering existing Unity installation: ${candidate_dir}"
    if unity editors add "$(get_editor_bundle "${candidate_dir}")" --quiet < /dev/null; then
      EDITOR_DIR=$(find_registered_editor)
      break
    fi
    echo "::warning::Could not register ${candidate_dir}"
  done < <(get_unregistered_editor_dirs)
fi

if [ -n "${EDITOR_DIR}" ]; then
  echo "::notice::✅ Unity ${UNITY_VERSION} already installed at ${EDITOR_DIR}"
  install_missing_modules
else
  install_editor
  EDITOR_DIR=$(find_registered_editor)
fi

if [ -z "${EDITOR_DIR}" ]; then
  echo "::error::Unity ${UNITY_VERSION} is not registered with the Unity CLI after installation"
  exit 1
fi

UNITY_EXECUTABLE=$(get_editor_executable "${EDITOR_DIR}")

if [ ! -x "${UNITY_EXECUTABLE}" ]; then
  echo "::error::Unity executable not found: ${UNITY_EXECUTABLE}"
  exit 1
fi

{
  echo "UNITY_PATH=${EDITOR_DIR}"
  echo "UNITY_EXECUTABLE=${UNITY_EXECUTABLE}"
} >> "${GITHUB_ENV}"

{
  echo "unity-path=${EDITOR_DIR}"
  echo "unity-executable=${UNITY_EXECUTABLE}"
} >> "${GITHUB_OUTPUT}"

echo "::notice::Unity ${UNITY_VERSION} ready at ${EDITOR_DIR}"
