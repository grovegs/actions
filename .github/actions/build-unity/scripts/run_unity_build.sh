#!/usr/bin/env bash

UNITY_CLI_PID=""

quote_unity_argument() {
  local value="$1"
  local quote="'"
  local escaped="'\\''"

  printf "'%s'" "${value//${quote}/${escaped}}"
}

stop_unity_build() {
  local signal="$1"

  trap - INT TERM

  if [ -n "${UNITY_CLI_PID}" ] && kill -0 "${UNITY_CLI_PID}" 2> /dev/null; then
    echo "::warning::Cancelled. Stopping the Unity CLI and the editor it started"
    kill "-${signal}" "${UNITY_CLI_PID}" 2> /dev/null || true
    wait "${UNITY_CLI_PID}" 2> /dev/null || true
  fi

  if [ "${signal}" = "INT" ]; then
    exit 130
  fi

  exit 143
}

run_unity_build() {
  local target="$1"
  local method="$2"
  local log_file="$3"
  shift 3
  local timeout="${BUILD_TIMEOUT:-0}"
  local editor_path="${UNITY_EDITOR_PATH}"
  local editor_args=""
  local exit_code=0
  local argument
  local -a cli_args

  if [ -z "${timeout}" ]; then
    timeout=0
  fi

  case "${timeout}" in
    *[!0-9]*)
      echo "::error::BUILD_TIMEOUT must be a whole number of seconds, got '${timeout}'"
      return 1
      ;;
  esac

  if ! command -v unity > /dev/null 2>&1; then
    echo "::error::Unity CLI is not installed. Run setup-unity before build-unity"
    return 1
  fi

  echo "editor-path=${UNITY_EDITOR_PATH}" >> "${GITHUB_OUTPUT}"

  editor_path="${editor_path%/Contents/MacOS/Unity}"

  cli_args=(
    --target "${target}"
    --execute-method "${method}"
    --editor-path "${editor_path}"
    --log-file "${log_file}"
    --allow-dirty-build
    --non-interactive
    --no-banner
  )

  if [ "${timeout}" -gt 0 ]; then
    cli_args+=(--timeout "${timeout}")
  fi

  if [ -n "${UNITY_ACCELERATOR:-}" ]; then
    cli_args+=(--accelerator "${UNITY_ACCELERATOR}")
  fi

  if [ -n "${BUILD_PROVENANCE_FILE:-}" ]; then
    cli_args+=(--provenance-path "${BUILD_PROVENANCE_FILE}")
  else
    cli_args+=(--no-provenance)
  fi

  for argument in "$@"; do
    editor_args="${editor_args}${editor_args:+ }$(quote_unity_argument "${argument}")"
  done

  trap 'stop_unity_build INT' INT
  trap 'stop_unity_build TERM' TERM

  unity build "${PROJECT_DIR}" "${cli_args[@]}" --args "${editor_args}" &
  UNITY_CLI_PID=$!

  wait "${UNITY_CLI_PID}" || exit_code=$?
  UNITY_CLI_PID=""

  trap - INT TERM

  if [ "${exit_code}" -eq 14 ]; then
    echo "::error::Unity build did not finish within ${timeout} seconds and was stopped"
  fi

  return "${exit_code}"
}
