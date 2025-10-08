#!/bin/bash

if [ -z "${FILE}" ]; then
  echo "::error::No file specified."
  exit 1
fi

if [ -z "${APP_ID}" ]; then
  echo "::error::No app ID specified."
  exit 1
fi

if [ -z "${CREDENTIALS}" ]; then
  echo "::error::No credentials specified."
  exit 1
fi

firebase_dir=~/.firebase
credentials_file="${firebase_dir}/credentials_file.json"

if ! mkdir -p "${firebase_dir}"; then
  echo "::error::Failed to create directory ${firebase_dir}."
  exit 1
fi

if ! echo -n "${CREDENTIALS}" | base64 -d > "${credentials_file}"; then
  echo "::error::Failed to decode and save the Firebase credentials."
  exit 1
fi

echo "::notice::Setting up Firebase distribution with app ID: ${APP_ID}"

export GOOGLE_APPLICATION_CREDENTIALS="${credentials_file}"

firebase_args=(
  "appdistribution:distribute"
  "${FILE}"
  "--app"
  "${APP_ID}"
)

if [ -n "${RELEASE_NOTES}" ]; then
  echo "::notice::Adding release notes to distribution"
  NOTES_FILE=$(mktemp)
  printf '%s' "${RELEASE_NOTES}" > "${NOTES_FILE}"
  firebase_args+=(
    "--release-notes-file"
    "${NOTES_FILE}"
  )
fi

if [ -n "${TESTER_GROUPS}" ]; then
  echo "::notice::Distributing to tester groups: ${TESTER_GROUPS}"
  firebase_args+=(
    "--groups"
    "${TESTER_GROUPS}"
  )
fi

echo "::notice::Executing Firebase distribution command"
if ! firebase "${firebase_args[@]}"; then
  [ -n "${NOTES_FILE}" ] && rm -f "${NOTES_FILE}"
  echo "::error::Firebase distribution failed"
  exit 1
fi

[ -n "${NOTES_FILE}" ] && rm -f "${NOTES_FILE}"
echo "::notice::Firebase distribution completed successfully"
