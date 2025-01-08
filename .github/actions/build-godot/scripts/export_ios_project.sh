#!/bin/bash

if [ $# -ne 9 ]; then
    echo "::error::Usage: $0 <project_dir> <preset> <configuration> <filename> <extra_arguments> <certificate> <certificate_password> <provisioning_profile> <provisioning_profile_uuid>"
    exit 1
fi

project_dir="$1"
preset="$2"
configuration="$3"
filename="$4"
extra_arguments="$5"
certificate="$6"
certificate_password="$7"
provisioning_profile="$8"
provisioning_profile_uuid="$9"

builds_dir=~/.builds/ios
certificate_file="${builds_dir}/ios.p12"
provisioning_profile_file="${builds_dir}/${provisioning_profile_uuid}.mobileprovision"

if ! mkdir -p "${builds_dir}"; then
    echo "::error::Failed to create directory ${builds_dir}."
    exit 1
fi

if ! echo -n "${certificate}" | base64 -d >"${certificate_file}"; then
    echo "::error::Failed to decode and save the iOS .p12 certificate."
    exit 1
fi

if ! echo -n "${provisioning_profile}" | base64 -d >"${provisioning_profile_file}"; then
    echo "::error::Failed to decode and save the provisioning profile."
    exit 1
fi

if ! security import "${certificate_file}" -k ~/Library/Keychains/login.keychain-db -P "${certificate_password}" -T /usr/bin/codesign; then
    echo "::error::Failed to import the .p12 certificate into the login keychain."
    exit 1
fi

provisioning_dir=~/Library/MobileDevice/Provisioning\ Profiles
if ! mkdir -p "${provisioning_dir}"; then
    echo "::error::Failed to create provisioning profiles directory."
    exit 1
fi

if ! cp "${provisioning_profile_file}" "${provisioning_dir}"; then
    echo "::error::Failed to copy the provisioning profile."
    exit 1
fi

ipa_file="${builds_dir}/${filename}.ipa"

case "${configuration}" in
Debug)
    echo "::notice::Exporting debug build for iOS"
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_DEBUG="${provisioning_profile_uuid}"
    if ! godot --path "${project_dir}" --headless --quiet --export-debug "${preset}" "${ipa_file}" "${extra_arguments}"; then
        echo "::error::Godot export debug failed."
        exit 1
    fi
    ;;
Release)
    echo "::notice::Exporting release build for iOS"
    export GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE="${provisioning_profile_uuid}"
    if ! godot --path "${project_dir}" --headless --quiet --export-release "${preset}" "${ipa_file}" "${extra_arguments}"; then
        echo "::error::Godot export release failed."
        exit 1
    fi
    ;;
*)
    echo "::warning::Unsupported configuration: ${configuration}"
    exit 1
    ;;
esac

echo "::notice::Build completed successfully: ${ipa_file}"
echo "file=${ipa_file}" >>"$GITHUB_OUTPUT"
