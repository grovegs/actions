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
  formatted+="### 🚀 Features\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${features}"
  formatted+="\n"
fi

fixes=$(echo "${RAW_CHANGELOG}" | jq -r '.fixes[]?' 2>/dev/null || echo "")
if [ -n "${fixes}" ]; then
  formatted+="### 🐞 Bug Fixes\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${fixes}"
  formatted+="\n"
fi

chores=$(echo "${RAW_CHANGELOG}" | jq -r '.chores[]?' 2>/dev/null || echo "")
if [ -n "${chores}" ]; then
  formatted+="### 🧹 Chores\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${chores}"
  formatted+="\n"
fi

refactors=$(echo "${RAW_CHANGELOG}" | jq -r '.refactors[]?' 2>/dev/null || echo "")
if [ -n "${refactors}" ]; then
  formatted+="### 🔨 Refactors\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${refactors}"
  formatted+="\n"
fi

tests=$(echo "${RAW_CHANGELOG}" | jq -r '.tests[]?' 2>/dev/null || echo "")
if [ -n "${tests}" ]; then
  formatted+="### 🧪 Tests\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${tests}"
  formatted+="\n"
fi

ci=$(echo "${RAW_CHANGELOG}" | jq -r '.ci[]?' 2>/dev/null || echo "")
if [ -n "${ci}" ]; then
  formatted+="### 🔧 CI/CD\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${ci}"
  formatted+="\n"
fi

reverts=$(echo "${RAW_CHANGELOG}" | jq -r '.reverts[]?' 2>/dev/null || echo "")
if [ -n "${reverts}" ]; then
  formatted+="### ⏪ Reverts\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${reverts}"
  formatted+="\n"
fi

docs=$(echo "${RAW_CHANGELOG}" | jq -r '.docs[]?' 2>/dev/null || echo "")
if [ -n "${docs}" ]; then
  formatted+="### 📚 Documentation\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${docs}"
  formatted+="\n"
fi

other=$(echo "${RAW_CHANGELOG}" | jq -r '.other[]?' 2>/dev/null || echo "")
if [ -n "${other}" ]; then
  formatted+="### 📦 Other\n"
  while IFS= read -r item; do
    if [ -n "${item}" ]; then
      formatted+="- ${item}\n"
      has_content=true
    fi
  done <<< "${other}"
  formatted+="\n"
fi

if [ "${has_content}" = false ]; then
  formatted="No changes in this release.\n"
fi

{
  echo "changelog-markdown<<EOF"
  printf "%b" "${formatted}"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
