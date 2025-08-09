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

echo "::notice::Building Unity project for Android (${format})..."
echo "::notice::Project path: ${project_dir}"

if [ -n "${build_method}" ]; then
    build_method_args=("-executeMethod" "${build_method}")
else
    build_script_dest="${project_dir}/Assets/Editor/BuildAndroid.cs"
    mkdir -p "${project_dir}/Assets/Editor"
    
    if [ -f "${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs" ]; then
        cp "${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs" "${build_script_dest}" || {
            echo "::error::Failed to copy build script"
            exit 1
        }
    else
        echo "::error::Build script not found: ${GITHUB_ACTION_PATH}/scripts/BuildAndroid.cs"
        exit 1
    fi
    
    build_method_args=("-executeMethod" "BuildAndroid.Build")
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

if [ -n "${keystore}" ]; then
    build_args+=(
        -keystorePath "${keystore_file}"
        -keystorePass "${keystore_password}"
        -keyaliasName "${keystore_user}"
        -keyaliasPass "${keystore_password}"
    )
fi

if ! unity "${build_args[@]}"; then
    echo "::error::Unity build failed for Android"
    
    echo "::debug::Project directory contents:"
    ls -la "${project_dir}" || echo "::debug::Cannot list project directory"
    
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