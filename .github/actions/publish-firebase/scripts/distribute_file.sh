#!/bin/bash

if [ "$#" -lt 3 ]; then
    echo "::error::Usage: $0 <file> <app_id> <credentials> [release_notes] [tester_groups]"
    exit 1
fi

file="$1"
app_id="$2"
credentials="$3"
release_notes="${4:-}"
tester_groups="${5:-}"

firebase_dir=~/.firebase
credentials_file=${firebase_dir}/credentials_file.json

if [ -z "${file}" ]; then
    echo "::error::No file found matching '${file}'."
    exit 1
fi

if ! mkdir -p ${firebase_dir}; then
    echo "::error::Failed to create directory ${firebase_dir}."
    exit 1
fi

if ! echo -n "${credentials}" | base64 -d >${credentials_file}; then
    echo "::error::Failed to decode and save the Firebase credentials."
    exit 1
fi

echo "::notice::Setting up Firebase distribution with app ID: ${app_id}"

export GOOGLE_APPLICATION_CREDENTIALS=${credentials_file}
firebase_command="firebase appdistribution:distribute \"${file}\" --app \"${app_id}\""

if [ -n "${release_notes}" ]; then
    echo "::notice::Adding release notes to distribution"
    firebase_command+=" --release-notes \"${release_notes}\""
fi

if [ -n "${tester_groups}" ]; then
    echo "::notice::Distributing to tester groups: ${tester_groups}"
    firebase_command+=" --groups \"${tester_groups}\""
fi

echo "::notice::Executing Firebase distribution command"
if ! eval "${firebase_command}"; then
    echo "::error::Firebase distribution failed"
    exit 1
fi

echo "::notice::Firebase distribution completed successfully"
