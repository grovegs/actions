#!/bin/bash

if [ $# -ne 7 ]; then
    echo "Usage: $0 <project_dir> <preset> <artifact> <keystore> <keystore_user> <keystore_password> <format>"
    exit 1
fi

project_dir="$1"
preset="$2"
artifact="$3"
keystore="$4"
keystore_user="$5"
keystore_password="$6"
format="$7"

artifacts_dir=~/.artifacts
android_dir=~/.android
keystore_file=${android_dir}/release.keystore
exported_file=${artifacts_dir}/"${artifact}".${format}

if ! mkdir -p ${android_dir}; then
    echo "Error: Failed to create directory ${android_dir}."
    exit 1
fi

if ! echo -n "${keystore}" | base64 -d >${keystore_file}; then
    echo "Error: Failed to decode and save the Android keystore."
    exit 1
fi

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=${keystore_file}
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=${keystore_user}
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=${keystore_password}

# shellcheck disable=SC2086
godot --path ${project_dir} --headless --export-release "${preset}" ${exported_file}

# shellcheck disable=SC2086
echo ${exported_file}
