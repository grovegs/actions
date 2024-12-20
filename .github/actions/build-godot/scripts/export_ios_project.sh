#!/bin/bash

if [ $# -ne 6 ]; then
    echo "Usage: $0 <project_dir> <preset> <configuration> <filename> <certificate> <provisioning_profile>"
    exit 1
fi

project_dir="$1"
preset="$2"
configuration="$3"
filename="$4"
certificate="$5"
provisioning_profile="$6"

builds_dir=~/.builds/ios
certificate_file=${builds_dir}/ios.cer
provisioning_profile_file=${builds_dir}/ios.mobileprovision

if ! mkdir -p ${builds_dir}; then
    echo "Error: Failed to create directory ${builds_dir}."
    exit 1
fi

if ! echo -n "${certificate}" | base64 -d >${certificate_file}; then
    echo "Error: Failed to decode and save the iOS distribution certificate."
    exit 1
fi

if ! echo -n "${provisioning_profile}" | base64 -d >${provisioning_profile_file}; then
    echo "Error: Failed to decode and save the provisioning profile."
    exit 1
fi

if ! sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${certificate_file}; then
    echo "Error: Failed to add the certificate to the keychain."
    exit 1
fi

provisioning_dir=~/Library/MobileDevice/Provisioning\ Profiles

if ! mkdir -p "${provisioning_dir}"; then
    echo "Error: Failed to create provisioning profiles directory."
    exit 1
fi

if ! cp "${provisioning_profile_file}" "${provisioning_dir}"; then
    echo "Error: Failed to copy the provisioning profile."
    exit 1
fi

file=${builds_dir}/"${filename}".ipa

case ${configuration} in
Debug)
    if ! godot --path "${project_dir}" --headless --quiet --export-debug "${preset}" "${file}"; then
        echo "Error: Godot export debug failed."
        exit 1
    fi
    ;;
Release)
    if ! godot --path "${project_dir}" --headless --quiet --export-release "${preset}" "${file}"; then
        echo "Error: Godot export release failed."
        exit 1
    fi
    ;;
*)
    echo "Unsupported configuration: ${configuration}"
    exit 1
    ;;
esac

echo "${file}"
