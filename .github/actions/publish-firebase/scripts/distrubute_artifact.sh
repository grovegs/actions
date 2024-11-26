#!/bin/bash

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <artifact_name> <app_id> <token> [release_notes] [tester_groups]"
    exit 1
fi

artifact_name="$1"
app_id="$2"
token="$3"
release_notes="${4:-}"
tester_groups="${5:-}"

artifacts_dir=~/.artifacts
artifact=$(find "${artifacts_dir}" -type f -name "${artifact_name}*" | head -n 1)

if [ -z "${artifact}" ]; then
    echo "Error: No artifact found matching '${artifact_name}' in '${artifacts_dir}'"
    exit 1
fi

firebase_command="firebase appdistribution:distribute \"${artifact}\" --app \"${app_id}\" --token \"${token}\""

if [ -n "${release_notes}" ]; then
    firebase_command+=" --release-notes \"${release_notes}\""
fi

if [ -n "${tester_groups}" ]; then
    firebase_command+=" --groups \"${tester_groups}\""
fi

eval "${firebase_command}"

echo "Artifact '${artifact}' successfully distributed to Firebase."
