#!/bin/bash

# Exit immediately if a command exits with a non-zero status (-e),
# treat unset variables as an error (-u),
# print each command before executing it (-x), and
# make pipelines fail if any command fails (not just the last one) (-o pipefail).
set -euxo pipefail

#######################################
# Utility functions
#######################################
log_error() {
    echo "::error::$1"
    exit 1
}

log_notice() {
    echo "::notice::$1"
}

#######################################
# Cleanup function to remove sensitive files
#######################################
cleanup() {
    log_notice "Cleaning up sensitive files..."
    security delete-keychain "${keychain_file}" || true
    rm -f "${certificate_file}" || true
    rm -f "${provisioning_profile_file}" || true
}
# Ensure cleanup is always called on script exit
trap cleanup EXIT

#######################################
# Argument Parsing
#######################################
if [ $# -ne 9 ]; then
    log_error "Usage: $0 <project_dir> <preset> <configuration> <filename> <define_symbols> <certificate> <certificate_password> <provisioning_profile> <provisioning_profile_uuid>"
fi

project_dir="$1"
preset="$2"
configuration="$3"
filename="$4"
define_symbols="$5"
certificate="$6"
certificate_password="$7"
provisioning_profile="$8"
provisioning_profile_uuid="$9"

#######################################
# Paths & Variables
#######################################
builds_dir="${HOME}/.builds/ios"
keychains_dir="${RUNNER_TEMP}/Keychains"
keychain_file="${keychains_dir}/ios.keychain-db"
certificate_file="${RUNNER_TEMP}/ios.p12"
provisioning_profile_file="${RUNNER_TEMP}/${provisioning_profile_uuid}.mobileprovision"
provisioning_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"
keychain_password=$(openssl rand -base64 32)
project_name="$(basename "${project_dir}")"
xcodeproj_file="${builds_dir}/${project_name}.xcodeproj"
export_file="${builds_dir}/${filename}.ipa"

# Godot build environment variable
export DefineSymbols="${define_symbols}"

#######################################
# Create directories
#######################################
log_notice "Creating required directories..."
mkdir -p "${builds_dir}" || log_error "Failed to create directory: ${builds_dir}"
mkdir -p "${keychains_dir}" || log_error "Failed to create directory: ${keychains_dir}"
mkdir -p "${provisioning_dir}" || log_error "Failed to create directory: ${provisioning_dir}"

#######################################
# Decode and save certificate & profile
#######################################
log_notice "Decoding certificate and provisioning profile..."
echo -n "${certificate}" | base64 -d >"${certificate_file}" ||
    log_error "Failed to decode and save the iOS .p12 certificate"
echo -n "${provisioning_profile}" | base64 -d >"${provisioning_profile_file}" ||
    log_error "Failed to decode and save the provisioning profile"

#######################################
# Keychain setup
#######################################
log_notice "Creating temporary keychain..."
security create-keychain -p "${keychain_password}" "${keychain_file}" ||
    log_error "Failed to create keychain"

log_notice "Configuring temporary keychain..."
security set-keychain-settings -lut 3600 "${keychain_file}"
security unlock-keychain -p "${keychain_password}" "${keychain_file}"
security list-keychains -d user -s "${keychain_file}"

log_notice "Importing certificate into keychain..."
security import "${certificate_file}" -k "${keychain_file}" -P "${certificate_password}" -T /usr/bin/codesign ||
    log_error "Failed to import the .p12 certificate into the keychain"

log_notice "Copying provisioning profile to local directory..."
cp "${provisioning_profile_file}" "${provisioning_dir}/" ||
    log_error "Failed to copy the provisioning profile"

#######################################
# Godot Export (Debug/Release)
#######################################
case "${configuration}" in
Debug)
    log_notice "Exporting debug build for iOS..."
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_DEBUG="${provisioning_profile_uuid}"
    godot --path "${project_dir}" --export-debug "${preset}" "${export_file}" ||
        log_error "Godot export debug failed"
    ;;
Release)
    log_notice "Exporting release build for iOS..."
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE="${provisioning_profile_uuid}"
    godot --path "${project_dir}" --export-release "${preset}" "${export_file}" ||
        log_error "Godot export release failed"
    ;;
*)
    log_error "Unsupported configuration: ${configuration}"
    ;;
esac

log_notice "Godot export succeeded. xcodeproj file exported to: ${xcodeproj_file}"

#######################################
# Xcode Archive & Export
#######################################
archive_path="${builds_dir}/${project_name}.xcarchive"
launch_screen_file="${builds_dir}/${project_name}/Launch Screen.storyboard"
splash_image_file="${builds_dir}/${project_name}/Images.xcassets/SplashImage.imageset"
export_options_plist="${builds_dir}/${project_name}/export_options.plist"

# Remove splash-related assets
log_notice "Removing SplashImage and <imageView> from Launch Screen.storyboard..."

# Remove splash image directory if it exists
if [ -d "${launch_screen_file}" ]; then
    rm -rf "${splash_image_file}"
fi

# Remove any imageView using awk
if [ ! -f "${launch_screen_file}" ]; then
    log_error "Launch Screen.storyboard not found at ${launch_screen_file}"
fi

if ! awk '
    BEGIN { found=0; printing=1 }
    /<imageView/ { found=1; printing=0; next }
    printing { print }
    /<\/imageView>/ { if (found) { found=0; printing=1; next } else print }
' "${launch_screen_file}" >"${launch_screen_file}.tmp"; then
    log_error "Failed to process Launch Screen.storyboard with awk"
fi

if ! mv "${launch_screen_file}.tmp" "${launch_screen_file}"; then
    log_error "Failed to update Launch Screen.storyboard"
fi

xcodebuild -list -project "${xcodeproj_file}"

default_scheme="$(
  xcodebuild -list -project "${xcodeproj_file}" |
    awk '
      /Schemes:/ { flag = 1; next }
      /^$/       { flag = 0 }
      flag {
        # Remove leading (and optionally trailing) whitespace
        gsub(/^[ \t]+|[ \t]+$/, "", $0)
        print
      }
    ' |
    head -n 1
)"

log_notice "Running xcodebuild clean..."
xcodebuild clean \
    -project "${xcodeproj_file}" \
    -scheme "${default_scheme}" \
    -configuration "${configuration}"

log_notice "Creating an archive (.xcarchive)..."
xcodebuild archive \
    -project "${xcodeproj_file}" \
    -scheme "${default_scheme}" \
    -configuration "${configuration}" \
    -archivePath "${archive_path}"

log_notice "Exporting .ipa from archive..."
xcodebuild -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${builds_dir}" \
    -exportOptionsPlist "${export_options_plist}"

#######################################
# Completion
#######################################
log_notice "Build completed successfully: ${export_file}"
echo "file=${export_file}" >>"${GITHUB_OUTPUT}"
