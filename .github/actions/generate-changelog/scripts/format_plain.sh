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

features=$(echo "${RAW_CHANGELOG}" | jq -r '.features[]?' 2>/dev/null || echo "")
if [ -n "${features}" ]; then
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="• ${item}\n"
      has_content=true
    fi
  done <<< "${features}"
fi

fixes=$(echo "${RAW_CHANGELOG}" | jq -r '.fixes[]?' 2>/dev/null || echo "")
if [ -n "${fixes}" ]; then
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="• ${item}\n"
      has_content=true
    fi
  done <<< "${fixes}"
fi

refactors=$(echo "${RAW_CHANGELOG}" | jq -r '.refactors[]?' 2>/dev/null || echo "")
if [ -n "${refactors}" ]; then
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="• ${item}\n"
      has_content=true
    fi
  done <<< "${refactors}"
fi

if [ "${has_content}" = false ]; then
  formatted="Bug fixes and performance improvements.\n"
fi

{
  echo "changelog-plain<<EOF"
  printf "%b" "${formatted}"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
