#!/usr/bin/env bash

run_unity_tests() {
  local log_file="$1"
  shift
  local timeout="${TEST_TIMEOUT:-0}"
  local poll_interval=5
  local elapsed=0
  local exit_code=0
  local unity_pid
  local tail_pid

  if [ -z "${timeout}" ]; then
    timeout=0
  fi

  case "${timeout}" in
    *[!0-9]*)
      echo "::error::TEST_TIMEOUT must be a whole number of seconds, got '${timeout}'"
      return 1
      ;;
  esac

  : > "${log_file}"
  tail -n +1 -F "${log_file}" 2> /dev/null &
  tail_pid=$!

  set -m
  "${UNITY_EDITOR_EXECUTABLE}" \
    -batchmode \
    -projectPath "${PROJECT_DIR}" \
    -logFile "${log_file}" \
    "$@" &
  unity_pid=$!
  set +m

  while kill -0 "${unity_pid}" 2> /dev/null; do
    if [ "${timeout}" -gt 0 ] && [ "${elapsed}" -ge "${timeout}" ]; then
      echo "::error::Unity tests did not finish within ${timeout} seconds and were stopped"
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
