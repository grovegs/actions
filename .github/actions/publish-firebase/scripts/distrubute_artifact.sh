#!/bin/bash

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <artifact_name> <app_id> <credentials> [release_notes] [tester_groups]"
    exit 1
fi

artifact_name="$1"
app_id="$2"
credentials="$3"
release_notes="${4:-}"
tester_groups="${5:-}"

artifacts_dir=~/.artifacts
firebase_dir=~/.firebase
artifact=$(find "${artifacts_dir}" -type f -name "${artifact_name}*" | head -n 1)
credentials_file=${firebase_dir}/credentials_file.json

if [ -z "${artifact}" ]; then
    echo "Error: No artifact found matching '${artifact_name}' in '${artifacts_dir}'"
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
firebase_command="firebase appdistribution:distribute \"${artifact}\" --app \"${app_id}\""

if [ -n "${release_notes}" ]; then
    firebase_command+=" --release-notes \"${release_notes}\""
fi

if [ -n "${tester_groups}" ]; then
    firebase_command+=" --groups \"${tester_groups}\""
fi

eval "${firebase_command}"
