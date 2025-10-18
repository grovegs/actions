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

FILE_SIZE=$(stat -f%z "${FILE}" 2> /dev/null || stat -c%s "${FILE}" 2> /dev/null || echo "unknown")
echo "::notice::Uploading IPA to TestFlight: ${FILE} (${FILE_SIZE} bytes)"
echo "::notice::Using API Key ID: ${API_KEY_ID}"

is_retryable_error() {
  local output="$1"

  if echo "${output}" | grep -q "500.*Internal Server Error"; then
    return 0
  fi
  if echo "${output}" | grep -q "503.*Service Unavailable"; then
    return 0
  fi
  if echo "${output}" | grep -q "502.*Bad Gateway"; then
    return 0
  fi
  if echo "${output}" | grep -q "504.*Gateway Timeout"; then
    return 0
  fi
  if echo "${output}" | grep -q "timeout"; then
    return 0
  fi
  if echo "${output}" | grep -q "network.*error"; then
    return 0
  fi

  return 1
}

MAX_ATTEMPTS="${MAX_RETRIES:-5}"
ATTEMPT=1
SUCCESS=false

while [ "${ATTEMPT}" -le "${MAX_ATTEMPTS}" ] && [ "${SUCCESS}" = "false" ]; do
  if [ "${ATTEMPT}" -gt 1 ]; then
    WAIT_TIME=$((ATTEMPT * 30))
    echo "::notice::Attempt ${ATTEMPT}/${MAX_ATTEMPTS} - waiting ${WAIT_TIME}s before retry"
    sleep "${WAIT_TIME}"
  else
    echo "::notice::Attempt ${ATTEMPT}/${MAX_ATTEMPTS} - starting upload"
  fi

  set +e
  OUTPUT=$(xcrun altool --upload-app \
    --type ios \
    --file "${FILE}" \
    --apiKey "${API_KEY_ID}" \
    --apiIssuer "${API_ISSUER_ID}" 2>&1)
  EXIT_CODE=$?
  set -e

  if [ "${EXIT_CODE}" -eq 0 ]; then
    echo "::notice::✅ TestFlight upload completed successfully"
    echo "::notice::The build will appear in App Store Connect after processing (usually 5-15 minutes)"
    SUCCESS=true
  else
    echo "::warning::❌ Upload attempt ${ATTEMPT} failed with exit code ${EXIT_CODE}"
    echo "::warning::Error output:"
    echo "${OUTPUT}"

    if is_retryable_error "${OUTPUT}"; then
      if [ "${ATTEMPT}" -lt "${MAX_ATTEMPTS}" ]; then
        echo "::notice::🔄 This appears to be a temporary server error. Will retry"
      else
        echo "::error::💀 Maximum retry attempts reached. This appears to be a persistent server issue"
        echo "::error::Suggestions:"
        echo "::error::1. Check Apple's System Status: https://developer.apple.com/system-status/"
        echo "::error::2. Try uploading manually using Xcode or Application Loader"
        echo "::error::3. Wait 10-30 minutes and re-run the workflow"
        echo "::error::4. Contact Apple Developer Support if the issue persists"
      fi
    else
      echo "::error::💀 Non-retryable error detected. This requires manual intervention"
      echo "::error::Common causes:"
      echo "::error::- Invalid API credentials"
      echo "::error::- App record not found in App Store Connect"
      echo "::error::- Bundle ID mismatch"
      echo "::error::- Invalid provisioning profile"
      echo "::error::- Missing required app metadata"
      break
    fi
  fi

  ATTEMPT=$((ATTEMPT + 1))
done

if [ "${SUCCESS}" = "false" ]; then
  echo "::error::TestFlight upload failed after ${MAX_ATTEMPTS} attempts"
  exit 1
fi
