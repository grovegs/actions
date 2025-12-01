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

FILE_SIZE=$(stat -f%z "${FILE}" 2>/dev/null || stat -c%s "${FILE}" 2>/dev/null || echo "0")
FILE_SIZE_MB=$((FILE_SIZE / 1048576))
echo "::notice::File size: ${FILE_SIZE_MB} MB"
echo "::notice::Executing Firebase distribution command"

MAX_RETRIES=3
RETRY_DELAY=60
ATTEMPT=0
FIREBASE_SUCCESS=false

while [ ${ATTEMPT} -le ${MAX_RETRIES} ]; do
  if [ ${ATTEMPT} -gt 0 ]; then
    echo "::notice::Retrying distribution (attempt ${ATTEMPT}/${MAX_RETRIES})..."
    echo "::notice::Waiting ${RETRY_DELAY} seconds for Firebase to process the release..."
    sleep ${RETRY_DELAY}
  fi

  OUTPUT_FILE=$(mktemp)
  if firebase "${FIREBASE_ARGS[@]}" > "${OUTPUT_FILE}" 2>&1; then
    FIREBASE_EXIT_CODE=0
  else
    FIREBASE_EXIT_CODE=$?
  fi

  cat "${OUTPUT_FILE}"

  if grep -q "added testers/groups successfully" "${OUTPUT_FILE}" 2>/dev/null || \
     grep -q "✔.*distribut.*successfully" "${OUTPUT_FILE}" 2>/dev/null; then
    echo "::notice::✓ Firebase distribution succeeded"
    FIREBASE_SUCCESS=true
    rm -f "${OUTPUT_FILE}"
    break
  fi

  if grep -q "HTTP Error: 404" "${OUTPUT_FILE}" 2>/dev/null; then
    if [ ${ATTEMPT} -lt ${MAX_RETRIES} ]; then
      echo "::warning::Release not yet available (404), will retry"
      ATTEMPT=$((ATTEMPT + 1))
      rm -f "${OUTPUT_FILE}"
      continue
    fi
  fi

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
    rm -f "${OUTPUT_FILE}"
    break
  fi

  if grep -qi "error:" "${OUTPUT_FILE}" 2>/dev/null; then
    echo "::warning::Firebase returned an error"
    ATTEMPT=$((ATTEMPT + 1))
    rm -f "${OUTPUT_FILE}"
  else
    echo "::warning::Firebase result unclear"
    ATTEMPT=$((ATTEMPT + 1))
    rm -f "${OUTPUT_FILE}"
  fi
done

if [ -n "${NOTES_FILE}" ]; then
  rm -f "${NOTES_FILE}"
fi

rm -f "${CREDENTIALS_FILE}"

if [ "${FIREBASE_SUCCESS}" = false ]; then
  echo "::error::Firebase distribution failed after $((MAX_RETRIES + 1)) attempts"
  echo "::notice::The release may have been uploaded but distribution to testers failed."
  echo "::notice::Check the Firebase Console to verify and manually distribute if needed."
  exit 1
fi

echo "::notice::✓ Firebase distribution completed successfully"
