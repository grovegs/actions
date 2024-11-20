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

echo application/short_version="\"${version}\"" application/version="\"${version}\""
