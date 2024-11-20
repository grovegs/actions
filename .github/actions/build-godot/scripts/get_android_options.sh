#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

version="$1"

IFS='.' read -r major minor patch <<<"$version"

if [[ -z "$major" || -z "$minor" || -z "$patch" ]]; then
    echo "Invalid version format. Expected format: major.minor.patch (e.g., 1.0.0)"
    exit 1
fi

version_number=$(printf "%d%03d%04d" "$major" "$minor" "$patch")

echo version/code="${version_number}" version/name="\"${version}\""
