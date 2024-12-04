#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 <presets_file> <preset_name> <key=value> [key=value] ..."
    echo "Example: $0 export_presets.cfg Android version/code=42 gradle_build/use_gradle_build=true"
    exit 1
fi

presets_file="$1"
preset_name="$2"
shift 2

if [ ! -f "${presets_file}" ]; then
    echo "Error: File ${presets_file} does not exist."
    exit 1
fi

preset_section=$(awk -v preset_name="$preset_name" '
    BEGIN { section_id = "" }
    /^\[preset\.[0-9]+\]/ { section_id = $0 }
    $0 ~ "name=\"" preset_name "\"" { print section_id; exit }
' "$presets_file")

if [ -z "$preset_section" ]; then
    echo "Error: Preset with name '${preset_name}' not found in ${presets_file}."
    exit 1
fi

escaped_section=$(echo "$preset_section" | sed 's/[][\/.^$*]/\\&/g')
temp_file=$(mktemp)
cp "${presets_file}" "${temp_file}"

for pair in "$@"; do
    key="${pair%%=*}"
    value="${pair#*=}"

    awk -v section="$escaped_section" -v key="$key" -v value="$value" '
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
    ' "$temp_file" >"${temp_file}.tmp" && mv "${temp_file}.tmp" "$temp_file"
done

mv "${temp_file}" "${presets_file}"
