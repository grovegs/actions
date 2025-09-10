#!/bin/bash

validate_args() {
    if [ $# -ne 15 ]; then
        echo "::error::Expected 15 arguments: project_dir version configuration filename unity_email unity_password unity_license_key team_id certificate certificate_password provisioning_profile provisioning_profile_uuid export_method build_method profile_name"
        echo "::error::Got $# arguments"
        exit 1
    fi
}

validate_inputs() {
    local project_dir="$1"
    
    if [[ "$project_dir" != /* ]]; then
        project_dir="$(cd "$project_dir" 2>/dev/null && pwd)" || {
            echo "::error::Project directory not found or inaccessible: $1"
            exit 1
        }
    fi
    
    [ -d "$project_dir" ] || { 
        echo "::error::Project directory not found: $project_dir"; 
        exit 1; 
    }
    
    [ -d "$project_dir/Assets" ] || { 
        echo "::error::Not a valid Unity project (missing Assets folder): $project_dir"; 
        exit 1; 
    }
    [ -d "$project_dir/ProjectSettings" ] || { 
        echo "::error::Not a valid Unity project (missing ProjectSettings folder): $project_dir"; 
        exit 1; 
    }
    
    [[ "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { 
        echo "::error::Invalid version format: $2. Expected x.y.z"; 
        exit 1; 
    }
}

validate_args "$@"

project_dir="$1"
version="$2"
configuration="$3"
filename="$4"
unity_email="$5"
unity_password="$6"
unity_license_key="$7"
team_id="$8"
certificate="${9}"
certificate_password="${10}"
provisioning_profile="${11}"
provisioning_profile_uuid="${12}"
export_method="${13}"
build_method="${14}"
profile_name="${15}"

validate_inputs "$@"

if [[ "$project_dir" != /* ]]; then
    project_dir="$(cd "$project_dir" && pwd)"
fi

builds_dir="${HOME}/.builds/ios"
xcode_project_dir="${builds_dir}/${filename}"
archive_path="${builds_dir}/${filename}.xcarchive"
export_path="${builds_dir}/${filename}.ipa"
export_options_plist="${builds_dir}/export.plist"

if [ -n "$DEVELOPER_DIR" ]; then
    echo "::notice::Using DEVELOPER_DIR: $DEVELOPER_DIR"
    XCODEBUILD_CMD="${DEVELOPER_DIR}/usr/bin/xcodebuild"
    if [ ! -x "$XCODEBUILD_CMD" ]; then
        echo "::warning::xcodebuild not found at $XCODEBUILD_CMD, falling back to xcrun"
        XCODEBUILD_CMD="xcrun xcodebuild"
    fi
else
    echo "::notice::DEVELOPER_DIR not set, using xcrun to find xcodebuild"
    XCODEBUILD_CMD="xcrun xcodebuild"
fi

echo "::notice::Using xcodebuild command: $XCODEBUILD_CMD"

cleanup() {
    echo "::notice::Cleaning up sensitive files..."
    security delete-keychain "${keychain_file}" 2>/dev/null || true
    rm -f "${certificate_file}" "${provisioning_file}" "${export_options_plist}" || true
}
trap cleanup EXIT

echo "::notice::Creating build directory..."
mkdir -p "${builds_dir}" || {
    echo "::error::Failed to create directory: ${builds_dir}"
    exit 1
}

echo "::notice::Checking iOS build requirements..."
if [ ! -f "${project_dir}/ProjectSettings/ProjectSettings.asset" ]; then
    echo "::warning::ProjectSettings.asset not found - this might not be a valid Unity project"
fi

if [ -d "${project_dir}/ProjectSettings" ]; then
    echo "::debug::ProjectSettings directory contents:"
    ls -la "${project_dir}/ProjectSettings/" || true
fi

echo "::notice::Build configuration:"
echo "::notice::  Project: ${project_dir}"
echo "::notice::  Version: ${version}"
echo "::notice::  Configuration: ${configuration}"
echo "::notice::  Output: ${xcode_project_dir}"
echo "::notice::  Profile: ${profile_name}"
echo "::notice::  Profile ID: ${provisioning_profile_uuid}"
echo "::notice::  Team ID: ${team_id}"

if [ -n "${build_method}" ]; then
    build_method_args=("-executeMethod" "${build_method}")
    echo "::notice::Using custom build method: ${build_method}"
else
    build_script_dest="${project_dir}/Assets/Editor/BuildiOS.cs"
    mkdir -p "${project_dir}/Assets/Editor"
    
    if [ -f "${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs" ]; then
        cp "${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs" "${build_script_dest}" || {
            echo "::error::Failed to copy build script"
            exit 1
        }
        echo "::notice::Copied BuildiOS.cs to ${build_script_dest}"
    else
        echo "::error::Build script not found: ${GITHUB_ACTION_PATH}/scripts/BuildiOS.cs"
        exit 1
    fi
    
    build_method_args=("-executeMethod" "BuildiOS.Build")
    echo "::notice::Using default build method: BuildiOS.Build"
fi

mkdir -p "${xcode_project_dir}" || {
    echo "::error::Failed to create Xcode project directory: ${xcode_project_dir}"
    exit 1
}

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

echo "::notice::Unity command line:"
printf '%s ' "${build_args[@]}"
echo ""

echo "::notice::Starting Unity build..."
if ! unity "${build_args[@]}" 2>&1; then
    echo "::error::Unity build failed for iOS"
    echo "::error::Check the Unity log output above for specific error details"
    
    echo "::debug::Project directory contents:"
    ls -la "${project_dir}" || echo "::debug::Cannot list project directory"
    
    echo "::debug::Build directory contents:"
    ls -la "${builds_dir}" || echo "::debug::Cannot list build directory"
    
    echo "::debug::Unity version:"
    unity -version 2>/dev/null || echo "::debug::Cannot get Unity version"
    
    exit 1
fi

xcodeproj_file=$(find "${xcode_project_dir}" -name "*.xcodeproj" -type d | head -1)
if [ -z "$xcodeproj_file" ]; then
    echo "::error::No Xcode project found in ${xcode_project_dir}"
    echo "::debug::Contents of Xcode project directory:"
    ls -la "${xcode_project_dir}" || echo "::debug::Cannot list Xcode project directory"
    exit 1
fi

xcodeproj_name=$(basename "$xcodeproj_file")
scheme_name="${xcodeproj_name%.*}"

if [ -n "${certificate}" ] && [ -n "${provisioning_profile}" ]; then
    echo "::notice::Setting up iOS signing..."
    
    keychain_file="${RUNNER_TEMP}/ios.keychain-db"
    certificate_file="${RUNNER_TEMP}/ios.p12"
    provisioning_file="${RUNNER_TEMP}/profile.mobileprovision"
    keychain_password=$(openssl rand -base64 32)
    
    echo -n "${certificate}" | base64 -d > "${certificate_file}" || {
        echo "::error::Failed to decode certificate"
        exit 1
    }
    echo -n "${provisioning_profile}" | base64 -d > "${provisioning_file}" || {
        echo "::error::Failed to decode provisioning profile"
        exit 1
    }
    
    security create-keychain -p "${keychain_password}" "${keychain_file}"
    security set-keychain-settings -lut 3600 "${keychain_file}"
    security unlock-keychain -p "${keychain_password}" "${keychain_file}"
    security list-keychains -d user -s "${keychain_file}"
    security import "${certificate_file}" -k "${keychain_file}" -P "${certificate_password}" -T /usr/bin/codesign
    
    mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
    cp "${provisioning_file}" "$HOME/Library/MobileDevice/Provisioning Profiles/"
    
    echo "::notice::Building Xcode project..."
    echo "::notice::Using xcodebuild: $XCODEBUILD_CMD"
    echo "::notice::Xcode version check:"
    $XCODEBUILD_CMD -version
    
    if ! $XCODEBUILD_CMD -project "${xcodeproj_file}" \
        -scheme "${scheme_name}" \
        -configuration "${configuration}" \
        -destination "generic/platform=iOS" \
        -archivePath "${archive_path}" \
        archive; then
        echo "::error::Xcode archive failed"
        exit 1
    fi
    
    echo "::notice::Creating export options plist..."
    
    if [ ! -f "${xcodeproj_file}/project.pbxproj" ]; then
        echo "::error::project.pbxproj not found in ${xcodeproj_file}"
        exit 1
    fi
    
    bundle_id=$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' "${xcodeproj_file}/project.pbxproj" | head -1 | cut -d' ' -f3 | tr -d '"')
    
    if [ -z "$bundle_id" ]; then
        echo "::error::Could not extract bundle ID from project.pbxproj"
        exit 1
    fi
    
    echo "::notice::Detected bundle ID: ${bundle_id}"
    echo "::notice::Using provisioning profile UUID: ${provisioning_profile_uuid}"
    
    {
        cat << EOF
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
    } > "${export_options_plist}"

    echo "::notice::Export options plist created with bundle ID: ${bundle_id}"
    echo "::debug::Export options plist contents:"
    cat "${export_options_plist}"
    
    echo "::notice::Exporting IPA..."
    
    if ! $XCODEBUILD_CMD -exportArchive \
        -archivePath "${archive_path}" \
        -exportPath "${builds_dir}" \
        -exportOptionsPlist "${export_options_plist}"; then
        echo "::error::IPA export failed"
        echo "::debug::Available files in build directory:"
        ls -la "${builds_dir}" || true
        exit 1
    fi
    
    actual_ipa=$(find "${builds_dir}" -name "*.ipa" -type f | head -1)
    if [ -n "$actual_ipa" ] && [ "$actual_ipa" != "$export_path" ]; then
        mv "$actual_ipa" "$export_path"
    fi
    
    if [ ! -f "${export_path}" ]; then
        echo "::error::IPA file not found: ${export_path}"
        echo "::debug::Contents of build directory:"
        ls -la "${builds_dir}" || true
        exit 1
    fi
    
    file_size=$(stat -f%z "${export_path}" 2>/dev/null || stat -c%s "${export_path}" 2>/dev/null || echo "unknown")
    echo "::notice::Build completed successfully: ${export_path} (${file_size} bytes)"
    echo "file=${export_path}" >> "${GITHUB_OUTPUT}"
else
    echo "::notice::Build completed successfully (Xcode project only): ${xcode_project_dir}"
    echo "file=${xcode_project_dir}" >> "${GITHUB_OUTPUT}"
fi