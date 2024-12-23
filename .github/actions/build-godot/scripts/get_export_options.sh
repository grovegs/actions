#!/bin/bash

if [ $# -ne 4 ]; then
    echo "Usage: $0 <platform> <version> <ios_team_id> <ios_provisioning_profile_uuid>"
    exit 1
fi

platform="$1"
version="$2"
ios_team_id="$3"
ios_provisioning_profile_uuid="$4"

IFS='.' read -r major minor patch <<<"$version"

if [[ -z "$major" || -z "$minor" || -z "$patch" ]]; then
    echo "Invalid version format. Expected format: major.minor.patch (e.g., 1.0.0)"
    exit 1
fi

case ${platform} in
Android)
    version_number=$(printf "%d%03d%04d" "$major" "$minor" "$patch")
    echo version/code="${version_number}" version/name=\""${version}"\"
    ;;
iOS)
    echo application/short_version="\"${version}\"" application/version="\"${version}\"" application/app_store_team_id="\"${ios_team_id}\"" application/provisioning_profile_uuid_release="\"${ios_provisioning_profile_uuid}\""
    ;;
*)
    echo "Unsupported platform: ${platform}"
    exit 1
    ;;
esac
