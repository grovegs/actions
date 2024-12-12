#!/bin/bash

set -x

if [ $# -ne 2 ]; then
    echo "Usage: $0 <platform> <version>"
    exit 1
fi

platform="$1"
version="$2"

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
    echo application/short_version="\"${version}\"" application/version="\"${version}\""
    ;;
*)
    echo "Unsupported platform: ${platform}"
    exit 1
    ;;
esac
