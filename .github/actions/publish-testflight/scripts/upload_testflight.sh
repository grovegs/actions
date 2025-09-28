#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "::error::Usage: $0 <file> <api_key> <api_key_id> <api_issuer_id>"
  exit 1
fi

file="$1"
api_key="$2"
api_key_id="$3"
api_issuer_id="$4"

private_keys_dir="${HOME}/.appstoreconnect/private_keys"
api_key_file="${private_keys_dir}/AuthKey_${api_key_id}.p8"

cleanup() {
  echo "::notice::Cleaning up temporary files..."
  rm -f "${api_key_file}" || true
}
trap cleanup EXIT

if [ ! -f "${file}" ]; then
  echo "::error::IPA file not found: ${file}"
  exit 1
fi

if [ -z "${api_key_id}" ] || [ -z "${api_issuer_id}" ] || [ -z "${api_key}" ]; then
  echo "::error::API key credentials are required"
  exit 1
fi

echo "::notice::Setting up App Store Connect API authentication"
mkdir -p "${private_keys_dir}"
if ! echo -n "${api_key}" | base64 -d > "${api_key_file}"; then
  echo "::error::Failed to decode API private key"
  exit 1
fi

chmod 600 "${api_key_file}"

file_size=$(stat -f%z "${file}" 2> /dev/null || stat -c%s "${file}" 2> /dev/null || echo "unknown")
echo "::notice::Uploading IPA to TestFlight: ${file} (${file_size} bytes)"
echo "::notice::Using API Key ID: ${api_key_id}"

is_retryable_error() {
  local exit_code=$1
  local output="$2"

  if echo "$output" | grep -q "500.*Internal Server Error"; then
    return 0
  fi
  if echo "$output" | grep -q "503.*Service Unavailable"; then
    return 0
  fi
  if echo "$output" | grep -q "502.*Bad Gateway"; then
    return 0
  fi
  if echo "$output" | grep -q "504.*Gateway Timeout"; then
    return 0
  fi
  if echo "$output" | grep -q "timeout"; then
    return 0
  fi
  if echo "$output" | grep -q "network.*error"; then
    return 0
  fi

  return 1
}

max_attempts=5
attempt=1
success=false

while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
  if [ $attempt -gt 1 ]; then
    wait_time=$((attempt * 30))
    echo "::notice::Attempt $attempt/$max_attempts - waiting ${wait_time}s before retry..."
    sleep $wait_time
  else
    echo "::notice::Attempt $attempt/$max_attempts - starting upload..."
  fi

  output=$(xcrun altool --upload-app \
    --type ios \
    --file "${file}" \
    --apiKey "${api_key_id}" \
    --apiIssuer "${api_issuer_id}" 2>&1)

  exit_code=$?

  if [ $exit_code -eq 0 ]; then
    echo "::notice::✅ TestFlight upload completed successfully!"
    echo "::notice::The build will appear in App Store Connect after processing (usually 5-15 minutes)"
    success=true
  else
    echo "::warning::❌ Upload attempt $attempt failed with exit code $exit_code"
    echo "::warning::Error output:"
    echo "$output"

    if is_retryable_error $exit_code "$output"; then
      if [ $attempt -lt $max_attempts ]; then
        echo "::notice::🔄 This appears to be a temporary server error. Will retry..."
      else
        echo "::error::💀 Maximum retry attempts reached. This appears to be a persistent server issue."
        echo "::error::Suggestions:"
        echo "::error::1. Check Apple's System Status: https://developer.apple.com/system-status/"
        echo "::error::2. Try uploading manually using Xcode or Application Loader"
        echo "::error::3. Wait 10-30 minutes and re-run the workflow"
        echo "::error::4. Contact Apple Developer Support if the issue persists"
      fi
    else
      echo "::error::💀 Non-retryable error detected. This requires manual intervention."
      echo "::error::Common causes:"
      echo "::error::- Invalid API credentials"
      echo "::error::- App record not found in App Store Connect"
      echo "::error::- Bundle ID mismatch"
      echo "::error::- Invalid provisioning profile"
      echo "::error::- Missing required app metadata"
      break
    fi
  fi

  attempt=$((attempt + 1))
done

if [ "$success" = false ]; then
  echo "::error::TestFlight upload failed after $max_attempts attempts"
  exit 1
fi
