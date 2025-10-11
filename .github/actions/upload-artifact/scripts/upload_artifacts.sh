#!/bin/bash

set -e

if [[ -z "${ARTIFACT_NAME}" ]]; then
  echo "::error::Artifact name is required."
  exit 1
fi

if [[ -z "${ARTIFACT_PATH}" ]]; then
  echo "::error::Artifact path is required."
  exit 1
fi

if ! [[ "${RETENTION_DAYS}" =~ ^[0-9]+$ ]] || [ "${RETENTION_DAYS}" -lt 1 ] || [ "${RETENTION_DAYS}" -gt 90 ]; then
  echo "::error::Retention days must be between 1 and 90."
  exit 1
fi

STAGING_DIR=$(mktemp -d)
METADATA_FILE="${STAGING_DIR}/.artifact_metadata.json"

echo "::notice::Preparing artifact: ${ARTIFACT_NAME}"

declare -a found_files=()
declare -a path_mappings=()

shopt -s dotglob nullglob

while IFS= read -r path; do
  path=$(echo "$path" | xargs)
  [[ -z "$path" ]] && continue

  declare -a expanded_paths
  eval "expanded_paths=($path)"

  for file_path in "${expanded_paths[@]}"; do
    if [[ -e "$file_path" ]]; then
      abs_path=$(realpath "$file_path")
      rel_path=$(realpath --relative-to="$PWD" "$abs_path")

      found_files+=("$abs_path")
      path_mappings+=("{\"original\":\"$rel_path\",\"absolute\":\"$abs_path\"}")
    fi
  done
done <<< "$ARTIFACT_PATH"

shopt -u nullglob dotglob

if [ ${#found_files[@]} -eq 0 ]; then
  echo "::warning::No files found to upload."
  exit 0
fi

echo "::notice::Found ${#found_files[@]} file(s)"

metadata_json=$(printf '%s\n' "${path_mappings[@]}" | jq -s '{
  version: "1.0",
  uploaded_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
  workflow: env.GITHUB_WORKFLOW,
  run_id: env.GITHUB_RUN_ID,
  repository: env.GITHUB_REPOSITORY,
  ref: env.GITHUB_REF,
  sha: env.GITHUB_SHA,
  include_hidden: true,
  paths: .
}')

echo "$metadata_json" > "$METADATA_FILE"

for file_path in "${found_files[@]}"; do
  rel_path=$(realpath --relative-to="$PWD" "$file_path")
  target_path="${STAGING_DIR}/${rel_path}"
  target_dir=$(dirname "$target_path")

  mkdir -p "$target_dir"
  cp -r "$file_path" "$target_path"
done

total_size=$(du -sb "${STAGING_DIR}" | cut -f1)
size_mb=$((total_size / 1024 / 1024))

echo "::notice::Prepared ${#found_files[@]} files (${size_mb}MB)"
echo "staging-dir=${STAGING_DIR}" >> "$GITHUB_OUTPUT"
