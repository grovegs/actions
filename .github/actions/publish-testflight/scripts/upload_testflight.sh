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

file_size=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo "unknown")
echo "::notice::Uploading IPA to TestFlight: ${file} (${file_size} bytes)"
echo "::notice::Using API Key ID: ${api_key_id}"

if ! xcrun altool --upload-app \
    --type ios \
    --file "${file}" \
    --apiKey "${api_key_id}" \
    --apiIssuer "${api_issuer_id}"; then
    echo "::error::TestFlight upload failed"
    exit 1
fi

echo "::notice::TestFlight upload completed successfully"
echo "::notice::The build will appear in App Store Connect after processing"