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
  local section_icon="$2"
  local json_key="$3"

  local items
  items=$(echo "${RAW_CHANGELOG}" | jq -c ".${json_key}[]?" 2>/dev/null || echo "")

  if [ -n "${items}" ]; then
    formatted+="### ${section_icon} ${section_name}\n"
    while IFS= read -r item; do
      if [ -n "${item}" ]; then
        local scope
        local description
        scope=$(echo "${item}" | jq -r '.scope')
        description=$(echo "${item}" | jq -r '.description')

        if [ -n "${scope}" ] && [ "${scope}" != "null" ] && [ "${scope}" != "" ]; then
          formatted+="- **${scope}**: ${description}\n"
        else
          formatted+="- ${description}\n"
        fi
        has_content=true
      fi
    done <<< "${items}"
    formatted+="\n"
  fi
}

add_section "Features" "🚀" "features"
add_section "Bug Fixes" "🐞" "fixes"
add_section "Performance" "⚡" "perf"
add_section "Refactors" "🔨" "refactors"
add_section "Documentation" "📚" "docs"
add_section "Tests" "🧪" "tests"
add_section "CI/CD" "🔧" "ci"
add_section "Chores" "🧹" "chores"
add_section "Reverts" "⏪" "reverts"

other=$(echo "${RAW_CHANGELOG}" | jq -c '.other[]?' 2>/dev/null || echo "")
if [ -n "${other}" ]; then
  formatted+="### 📦 Other\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      local description
      description=$(echo "${item}" | jq -r '.description')
      formatted+="- ${description}\n"
      has_content=true
    fi
  done <<< "${other}"
  formatted+="\n"
fi

if [ "${has_content}" = false ]; then
  formatted="No changes in this release.\n"
fi

formatted=$(printf "%b" "${formatted}" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

{
  echo "changelog-markdown<<EOF"
  printf "%s\n" "${formatted}"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
