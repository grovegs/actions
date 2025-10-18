#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${VERSION:-}" ]; then
  echo "::error::VERSION environment variable is required"
  exit 1
fi

if [ -z "${CONFIGURATION:-}" ]; then
  echo "::error::CONFIGURATION environment variable is required"
  exit 1
fi

if [ -z "${FILENAME:-}" ]; then
  echo "::error::FILENAME environment variable is required"
  exit 1
fi

if [ -z "${UNITY_EMAIL:-}" ]; then
  echo "::error::UNITY_EMAIL environment variable is required"
  exit 1
fi

if [ -z "${UNITY_PASSWORD:-}" ]; then
  echo "::error::UNITY_PASSWORD environment variable is required"
  exit 1
fi

if [ -z "${UNITY_LICENSE_KEY:-}" ]; then
  echo "::error::UNITY_LICENSE_KEY environment variable is required"
  exit 1
fi

if [ -z "${IOS_TEAM_ID:-}" ]; then
  echo "::error::IOS_TEAM_ID is required for iOS builds"
  exit 1
fi

if [ -z "${IOS_CERTIFICATE:-}" ]; then
  echo "::error::IOS_CERTIFICATE is required for iOS builds"
  exit 1
fi

if [ -z "${IOS_CERTIFICATE_PASSWORD:-}" ]; then
  echo "::error::IOS_CERTIFICATE_PASSWORD is required for iOS builds"
  exit 1
fi

if [ -z "${IOS_PROVISIONING_PROFILE:-}" ]; then
  echo "::error::IOS_PROVISIONING_PROFILE is required for iOS builds"
  exit 1
fi

if [ -z "${IOS_PROVISIONING_PROFILE_UUID:-}" ]; then
  echo "::error::IOS_PROVISIONING_PROFILE_UUID is required for iOS builds"
  exit 1
fi

if [ -z "${IOS_EXPORT_METHOD:-}" ]; then
  echo "::error::IOS_EXPORT_METHOD is required for iOS builds"
  exit 1
fi

if [[ ! "${IOS_EXPORT_METHOD}" =~ ^(ad-hoc|app-store|development|enterprise)$ ]]; then
  echo "::error::Invalid ios-export-method: ${IOS_EXPORT_METHOD}. Supported values: ad-hoc, app-store, development, enterprise"
  exit 1
fi

if [[ ! "${IOS_TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "::warning::iOS Team ID format appears invalid. Expected 10 uppercase alphanumeric characters."
fi

if [[ ! "${IOS_PROVISIONING_PROFILE_UUID}" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]; then
  echo "::warning::iOS provisioning profile UUID format appears invalid. Expected UUID format."
fi

if [[ "${PROJECT_DIR}" != /* ]]; then
  PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"
fi

BUILDS_DIR="${HOME}/.builds/ios"
XCODE_PROJECT_DIR="${BUILDS_DIR}/${FILENAME}"
ARCHIVE_PATH="${BUILDS_DIR}/${FILENAME}.xcarchive"
EXPORT_PATH="${BUILDS_DIR}/${FILENAME}.ipa"
EXPORT_OPTIONS_PLIST="${BUILDS_DIR}/export.plist"
KEYCHAIN_FILE="${RUNNER_TEMP}/ios.keychain-db"
CERTIFICATE_FILE="${RUNNER_TEMP}/ios.p12"
PROVISIONING_FILE="${RUNNER_TEMP}/profile.mobileprovision"

cleanup() {
  echo "::notice::Cleaning up sensitive files..."
  security delete-keychain "${KEYCHAIN_FILE}" 2>/dev/null || true
  rm -f "${CERTIFICATE_FILE}" "${PROVISIONING_FILE}" "${EXPORT_OPTIONS_PLIST}" || true
}
trap cleanup EXIT

echo "::notice::Creating build directories..."
mkdir -p "${BUILDS_DIR}"
mkdir -p "${XCODE_PROJECT_DIR}"

{
  echo "::notice::Build configuration:"
  echo "::notice::  Project: ${PROJECT_DIR}"
  echo "::notice::  Version: ${VERSION}"
  echo "::notice::  Configuration: ${CONFIGURATION}"
  echo "::notice::  Output: ${XCODE_PROJECT_DIR}"
  echo "::notice::  Profile: ${PROFILE_NAME:-default}"
  echo "::notice::  Team ID: ${IOS_TEAM_ID}"
  echo "::notice::  Export Method: ${IOS_EXPORT_METHOD}"
} >&2

if [ -n "${BUILD_METHOD:-}" ]; then
  echo "::notice::Using custom build method: ${BUILD_METHOD}"
  BUILD_METHOD_ARGS=("-executeMethod" "${BUILD_METHOD}")
else
  echo "::notice::Using default build method: BuildiOS.Build"
  BUILD_SCRIPT_DEST="${PROJECT_DIR}/Assets/Editor/BuildiOS.cs"
  mkdir -p "${PROJECT_DIR}/Assets/Editor"

  if [ -f "${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs" ]; then
    cp "${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs" "${BUILD_SCRIPT_DEST}"
    echo "::notice::Copied BuildiOS.cs to ${BUILD_SCRIPT_DEST}"
  else
    echo "::error::Build script not found: ${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs"
    exit 1
  fi

  BUILD_METHOD_ARGS=("-executeMethod" "BuildiOS.Build")
fi

BUILD_ARGS=(
  -batchmode
  -nographics
  -quit
  -username "${UNITY_EMAIL}"
  -password "${UNITY_PASSWORD}"
  -serial "${UNITY_LICENSE_KEY}"
  -projectPath "${PROJECT_DIR}"
  -buildTarget iOS
  -logFile -
  "${BUILD_METHOD_ARGS[@]}"
  -outputPath "${XCODE_PROJECT_DIR}"
  -versionName "${VERSION}"
  -buildConfig "${CONFIGURATION}"
  -profileId "${IOS_PROVISIONING_PROFILE_UUID}"
  -teamId "${IOS_TEAM_ID}"
  -profileName "${PROFILE_NAME:-iOS}"
)

echo "::notice::Starting Unity build..."
if ! unity "${BUILD_ARGS[@]}" 2>&1; then
  echo "::error::Unity build failed for iOS"
  exit 1
fi

echo "::notice::Unity build completed successfully"

echo "::notice::Looking for Xcode workspace..."
XCWORKSPACE_FILE=$(find "${XCODE_PROJECT_DIR}" -maxdepth 1 -name "*.xcworkspace" -type d | head -1)

if [ -z "${XCWORKSPACE_FILE}" ]; then
  echo "::error::No Xcode workspace found in ${XCODE_PROJECT_DIR}"
  echo "::debug::Contents of ${XCODE_PROJECT_DIR}:"
  ls -la "${XCODE_PROJECT_DIR}"
  echo "::debug::Unity should generate a .xcworkspace file for iOS builds"
  exit 1
fi

WORKSPACE_NAME=$(basename "${XCWORKSPACE_FILE}")
SCHEME_NAME="${WORKSPACE_NAME%.*}"
echo "::notice::Found Xcode workspace: ${WORKSPACE_NAME}"
echo "::notice::Using scheme: ${SCHEME_NAME}"

xcodebuild -workspace "${XCWORKSPACE_FILE}" -list 2>/dev/null || echo "::debug::Could not list schemes"

echo "::notice::Setting up iOS signing..."
KEYCHAIN_PASSWORD=$(openssl rand -base64 32)

echo -n "${IOS_CERTIFICATE}" | base64 -d > "${CERTIFICATE_FILE}"
echo -n "${IOS_PROVISIONING_PROFILE}" | base64 -d > "${PROVISIONING_FILE}"

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_FILE}"
security set-keychain-settings -lut 3600 "${KEYCHAIN_FILE}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_FILE}"
security list-keychains -d user -s "${KEYCHAIN_FILE}"
security import "${CERTIFICATE_FILE}" -k "${KEYCHAIN_FILE}" -P "${IOS_CERTIFICATE_PASSWORD}" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_FILE}"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "${PROVISIONING_FILE}" "$HOME/Library/MobileDevice/Provisioning Profiles/${IOS_PROVISIONING_PROFILE_UUID}.mobileprovision"

echo "::notice::Building and archiving iOS project..."

if ! xcodebuild -workspace "${XCWORKSPACE_FILE}" \
  -scheme "${SCHEME_NAME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=iOS" \
  -archivePath "${ARCHIVE_PATH}" \
  archive \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="${IOS_TEAM_ID}" \
  PROVISIONING_PROFILE_SPECIFIER="${IOS_PROVISIONING_PROFILE_UUID}"; then
  echo "::error::Xcode archive failed"
  exit 1
fi

echo "::notice::Archive created successfully at ${ARCHIVE_PATH}"

echo "::notice::Creating export options plist..."

BUNDLE_ID=""
if [ -d "${ARCHIVE_PATH}" ]; then
  BUNDLE_ID=$(defaults read "${ARCHIVE_PATH}/Info.plist" ApplicationProperties 2>/dev/null | grep -o 'CFBundleIdentifier = "[^"]*"' | cut -d'"' -f2 | head -1)
fi

if [ -z "${BUNDLE_ID}" ]; then
  XCODEPROJ_FILE=$(find "${XCODE_PROJECT_DIR}" -maxdepth 1 -name "*.xcodeproj" -type d | head -1)
  if [ -n "${XCODEPROJ_FILE}" ]; then
    BUNDLE_ID=$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' "${XCODEPROJ_FILE}/project.pbxproj" | head -1 | cut -d' ' -f3 | tr -d '"')
  fi
fi

if [ -z "${BUNDLE_ID}" ]; then
  echo "::error::Could not extract bundle ID from archive or project"
  exit 1
fi

echo "::notice::Using bundle ID: ${BUNDLE_ID}"
echo "::notice::Using provisioning profile UUID: ${IOS_PROVISIONING_PROFILE_UUID}"

cat > "${EXPORT_OPTIONS_PLIST}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${IOS_EXPORT_METHOD}</string>
    <key>teamID</key>
    <string>${IOS_TEAM_ID}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID}</key>
        <string>${IOS_PROVISIONING_PROFILE_UUID}</string>
    </dict>
    <key>compileBitcode</key>
    <false/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
EOF

echo "::notice::Exporting IPA from archive..."
if ! xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${BUILDS_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"; then
  echo "::error::IPA export failed"
  exit 1
fi

ACTUAL_IPA=$(find "${BUILDS_DIR}" -name "*.ipa" -type f | head -1)
if [ -n "${ACTUAL_IPA}" ] && [ "${ACTUAL_IPA}" != "${EXPORT_PATH}" ]; then
  mv "${ACTUAL_IPA}" "${EXPORT_PATH}"
fi

if [ ! -f "${EXPORT_PATH}" ]; then
  echo "::error::IPA file not found: ${EXPORT_PATH}"
  exit 1
fi

FILE_SIZE=$(stat -f%z "${EXPORT_PATH}" 2>/dev/null || stat -c%s "${EXPORT_PATH}" 2>/dev/null || echo "unknown")
echo "::notice::Build completed successfully: ${EXPORT_PATH} (${FILE_SIZE} bytes)"
echo "file=${EXPORT_PATH}" >> "${GITHUB_OUTPUT}"
