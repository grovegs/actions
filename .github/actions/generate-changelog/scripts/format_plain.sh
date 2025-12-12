#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RAW_CHANGELOG:-}" ]; then
  echo "::error::RAW_CHANGELOG environment variable is required"
  exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "::error::jq is not installed or not in PATH"
  exit 1
fi

formatted=""
has_content=false

add_section() {
  local section_name="$1"
  local json_key="$2"

  local items
  items=$(echo "${RAW_CHANGELOG}" | jq -r ".${json_key}[]?" 2>/dev/null || echo "")

  if [ -n "${items}" ]; then
    formatted+="${section_name}\n"
    while IFS= read -r item; do
      if [ -n "${item}" ]; then
        formatted+="• ${item}\n"
        has_content=true
      fi
    done <<< "${items}"
    formatted+="\n"
  fi
}

add_section "Features" "features"
add_section "Bug Fixes" "fixes"
add_section "Performance" "perf"
add_section "Refactors" "refactors"
add_section "Tests" "tests"

if [ "${has_content}" = false ]; then
  formatted="Bug fixes and performance improvements.\n"
fi

formatted=$(printf "%b" "${formatted}" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

{
  echo "changelog-plain<<EOF"
  printf "%s\n" "${formatted}"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
