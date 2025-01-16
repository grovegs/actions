#!/bin/bash

set -e

log_error() {
    echo "::error::$1"
    exit 1
}

log_notice() {
    echo "::notice::$1"
}

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

builds_dir="${HOME}/.builds/ios"
keychains_dir="${RUNNER_TEMP}/Keychains"
keychain_file="${keychains_dir}/ios.keychain-db"
certificate_file="${RUNNER_TEMP}/ios.p12"
provisioning_profile_file="${RUNNER_TEMP}/${provisioning_profile_uuid}.mobileprovision"
provisioning_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"

keychain_password=$(openssl rand -base64 32)

mkdir -p "${builds_dir}" || log_error "Failed to create directory ${builds_dir}"
mkdir -p "${keychains_dir}" || log_error "Failed to create directory ${keychains_dir}"
mkdir -p "${provisioning_dir}" || log_error "Failed to create provisioning profiles directory"

echo -n "${certificate}" | base64 -d >"${certificate_file}" || log_error "Failed to decode and save the iOS .p12 certificate"
echo -n "${provisioning_profile}" | base64 -d >"${provisioning_profile_file}" || log_error "Failed to decode and save the provisioning profile"

log_notice "Creating temporary keychain..."
security create-keychain -p "${keychain_password}" "${keychain_file}" || log_error "Failed to create keychain"

log_notice "Configuring temporary keychain..."
security set-keychain-settings -lut 3600 "${keychain_file}"
security unlock-keychain -p "${keychain_password}" "${keychain_file}"
security list-keychain -d user -s "${keychain_file}"

security import "${certificate_file}" -k "${keychain_file}" -P "${certificate_password}" -T /usr/bin/codesign ||
    log_error "Failed to import the .p12 certificate into the keychain"

cp "${provisioning_profile_file}" "${provisioning_dir}/" || log_error "Failed to copy the provisioning profile"

export_file="${builds_dir}/${filename}.ipa"

export DefineSymbols=${define_symbols}

case "${configuration}" in
Debug)
    log_notice "Exporting debug build for iOS"
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_DEBUG="${provisioning_profile_uuid}"
    godot --path "${project_dir}" --export-debug "${preset}" "${export_file}" "${define_symbols}" ||
        log_error "Godot export debug failed"
    ;;
Release)
    log_notice "Exporting release build for iOS"
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE="${provisioning_profile_uuid}"
    godot --path "${project_dir}" --export-release "${preset}" "${export_file}" "${define_symbols}" ||
        log_error "Godot export release failed"
    ;;
*)
    log_error "Unsupported configuration: ${configuration}"
    ;;
esac

rm -rf "${builds_dir}/${filename}/Images.xcassets/SplashImage.imageset"
sed -i '/<imageView[^>]*id="tjZ-vn-Lsv"/,/<\/imageView>/d' "${builds_dir}/${filename}/Launch Screen.storyboard"

cleanup() {
    log_notice "Cleaning up sensitive files..."
    security delete-keychain "${keychain_file}" || true
    rm -f "${certificate_file}" || true
    rm -f "${provisioning_profile_file}" || true
}
trap cleanup EXIT

log_notice "Build completed successfully: ${export_file}"
echo "file=${export_file}" >>"$GITHUB_OUTPUT"
