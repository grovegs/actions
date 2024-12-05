#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <project> <configuration> <version>"
    exit 1
fi

project="$1"
configuration="$2"
version="$3"

if [[ -z "${project}" ]]; then
    echo "Error: Project input is required."
    exit 1
fi

if [[ -z "${configuration}" ]]; then
    echo "Error: Configuration input is required."
    exit 1
fi

version_flag=""
if [[ -n "${version}" ]]; then
    version_flag="-p:Version=${version}"
fi

dotnet build --nologo --configuration "${configuration}" "${project}" "${version_flag}"
