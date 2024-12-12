#!/bin/bash

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <file> <app_id> <credentials> [release_notes] [tester_groups]"
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
    echo "Error: No file found matching '${file}'."
    exit 1
fi

if ! mkdir -p ${firebase_dir}; then
    echo "Error: Failed to create directory ${firebase_dir}."
    exit 1
fi

if ! echo -n "${credentials}" | base64 -d >${credentials_file}; then
    echo "Error: Failed to decode and save the Firebase credentials."
    exit 1
fi

export GOOGLE_APPLICATION_CREDENTIALS=${credentials_file}
firebase_command="firebase appdistribution:distribute \"${file}\" --app \"${app_id}\""

if [ -n "${release_notes}" ]; then
    firebase_command+=" --release-notes \"${release_notes}\""
fi

if [ -n "${tester_groups}" ]; then
    firebase_command+=" --groups \"${tester_groups}\""
fi

eval "${firebase_command}"
