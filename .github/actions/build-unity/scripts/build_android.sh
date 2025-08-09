#!/bin/bash

validate_args() {
    if [ $# -ne 13 ]; then
        echo "::error::Expected 13 arguments: project_dir version configuration filename unity_email unity_password unity_license_key define_symbols keystore keystore_user keystore_password format build_method"
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
    
    [[ "${12}" =~ ^(apk|aab)$ ]] || { 
        echo "::error::Invalid Android format: ${12}. Expected apk or aab"; 
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
define_symbols="$8"
keystore="$9"
keystore_user="${10}"
keystore_password="${11}"
format="${12}"
build_method="${13}"

validate_inputs "$@"

if [[ "$project_dir" != /* ]]; then
    project_dir="$(cd "$project_dir" && pwd)"
fi

builds_dir="${HOME}/.builds/android"
keystore_file="${RUNNER_TEMP}/android.keystore"
output_file="${builds_dir}/${filename}.${format}"

cleanup() {
    echo "::notice::Cleaning up sensitive files..."
    rm -f "${keystore_file}" || true
}
trap cleanup EXIT

echo "::notice::Creating build directory..."
mkdir -p "${builds_dir}" || {
    echo "::error::Failed to create directory: ${builds_dir}"
    exit 1
}

if [ -n "${keystore}" ]; then
    echo "::notice::Decoding Android keystore..."
    echo -n "${keystore}" | base64 -d > "${keystore_file}" || {
        echo "::error::Failed to decode Android keystore"
        exit 1
    }
    chmod 600 "${keystore_file}"
fi

echo "::notice::Checking Android build requirements..."
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
echo "::notice::  Format: ${format}"
echo "::notice::  Output: ${output_file}"
echo "::notice::  Define symbols: ${define_symbols}"

if [ -n "${build_method}" ]; then
    build_method_args=("-executeMethod" "${build_method}")
    echo "::notice::Using custom build method: ${build_method}"
else
    build_script_dest="${project_dir}/Assets/Editor/BuildAndroid.cs"
    mkdir -p "${project_dir}/Assets/Editor"
    
    if [ -f "${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs" ]; then
        cp "${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs" "${build_script_dest}" || {
            echo "::error::Failed to copy build script"
            exit 1
        }
        echo "::notice::Copied BuildAndroid.cs to ${build_script_dest}"
    else
        echo "::error::Build script not found: ${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs"
        exit 1
    fi
    
    build_method_args=("-executeMethod" "BuildAndroid.Build")
    echo "::notice::Using default build method: BuildAndroid.Build"
fi

mkdir -p "$(dirname "${output_file}")" || {
    echo "::error::Failed to create output directory: $(dirname "${output_file}")"
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
    -logFile -
    -buildTarget Android
    "${build_method_args[@]}"
    -outputPath "${output_file}"
    -defineSymbols "${define_symbols}"
    -versionName "${version}"
    -buildConfig "${configuration}"
    -buildFormat "${format}"
)

echo "::notice::Unity command line:"
printf '%s ' "${build_args[@]}"
echo ""

if [ -n "${keystore}" ]; then
    build_args+=(
        -keystorePath "${keystore_file}"
        -keystorePass "${keystore_password}"
        -keyaliasName "${keystore_user}"
        -keyaliasPass "${keystore_password}"
    )
fi

echo "::notice::Starting Unity build..."
if ! unity "${build_args[@]}" 2>&1; then
    echo "::error::Unity build failed for Android"
    echo "::error::Check the Unity log output above for specific error details"
    
    echo "::debug::Project directory contents:"
    ls -la "${project_dir}" || echo "::debug::Cannot list project directory"
    
    echo "::debug::Build directory contents:"
    ls -la "${builds_dir}" || echo "::debug::Cannot list build directory"
    
    echo "::debug::Unity version:"
    unity -version 2>/dev/null || echo "::debug::Cannot get Unity version"
    
    exit 1
fi

if [ ! -f "${output_file}" ]; then
    echo "::error::Build output not found: ${output_file}"
    echo "::debug::Contents of build directory:"
    ls -la "${builds_dir}" || echo "::debug::Cannot list build directory"
    exit 1
fi

file_size=$(stat -f%z "${output_file}" 2>/dev/null || stat -c%s "${output_file}" 2>/dev/null || echo "unknown")
echo "::notice::Build completed successfully: ${output_file} (${file_size} bytes)"
echo "file=${output_file}" >> "${GITHUB_OUTPUT}"