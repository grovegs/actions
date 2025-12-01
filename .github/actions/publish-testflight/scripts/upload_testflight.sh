#!/usr/bin/env bash
set -euo pipefail

if [ -z "${FILE:-}" ]; then
  echo "::error::FILE environment variable is required"
  exit 1
fi

if [ -z "${API_KEY:-}" ]; then
  echo "::error::API_KEY environment variable is required"
  exit 1
fi

if [ -z "${API_KEY_ID:-}" ]; then
  echo "::error::API_KEY_ID environment variable is required"
  exit 1
fi

if [ -z "${API_ISSUER_ID:-}" ]; then
  echo "::error::API_ISSUER_ID environment variable is required"
  exit 1
fi

if ! command -v xcrun > /dev/null 2>&1; then
  echo "::error::xcrun is not installed or not in PATH"
  exit 1
fi

if ! command -v base64 > /dev/null 2>&1; then
  echo "::error::base64 is not installed or not in PATH"
  exit 1
fi

if [ ! -f "${FILE}" ]; then
  echo "::error::IPA file not found: ${FILE}"
  exit 1
fi

PRIVATE_KEYS_DIR="${HOME}/.appstoreconnect/private_keys"
API_KEY_FILE="${PRIVATE_KEYS_DIR}/AuthKey_${API_KEY_ID}.p8"

cleanup() {
  if [ -f "${API_KEY_FILE}" ]; then
    echo "::notice::Cleaning up temporary files"
    rm -f "${API_KEY_FILE}"
  fi
}
trap cleanup EXIT

echo "::notice::Setting up App Store Connect API authentication"
if ! mkdir -p "${PRIVATE_KEYS_DIR}"; then
  echo "::error::Failed to create directory '${PRIVATE_KEYS_DIR}'"
  exit 1
fi

if ! echo -n "${API_KEY}" | base64 -d > "${API_KEY_FILE}"; then
  echo "::error::Failed to decode API private key"
  exit 1
fi

chmod 600 "${API_KEY_FILE}"

FILE_SIZE=$(stat -f%z "${FILE}" 2>/dev/null || stat -c%s "${FILE}" 2>/dev/null || echo "unknown")
FILE_SIZE_MB=$((FILE_SIZE / 1048576))
echo "::notice::File size: ${FILE_SIZE_MB} MB"
echo "::notice::Uploading IPA to TestFlight: ${FILE}"
echo "::notice::Using API Key ID: ${API_KEY_ID}"

MAX_RETRIES=3
RETRY_DELAY=60
ATTEMPT=0
SUCCESS=false

while [ ${ATTEMPT} -le ${MAX_RETRIES} ]; do
  if [ ${ATTEMPT} -gt 0 ]; then
    echo "::notice::Retrying upload (attempt ${ATTEMPT}/${MAX_RETRIES})..."
    echo "::notice::Waiting ${RETRY_DELAY} seconds..."
    sleep ${RETRY_DELAY}
  fi

  OUTPUT=$(mktemp)
  if xcrun altool --upload-app \
    --type ios \
    --file "${FILE}" \
    --apiKey "${API_KEY_ID}" \
    --apiIssuer "${API_ISSUER_ID}" > "${OUTPUT}" 2>&1; then
    echo "::notice::✓ TestFlight upload succeeded"
    SUCCESS=true
    rm -f "${OUTPUT}"
    break
  fi

  cat "${OUTPUT}"

  if grep -q "500.*Internal Server Error" "${OUTPUT}" 2>/dev/null || \
     grep -q "503.*Service Unavailable" "${OUTPUT}" 2>/dev/null || \
     grep -q "502.*Bad Gateway" "${OUTPUT}" 2>/dev/null || \
     grep -q "504.*Gateway Timeout" "${OUTPUT}" 2>/dev/null || \
     grep -q "timeout" "${OUTPUT}" 2>/dev/null || \
     grep -q "network.*error" "${OUTPUT}" 2>/dev/null; then
    if [ ${ATTEMPT} -lt ${MAX_RETRIES} ]; then
      echo "::warning::Temporary server error, will retry"
      ATTEMPT=$((ATTEMPT + 1))
      rm -f "${OUTPUT}"
      continue
    fi
  fi

  if grep -q "Invalid credentials" "${OUTPUT}" 2>/dev/null || \
     grep -q "not found" "${OUTPUT}" 2>/dev/null || \
     grep -q "Bundle ID" "${OUTPUT}" 2>/dev/null; then
    echo "::error::Non-retryable error detected"
    echo "::error::Common causes:"
    echo "::error::  - Invalid API credentials"
    echo "::error::  - App record not found in App Store Connect"
    echo "::error::  - Bundle ID mismatch"
    echo "::error::  - Invalid provisioning profile"
    rm -f "${OUTPUT}"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  rm -f "${OUTPUT}"
done

if [ "${SUCCESS}" = false ]; then
  echo "::error::TestFlight upload failed after $((MAX_RETRIES + 1)) attempts"
  echo "::notice::Suggestions:"
  echo "::notice::  1. Check Apple's System Status: https://developer.apple.com/system-status/"
  echo "::notice::  2. Verify API credentials are correct"
  echo "::notice::  3. Try uploading manually using Xcode"
  exit 1
fi

echo "::notice::✓ TestFlight upload completed successfully"
echo "::notice::The build will appear in App Store Connect after processing (usually 5-15 minutes)"
