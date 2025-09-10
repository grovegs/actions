#!/bin/bash

set -euo pipefail

if [ $# -ne 15 ]; then
    echo "::error::Expected 15 arguments"
    exit 1
fi

project_dir="$1"
version="$2"
configuration="$3"
filename="$4"
unity_email="$5"
unity_password="$6"
unity_license_key="$7"
team_id="$8"
certificate="$9"
certificate_password="${10}"
provisioning_profile="${11}"
provisioning_profile_uuid="${12}"
export_method="${13}"
build_method="${14}"
profile_name="${15}"

if [[ "$project_dir" != /* ]]; then
    project_dir="$(cd "$project_dir" && pwd)"
fi

builds_dir="${HOME}/.builds/ios"
xcode_project_dir="${builds_dir}/${filename}"
archive_path="${builds_dir}/${filename}.xcarchive"
export_path="${builds_dir}/${filename}.ipa"
export_options_plist="${builds_dir}/export.plist"

cleanup() {
    echo "::notice::Cleaning up sensitive files..."
    security delete-keychain "${keychain_file}" 2>/dev/null || true
    rm -f "${certificate_file}" "${provisioning_file}" "${export_options_plist}" || true
}
trap cleanup EXIT

echo "::notice::Creating build directories..."
mkdir -p "${builds_dir}"
mkdir -p "${xcode_project_dir}"

echo "::notice::Build configuration:"
echo "::notice::  Project: ${project_dir}"
echo "::notice::  Version: ${version}"
echo "::notice::  Configuration: ${configuration}"
echo "::notice::  Output: ${xcode_project_dir}"
echo "::notice::  Profile: ${profile_name}"
echo "::notice::  Team ID: ${team_id}"

if [ -n "${build_method}" ]; then
    echo "::notice::Using custom build method: ${build_method}"
    build_method_args=("-executeMethod" "${build_method}")
else
    echo "::notice::Using default build method: BuildiOS.Build"
    build_script_dest="${project_dir}/Assets/Editor/BuildiOS.cs"
    mkdir -p "${project_dir}/Assets/Editor"
    
    if [ -f "${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs" ]; then
        cp "${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs" "${build_script_dest}"
        echo "::notice::Copied BuildiOS.cs to ${build_script_dest}"
    else
        echo "::error::Build script not found: ${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs"
        exit 1
    fi
    
    build_method_args=("-executeMethod" "BuildiOS.Build")
fi

build_args=(
    -batchmode
    -nographics
    -quit
    -username "${unity_email}"
    -password "${unity_password}"
    -serial "${unity_license_key}"
    -projectPath "${project_dir}"
    -buildTarget iOS
    -logFile -
    "${build_method_args[@]}"
    -outputPath "${xcode_project_dir}"
    -versionName "${version}"
    -buildConfig "${configuration}"
    -profileId "${provisioning_profile_uuid}"
    -teamId "${team_id}"
    -profileName "${profile_name}"
)

echo "::notice::Starting Unity build..."
if ! unity "${build_args[@]}" 2>&1; then
    echo "::error::Unity build failed for iOS"
    exit 1
fi

echo "::notice::Unity build completed successfully"

echo "::notice::Looking for Xcode project..."
xcodeproj_file=$(find "${xcode_project_dir}" -name "*.xcodeproj" -type d | head -1)
if [ -z "$xcodeproj_file" ]; then
    echo "::error::No Xcode project found in ${xcode_project_dir}"
    exit 1
fi

xcodeproj_name=$(basename "$xcodeproj_file")
scheme_name="${xcodeproj_name%.*}"
echo "::notice::Found Xcode project: ${xcodeproj_name}"

if [ -n "${certificate}" ] && [ -n "${provisioning_profile}" ]; then
    echo "::notice::Setting up iOS signing..."
    keychain_file="${RUNNER_TEMP}/ios.keychain-db"
    certificate_file="${RUNNER_TEMP}/ios.p12"
    provisioning_file="${RUNNER_TEMP}/profile.mobileprovision"
    keychain_password=$(openssl rand -base64 32)
    
    echo -n "${certificate}" | base64 -d > "${certificate_file}"
    echo -n "${provisioning_profile}" | base64 -d > "${provisioning_file}"
    
    security create-keychain -p "${keychain_password}" "${keychain_file}"
    security set-keychain-settings -lut 3600 "${keychain_file}"
    security unlock-keychain -p "${keychain_password}" "${keychain_file}"
    security list-keychains -d user -s "${keychain_file}"
    security import "${certificate_file}" -k "${keychain_file}" -P "${certificate_password}" -T /usr/bin/codesign
    
    mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
    cp "${provisioning_file}" "$HOME/Library/MobileDevice/Provisioning Profiles/"
    
    echo "::notice::Building and archiving iOS project..."
    if ! xcodebuild -project "${xcodeproj_file}" \
        -scheme "${scheme_name}" \
        -configuration "${configuration}" \
        -destination "generic/platform=iOS" \
        -archivePath "${archive_path}" \
        archive; then
        echo "::error::Xcode archive failed"
        exit 1
    fi
    
    echo "::notice::Archive created successfully at ${archive_path}"
    
    echo "::notice::Creating export options plist..."
    bundle_id=$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' "${xcodeproj_file}/project.pbxproj" | head -1 | cut -d' ' -f3 | tr -d '"')
    
    if [ -z "$bundle_id" ]; then
        echo "::error::Could not extract bundle ID from project.pbxproj"
        exit 1
    fi
    
    echo "::notice::Using bundle ID: ${bundle_id}"
    echo "::notice::Using provisioning profile UUID: ${provisioning_profile_uuid}"
    
    cat > "${export_options_plist}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${export_method}</string>
    <key>teamID</key>
    <string>${team_id}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${bundle_id}</key>
        <string>${provisioning_profile_uuid}</string>
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
        -archivePath "${archive_path}" \
        -exportPath "${builds_dir}" \
        -exportOptionsPlist "${export_options_plist}"; then
        echo "::error::IPA export failed"
        exit 1
    fi
    
    actual_ipa=$(find "${builds_dir}" -name "*.ipa" -type f | head -1)
    if [ -n "$actual_ipa" ] && [ "$actual_ipa" != "$export_path" ]; then
        mv "$actual_ipa" "$export_path"
    fi
    
    if [ ! -f "${export_path}" ]; then
        echo "::error::IPA file not found: ${export_path}"
        exit 1
    fi
    
    file_size=$(stat -f%z "${export_path}" 2>/dev/null || stat -c%s "${export_path}" 2>/dev/null || echo "unknown")
    echo "::notice::Build completed successfully: ${export_path} (${file_size} bytes)"
    echo "file=${export_path}" >> "${GITHUB_OUTPUT}"
else
    echo "::notice::Build completed successfully (Xcode project only): ${xcode_project_dir}"
    echo "file=${xcode_project_dir}" >> "${GITHUB_OUTPUT}"
fi