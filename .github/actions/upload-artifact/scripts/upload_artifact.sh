#!/bin/bash
set -euo pipefail

STAGING_DIR="${GITHUB_WORKSPACE}/.artifact-staging-${ARTIFACT_NAME}"
METADATA_FILE="${STAGING_DIR}/.artifact-meta.json"
WORKSPACE="${GITHUB_WORKSPACE}"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "Preparing artifact: ${ARTIFACT_NAME}"

mapfile -t PATHS <<< "$ARTIFACT_PATH"

FILES_FOUND=0
declare -a FILE_ENTRIES

if [ "$INCLUDE_HIDDEN" = "true" ]; then
  shopt -s dotglob
fi
shopt -s nullglob

for path_pattern in "${PATHS[@]}"; do
  path_pattern=$(echo "$path_pattern" | xargs)

  [ -z "$path_pattern" ] && continue

  [[ "$path_pattern" == !* ]] && continue

  cd "$WORKSPACE"

  for item in $path_pattern; do
    [ ! -e "$item" ] && continue

    if [ -f "$item" ]; then
      ITEM_DIR=$(cd "$(dirname "$item")" && pwd)
      ITEM_NAME=$(basename "$item")
      ABS_PATH="${ITEM_DIR}/${ITEM_NAME}"
    elif [ -d "$item" ]; then
      ABS_PATH=$(cd "$item" && pwd)
    else
      continue
    fi

    REL_PATH="${ABS_PATH#"${WORKSPACE}"/}"

    if [ "$REL_PATH" = "$ABS_PATH" ]; then
      echo "::warning::Skipping item outside workspace: $item"
      continue
    fi

    TARGET_DIR="${STAGING_DIR}/$(dirname "$REL_PATH")"
    mkdir -p "$TARGET_DIR"

    if [ -f "$item" ]; then
      cp -p "$item" "${STAGING_DIR}/${REL_PATH}"
    elif [ -d "$item" ]; then
      cp -rp "$item" "${STAGING_DIR}/${REL_PATH}"
    fi

    FILE_ENTRIES+=("$REL_PATH")
    FILES_FOUND=$((FILES_FOUND + 1))
  done
done

shopt -u nullglob
if [ "$INCLUDE_HIDDEN" = "true" ]; then
  shopt -u dotglob
fi

cat > "$METADATA_FILE" << EOF
{
  "version": "1.0",
  "artifact_name": "${ARTIFACT_NAME}",
  "workspace": "${WORKSPACE}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "files_count": ${FILES_FOUND},
  "files": [
EOF

FIRST=true
for entry in "${FILE_ENTRIES[@]}"; do
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo "," >> "$METADATA_FILE"
  fi
  echo -n "    \"${entry}\"" >> "$METADATA_FILE"
done

cat >> "$METADATA_FILE" << EOF

  ]
}
EOF

echo "Files prepared: ${FILES_FOUND}"
echo "staging-dir=${STAGING_DIR}" >> "$GITHUB_OUTPUT"
