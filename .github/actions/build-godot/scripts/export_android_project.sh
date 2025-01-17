#!/bin/bash

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
    rm -f "${keystore_file}" || true
}
# Ensure cleanup is always called on script exit
trap cleanup EXIT

#######################################
# Argument Parsing
#######################################
if [ $# -ne 9 ]; then
    log_error "Invalid number of arguments. Expected 9, got $#. Usage: $0 <project_dir> <preset> <configuration> <filename> <define_symbols> <keystore> <keystore_user> <keystore_password> <format>"
fi

project_dir="$1"
preset="$2"
configuration="$3"
filename="$4"
define_symbols="$5"
keystore="$6"
keystore_user="$7"
keystore_password="$8"
format="$9"

#######################################
# Paths & Variables
#######################################
android_dir="${HOME}/.android"
keystore_file="${RUNNER_TEMP}/android.keystore"
builds_dir="${HOME}/.builds/android"
output_file="${builds_dir}/${filename}.${format}"

# Set environment variables for Godot
export DefineSymbols="${define_symbols}"

#######################################
# Create Directories
#######################################
log_notice "Creating required directories..."
mkdir -p "${android_dir}" || log_error "Failed to create directory: ${android_dir}"
mkdir -p "${builds_dir}" || log_error "Failed to create directory: ${builds_dir}"

#######################################
# Decode and Save Keystore
#######################################
log_notice "Decoding Android keystore..."
echo -n "${keystore}" | base64 -d >"${keystore_file}" ||
    log_error "Failed to decode and save the Android keystore"

#######################################
# Godot Export (Debug/Release)
#######################################
case "${configuration}" in
Debug)
    log_notice "Exporting debug build for Android..."
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${keystore_file}"
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${keystore_user}"
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${keystore_password}"
    godot --path "${project_dir}" --rendering-driver opengl3 --export-debug "${preset}" "${output_file}" ||
        log_error "Godot export debug failed"
    ;;
Release)
    log_notice "Exporting release build for Android..."
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${keystore_file}"
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${keystore_user}"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${keystore_password}"
    godot --path "${project_dir}" --rendering-driver opengl3 --export-release "${preset}" "${output_file}" ||
        log_error "Godot export release failed"
    ;;
*)
    log_error "Unsupported configuration: ${configuration}"
    ;;
esac

#######################################
# Completion
#######################################
log_notice "Build completed successfully: ${output_file}"
echo "file=${output_file}" >>"${GITHUB_OUTPUT}"
