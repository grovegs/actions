#!/usr/bin/env bash
set -euo pipefail

if [ -z "${FILE:-}" ]; then
  echo "::error::FILE environment variable is required"
  exit 1
fi

if [ -z "${APP_ID:-}" ]; then
  echo "::error::APP_ID environment variable is required"
  exit 1
fi

if [ -z "${CREDENTIALS:-}" ]; then
  echo "::error::CREDENTIALS environment variable is required"
  exit 1
fi

if ! command -v firebase > /dev/null 2>&1; then
  echo "::error::firebase is not installed or not in PATH"
  exit 1
fi

if ! command -v base64 > /dev/null 2>&1; then
  echo "::error::base64 is not installed or not in PATH"
  exit 1
fi

if [ ! -f "${FILE}" ]; then
  echo "::error::Build file '${FILE}' does not exist"
  exit 1
fi

FIREBASE_DIR="${HOME}/.firebase"
CREDENTIALS_FILE="${FIREBASE_DIR}/credentials_file.json"

echo "::notice::Setting up Firebase credentials"
if ! mkdir -p "${FIREBASE_DIR}"; then
  echo "::error::Failed to create directory '${FIREBASE_DIR}'"
  exit 1
fi

if ! echo -n "${CREDENTIALS}" | base64 -d > "${CREDENTIALS_FILE}"; then
  echo "::error::Failed to decode and save the Firebase credentials"
  exit 1
fi

echo "::notice::Setting up Firebase distribution with app ID: ${APP_ID}"

export GOOGLE_APPLICATION_CREDENTIALS="${CREDENTIALS_FILE}"

declare -a FIREBASE_ARGS
FIREBASE_ARGS=(
  "appdistribution:distribute"
  "${FILE}"
  "--app"
  "${APP_ID}"
)

NOTES_FILE=""

if [ -n "${RELEASE_NOTES:-}" ]; then
  echo "::notice::Adding release notes to distribution"
  NOTES_FILE=$(mktemp)
  printf '%s' "${RELEASE_NOTES}" > "${NOTES_FILE}"
  FIREBASE_ARGS+=(
    "--release-notes-file"
    "${NOTES_FILE}"
  )
fi

if [ -n "${TESTER_GROUPS:-}" ]; then
  echo "::notice::Distributing to tester groups: ${TESTER_GROUPS}"
  FIREBASE_ARGS+=(
    "--groups"
    "${TESTER_GROUPS}"
  )
fi

echo "::notice::Executing Firebase distribution command"
if ! firebase "${FIREBASE_ARGS[@]}"; then
  if [ -n "${NOTES_FILE}" ]; then
    rm -f "${NOTES_FILE}"
  fi
  echo "::error::Firebase distribution failed"
  exit 1
fi

if [ -n "${NOTES_FILE}" ]; then
  rm -f "${NOTES_FILE}"
fi

echo "::notice::✓ Firebase distribution completed successfully"
