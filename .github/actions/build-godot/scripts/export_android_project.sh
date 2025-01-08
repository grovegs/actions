#!/bin/bash

if [ $# -ne 9 ]; then
    echo "::error::Invalid number of arguments. Expected 8, got $#"
    echo "Usage: $0 <project_dir> <preset> <configuration> <filename> <extra_arguments> <keystore> <keystore_user> <keystore_password> <format>"
    exit 1
fi

project_dir="$1"
preset="$2"
configuration="$3"
filename="$4"
extra_arguments="$5"
keystore="$6"
keystore_user="$7"
keystore_password="$8"
format="$9"

android_dir=~/.android
keystore_file=${android_dir}/android.keystore

if ! mkdir -p ${android_dir}; then
    echo "::error::Failed to create directory ${android_dir}"
    exit 1
fi

if ! echo -n "${keystore}" | base64 -d >${keystore_file}; then
    echo "::error::Failed to decode and save the Android keystore"
    exit 1
fi

builds_dir=~/.builds/android

if ! mkdir -p ${builds_dir}; then
    echo "::error::Failed to create directory ${builds_dir}"
    exit 1
fi

file=${builds_dir}/"${filename}".${format}
echo "::notice::Build output will be saved to: ${file}"

case ${configuration} in
Debug)
    export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=${keystore_file}
    export GODOT_ANDROID_KEYSTORE_DEBUG_USER=${keystore_user}
    export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=${keystore_password}

    if ! godot --path "${project_dir}" --headless --export-debug "${preset}" "${file}" "${extra_arguments}"; then
        echo "::error::Godot export debug failed"
        exit 1
    fi
    ;;
Release)
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=${keystore_file}
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER=${keystore_user}
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=${keystore_password}

    if ! godot --path "${project_dir}" --headless --export-release "${preset}" "${file}" "${extra_arguments}"; then
        echo "::error::Godot export release failed"
        exit 1
    fi
    ;;
*)
    echo "::error::Unsupported configuration: ${configuration}"
    exit 1
    ;;
esac

echo "::notice::Build artifact created at: ${file}"
echo file="${file}" >>"$GITHUB_OUTPUT"
