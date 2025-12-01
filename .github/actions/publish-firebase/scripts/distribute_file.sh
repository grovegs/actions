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

SECRETS_DIR="${RUNNER_TEMP}/secrets"
CREDENTIALS_FILE="${SECRETS_DIR}/firebase_credentials.json"

echo "::notice::Setting up Firebase credentials"
if ! mkdir -p "${SECRETS_DIR}"; then
  echo "::error::Failed to create directory '${SECRETS_DIR}'"
  exit 1
fi

if ! echo -n "${CREDENTIALS}" | base64 -d > "${CREDENTIALS_FILE}"; then
  echo "::error::Failed to decode and save the Firebase credentials"
  exit 1
fi

SERVICE_ACCOUNT="unknown"
if command -v jq > /dev/null 2>&1; then
  SERVICE_ACCOUNT=$(jq -r '.client_email // "unknown"' "${CREDENTIALS_FILE}" 2>/dev/null || echo "unknown")
  echo "::notice::Using service account: ${SERVICE_ACCOUNT}"
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

OUTPUT_FILE=$(mktemp)
if firebase "${FIREBASE_ARGS[@]}" > "${OUTPUT_FILE}" 2>&1; then
  FIREBASE_EXIT_CODE=0
else
  FIREBASE_EXIT_CODE=$?
fi

cat "${OUTPUT_FILE}"

FIREBASE_FAILED=false
if [ ${FIREBASE_EXIT_CODE} -ne 0 ]; then
  FIREBASE_FAILED=true
elif grep -qi "error:" "${OUTPUT_FILE}"; then
  FIREBASE_FAILED=true
elif grep -qi "HTTP Error:" "${OUTPUT_FILE}"; then
  FIREBASE_FAILED=true
fi

if [ "${FIREBASE_FAILED}" = true ]; then
  if [ -n "${NOTES_FILE}" ]; then
    rm -f "${NOTES_FILE}"
  fi

  echo "::error::Firebase distribution failed"

  if grep -q "HTTP Error: 403" "${OUTPUT_FILE}" 2>/dev/null; then
    echo "::error::Permission denied (403 Forbidden)"
    echo "::notice::The service account '${SERVICE_ACCOUNT}' needs the following role:"
    echo "::notice::  - Firebase App Distribution Admin (roles/firebaseappdistro.admin)"
    echo "::notice::"
    echo "::notice::To fix this:"
    echo "::notice::  1. Go to https://console.cloud.google.com/iam-admin/iam"
    echo "::notice::  2. Find: ${SERVICE_ACCOUNT}"
    echo "::notice::  3. Click Edit (pencil icon)"
    echo "::notice::  4. Add Role: Firebase App Distribution Admin"
    echo "::notice::  5. Save and retry the build"
  fi

  rm -f "${CREDENTIALS_FILE}"
  rm -f "${OUTPUT_FILE}"

  exit 1
fi

rm -f "${OUTPUT_FILE}"

if [ -n "${NOTES_FILE}" ]; then
  rm -f "${NOTES_FILE}"
fi

rm -f "${CREDENTIALS_FILE}"

echo "::notice::✓ Firebase distribution completed successfully"
