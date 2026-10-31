#!/usr/bin/env bash

run_unity() {
  local log_file="$1"
  shift
  local timeout="${BUILD_TIMEOUT:-0}"
  local accelerator="${UNITY_ACCELERATOR:-}"
  local poll_interval=5
  local elapsed=0
  local exit_code=0
  local unity_pid
  local tail_pid
  local -a editor_args

  if [ -z "${timeout}" ]; then
    timeout=0
  fi

  case "${timeout}" in
    *[!0-9]*)
      echo "::error::BUILD_TIMEOUT must be a whole number of seconds, got '${timeout}'"
      return 1
      ;;
  esac

  editor_args=(
    -batchmode
    -quit
    -projectPath "${PROJECT_DIR}"
    -logFile "${log_file}"
  )

  if [ -n "${accelerator}" ]; then
    if [[ "${accelerator}" != *:* ]]; then
      accelerator="${accelerator}:10080"
    fi
    editor_args+=(-EnableCacheServer -cacheServerEndpoint "${accelerator}")
  fi

  : > "${log_file}"
  tail -n +1 -F "${log_file}" 2> /dev/null &
  tail_pid=$!

  set -m
  "${UNITY_EDITOR_PATH}" "${editor_args[@]}" "$@" &
  unity_pid=$!
  set +m

  while kill -0 "${unity_pid}" 2> /dev/null; do
    if [ "${timeout}" -gt 0 ] && [ "${elapsed}" -ge "${timeout}" ]; then
      echo "::error::Unity build did not finish within ${timeout} seconds and was stopped"
      kill -TERM -- "-${unity_pid}" 2> /dev/null || true
      sleep 10
      kill -KILL -- "-${unity_pid}" 2> /dev/null || true
      wait "${unity_pid}" 2> /dev/null || true
      kill "${tail_pid}" 2> /dev/null || true
      wait "${tail_pid}" 2> /dev/null || true
      return 124
    fi

    sleep "${poll_interval}"
    elapsed=$((elapsed + poll_interval))
  done

  wait "${unity_pid}" || exit_code=$?
  sleep 1
  kill "${tail_pid}" 2> /dev/null || true
  wait "${tail_pid}" 2> /dev/null || true
  return "${exit_code}"
}
