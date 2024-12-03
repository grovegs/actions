#!/bin/bash

if [ $# -ne 8 ]; then
    echo "Usage: $0 <project_dir> <preset> <configuration> <filename> <keystore> <keystore_user> <keystore_password> <format>"
    exit 1
fi

project_dir="$1"
preset="$2"
configuration="$3"
filename="$4"
keystore="$5"
keystore_user="$6"
keystore_password="$7"
format="$8"

android_dir=~/.android
keystore_file=${android_dir}/release.keystore

if ! mkdir -p ${android_dir}; then
    echo "Error: Failed to create directory ${android_dir}."
    exit 1
fi

if [ -z "${keystore}" ]; then
    echo "Error: Keystore is empty. Please provide a valid Base64-encoded keystore."
    exit 1
fi

if ! echo -n "${keystore}" | base64 -d >/dev/null 2>&1; then
    echo "Error: Keystore is not valid Base64. Please provide a valid Base64-encoded keystore."
    exit 1
fi

if ! echo -n "${keystore}" | base64 -d >"${keystore_file}"; then
    echo "Error: Failed to decode and save the Android keystore."
    exit 1
fi

builds_dir=~/.builds/android

if ! mkdir -p ${builds_dir}; then
    echo "Error: Failed to create directory ${builds_dir}."
    exit 1
fi

exported_file=${builds_dir}/"${filename}".${format}

case ${configuration} in
Debug)
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=${keystore_file}
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER=${keystore_user}
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=${keystore_password}
    godot --path "${project_dir}" --headless --export-debug "${preset}" "${exported_file}" >/dev/null 2>&1
    ;;
Release)
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=${keystore_file}
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER=${keystore_user}
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=${keystore_password}
    godot --path "${project_dir}" --headless --export-release "${preset}" "${exported_file}" >/dev/null 2>&1
    ;;
*)
    echo "Unsupported configuration: ${configuration}"
    exit 1
    ;;
esac

echo "${exported_file}"
