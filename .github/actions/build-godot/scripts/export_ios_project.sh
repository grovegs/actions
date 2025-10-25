#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${PRESET:-}" ]; then
  echo "::error::PRESET environment variable is required"
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

BUILDS_DIR="${HOME}/.builds/ios"
KEYCHAINS_DIR="${RUNNER_TEMP}/Keychains"
KEYCHAIN_FILE="${KEYCHAINS_DIR}/ios.keychain-db"
CERTIFICATE_FILE="${RUNNER_TEMP}/ios.p12"
PROVISIONING_PROFILE_FILE="${RUNNER_TEMP}/profile.mobileprovision"
PROVISIONING_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
PROJECT_NAME="$(basename "${PROJECT_DIR}")"
XCODEPROJ_FILE="${BUILDS_DIR}/${PROJECT_NAME}.xcodeproj"
EXPORT_FILE="${BUILDS_DIR}/${FILENAME}.ipa"

export DefineSymbols="${DEFINE_SYMBOLS:-}"

cleanup() {
  echo "::notice::Cleaning up sensitive files..."
  security delete-keychain "${KEYCHAIN_FILE}" 2>/dev/null || true
  rm -f "${CERTIFICATE_FILE}" "${PROVISIONING_PROFILE_FILE}" || true
}
trap cleanup EXIT

echo "::notice::Creating required directories..."
mkdir -p "${BUILDS_DIR}" || {
  echo "::error::Failed to create directory: ${BUILDS_DIR}"
  exit 1
}
mkdir -p "${KEYCHAINS_DIR}" || {
  echo "::error::Failed to create directory: ${KEYCHAINS_DIR}"
  exit 1
}
mkdir -p "${PROVISIONING_DIR}" || {
  echo "::error::Failed to create directory: ${PROVISIONING_DIR}"
  exit 1
}

echo "::notice::Decoding certificate and provisioning profile..."
echo -n "${IOS_CERTIFICATE}" | base64 -d > "${CERTIFICATE_FILE}" || {
  echo "::error::Failed to decode and save the iOS .p12 certificate"
  exit 1
}
echo -n "${IOS_PROVISIONING_PROFILE}" | base64 -d > "${PROVISIONING_PROFILE_FILE}" || {
  echo "::error::Failed to decode and save the provisioning profile"
  exit 1
}

echo "::notice::Extracting UUID from provisioning profile..."
IOS_PROVISIONING_PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print :UUID" /dev/stdin <<< "$(security cms -D -i "${PROVISIONING_PROFILE_FILE}")") || {
  echo "::error::Failed to extract UUID from provisioning profile"
  exit 1
}

if [ -z "${IOS_PROVISIONING_PROFILE_UUID}" ]; then
  echo "::error::Extracted UUID is empty"
  exit 1
fi

echo "::notice::Extracted provisioning profile UUID: ${IOS_PROVISIONING_PROFILE_UUID}"

echo "::notice::Creating temporary keychain..."
security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_FILE}" || {
  echo "::error::Failed to create keychain"
  exit 1
}

echo "::notice::Configuring temporary keychain..."
security set-keychain-settings -lut 3600 "${KEYCHAIN_FILE}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_FILE}"
security list-keychains -d user -s "${KEYCHAIN_FILE}"

echo "::notice::Importing certificate into keychain..."
security import "${CERTIFICATE_FILE}" -k "${KEYCHAIN_FILE}" -P "${IOS_CERTIFICATE_PASSWORD}" -T /usr/bin/codesign || {
  echo "::error::Failed to import the .p12 certificate into the keychain"
  exit 1
}

echo "::notice::Copying provisioning profile to local directory..."
cp "${PROVISIONING_PROFILE_FILE}" "${PROVISIONING_DIR}/${IOS_PROVISIONING_PROFILE_UUID}.mobileprovision" || {
  echo "::error::Failed to copy the provisioning profile"
  exit 1
}

case "${CONFIGURATION}" in
  Debug)
    echo "::notice::Exporting debug build for iOS..."
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_DEBUG="${IOS_PROVISIONING_PROFILE_UUID}"
    if ! godot --nologo --path "${PROJECT_DIR}" --rendering-driver vulkan --export-debug "${PRESET}" "${EXPORT_FILE}"; then
      echo "::error::Godot export debug failed"
      exit 1
    fi
    ;;
  Release)
    echo "::notice::Exporting release build for iOS..."
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE="${IOS_PROVISIONING_PROFILE_UUID}"
    if ! godot --nologo --path "${PROJECT_DIR}" --rendering-driver vulkan --export-release "${PRESET}" "${EXPORT_FILE}"; then
      echo "::error::Godot export release failed"
      exit 1
    fi
    ;;
  *)
    echo "::error::Unsupported configuration: ${CONFIGURATION}"
    exit 1
    ;;
esac

echo "::notice::Godot export succeeded. xcodeproj file exported to: ${XCODEPROJ_FILE}"

ARCHIVE_PATH="${BUILDS_DIR}/${PROJECT_NAME}.xcarchive"
LAUNCH_SCREEN_FILE="${BUILDS_DIR}/${PROJECT_NAME}/Launch Screen.storyboard"
SPLASH_IMAGE_FILE="${BUILDS_DIR}/${PROJECT_NAME}/Images.xcassets/SplashImage.imageset"
EXPORT_OPTIONS_PLIST="${BUILDS_DIR}/${PROJECT_NAME}/export_options.plist"

echo "::notice::Removing SplashImage and imageView from Launch Screen.storyboard..."

if [ -d "${SPLASH_IMAGE_FILE}" ]; then
  rm -rf "${SPLASH_IMAGE_FILE}"
fi

if [ ! -f "${LAUNCH_SCREEN_FILE}" ]; then
  echo "::error::Launch Screen.storyboard not found at ${LAUNCH_SCREEN_FILE}"
  exit 1
fi

if ! awk '
    BEGIN { found=0; printing=1 }
    /<imageView/ { found=1; printing=0; next }
    printing { print }
    /<\/imageView>/ { if (found) { found=0; printing=1; next } else print }
' "${LAUNCH_SCREEN_FILE}" > "${LAUNCH_SCREEN_FILE}.tmp"; then
  echo "::error::Failed to process Launch Screen.storyboard with awk"
  exit 1
fi

if ! mv "${LAUNCH_SCREEN_FILE}.tmp" "${LAUNCH_SCREEN_FILE}"; then
  echo "::error::Failed to update Launch Screen.storyboard"
  exit 1
fi

xcodebuild -list -project "${XCODEPROJ_FILE}"

DEFAULT_SCHEME=$(
  xcodebuild -list -project "${XCODEPROJ_FILE}" \
    | awk '
      /Schemes:/ { flag = 1; next }
      /^$/       { flag = 0 }
      flag {
        gsub(/^[ \t]+|[ \t]+$/, "", $0)
        print
      }
    ' \
    | head -n 1
)

echo "::notice::Running xcodebuild clean..."
xcodebuild clean \
  -project "${XCODEPROJ_FILE}" \
  -scheme "${DEFAULT_SCHEME}" \
  -configuration "${CONFIGURATION}"

echo "::notice::Creating an archive (.xcarchive)..."
xcodebuild archive \
  -project "${XCODEPROJ_FILE}" \
  -scheme "${DEFAULT_SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH}"

echo "::notice::Exporting .ipa from archive..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${BUILDS_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}"

if [ ! -f "${EXPORT_FILE}" ]; then
  echo "::error::IPA file not found: ${EXPORT_FILE}"
  exit 1
fi

FILE_SIZE=$(stat -f%z "${EXPORT_FILE}" 2>/dev/null || stat -c%s "${EXPORT_FILE}" 2>/dev/null || echo "unknown")
echo "::notice::Build completed successfully: ${EXPORT_FILE} (${FILE_SIZE} bytes)"
echo "file=${EXPORT_FILE}" >> "${GITHUB_OUTPUT}"
