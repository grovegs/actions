#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PRESETS_FILE:-}" ]; then
  echo "::error::PRESETS_FILE environment variable is required"
  exit 1
fi

if [ -z "${PRESET_NAME:-}" ]; then
  echo "::error::PRESET_NAME environment variable is required"
  exit 1
fi

if [ -z "${EXPORT_OPTIONS:-}" ]; then
  echo "::error::EXPORT_OPTIONS environment variable is required"
  exit 1
fi

if [ ! -f "${PRESETS_FILE}" ]; then
  echo "::error::File ${PRESETS_FILE} does not exist"
  exit 1
fi

PRESET_SECTION=$(awk -v preset_name="${PRESET_NAME}" '
    BEGIN { section_id = "" }
    /^\[preset\.[0-9]+\]/ { section_id = $0 }
    $0 ~ "name=\"" preset_name "\"" { print section_id; exit }
' "${PRESETS_FILE}")

if [ -z "${PRESET_SECTION}" ]; then
  echo "::error::Preset with name '${PRESET_NAME}' not found in ${PRESETS_FILE}"
  exit 1
fi

TEMP_FILE=$(mktemp)
cp "${PRESETS_FILE}" "${TEMP_FILE}"

read -ra OPTIONS_ARRAY <<< "${EXPORT_OPTIONS}"

for pair in "${OPTIONS_ARRAY[@]}"; do
  KEY="${pair%%=*}"
  VALUE="${pair#*=}"

  awk -v section="${PRESET_SECTION}" -v key="${KEY}" -v value="${VALUE}" '
    BEGIN { in_section = 0 }
    $0 ~ section { in_section = 1 }
    in_section && /^\[/ && $0 != section { in_section = 0 }
    in_section {
        if ($0 ~ "^[[:space:]]*" key "=") {
            current_value = substr($0, index($0, "=") + 1)
            if (value ~ /^".*"$/) {
                sub(/=.*/, "=" value, $0)
            } else if (current_value ~ /^".*"$/) {
                sub(/=.*/, "=" "\"" value "\"", $0)
            } else {
                sub(/=.*/, "=" value, $0)
            }
        }
    }
    { print }
    ' "${TEMP_FILE}" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "${TEMP_FILE}"
done

mv "${TEMP_FILE}" "${PRESETS_FILE}"
echo "::notice::Successfully updated ${PRESETS_FILE} for preset '${PRESET_NAME}'"
