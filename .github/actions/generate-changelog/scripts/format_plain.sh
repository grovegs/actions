#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RAW_CHANGELOG:-}" ]; then
  echo "::error::RAW_CHANGELOG environment variable is required"
  exit 1
fi

if [ -z "${VERSION:-}" ]; then
  echo "::error::VERSION environment variable is required"
  exit 1
fi

sanitize_text() {
  local text="$1"
  text="${text//\`/\\\`}"
  printf "%s" "${text}"
}

branch_name=""
if [[ "${RAW_CHANGELOG}" =~ ^BRANCH:([^$'\n']+) ]]; then
  branch_name="${BASH_REMATCH[1]}"
  RAW_CHANGELOG=$(printf "%s" "${RAW_CHANGELOG}" | sed '1d')
fi

if [[ "${RAW_CHANGELOG}" == "No changes in this release." ]]; then
  if [ -n "${branch_name}" ]; then
    formatted="Release Notes v${VERSION} (${branch_name})\n\nNo changes in this release."
  else
    formatted="Release Notes v${VERSION}\n\nNo changes in this release."
  fi
else
  if [ -n "${branch_name}" ]; then
    formatted="Release Notes v${VERSION} (${branch_name})\n\n"
  else
    formatted="Release Notes v${VERSION}\n\n"
  fi

  while IFS= read -r line; do
    line=$(sanitize_text "${line}")

    if [[ "${line}" =~ ^[A-Z] ]] && [[ ! "${line}" =~ ^[A-Za-z]+: ]]; then
      formatted+="\n${line}:\n"
    elif [ -n "${line}" ]; then
      formatted+="• ${line}\n"
    fi
  done <<< "${RAW_CHANGELOG}"
fi

{
  echo "changelog-plain<<EOF"
  printf "%b" "${formatted}"
  echo ""
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
