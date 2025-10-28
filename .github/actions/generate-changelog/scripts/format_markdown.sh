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

version=$(echo "${RAW_CHANGELOG}" | jq -r '.version // ""')
branch=$(echo "${RAW_CHANGELOG}" | jq -r '.branch // ""')

if [ -n "${branch}" ]; then
  formatted="## Release Notes v${version} (\`${branch}\`)\n\n"
else
  formatted="## Release Notes v${version}\n\n"
fi

has_content=false

features=$(echo "${RAW_CHANGELOG}" | jq -r '.features[]?' 2>/dev/null || echo "")
if [ -n "${features}" ]; then
  formatted+="### 🚀 Features\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${features}"
  formatted+="\n"
  has_content=true
fi

fixes=$(echo "${RAW_CHANGELOG}" | jq -r '.fixes[]?' 2>/dev/null || echo "")
if [ -n "${fixes}" ]; then
  formatted+="### 🐞 Bug Fixes\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${fixes}"
  formatted+="\n"
  has_content=true
fi

chores=$(echo "${RAW_CHANGELOG}" | jq -r '.chores[]?' 2>/dev/null || echo "")
if [ -n "${chores}" ]; then
  formatted+="### 🧹 Chores\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${chores}"
  formatted+="\n"
  has_content=true
fi

refactors=$(echo "${RAW_CHANGELOG}" | jq -r '.refactors[]?' 2>/dev/null || echo "")
if [ -n "${refactors}" ]; then
  formatted+="### 🔨 Refactors\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${refactors}"
  formatted+="\n"
  has_content=true
fi

tests=$(echo "${RAW_CHANGELOG}" | jq -r '.tests[]?' 2>/dev/null || echo "")
if [ -n "${tests}" ]; then
  formatted+="### 🧪 Tests\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${tests}"
  formatted+="\n"
  has_content=true
fi

ci=$(echo "${RAW_CHANGELOG}" | jq -r '.ci[]?' 2>/dev/null || echo "")
if [ -n "${ci}" ]; then
  formatted+="### 🔧 CI/CD\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${ci}"
  formatted+="\n"
  has_content=true
fi

reverts=$(echo "${RAW_CHANGELOG}" | jq -r '.reverts[]?' 2>/dev/null || echo "")
if [ -n "${reverts}" ]; then
  formatted+="### ⏪ Reverts\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${reverts}"
  formatted+="\n"
  has_content=true
fi

docs=$(echo "${RAW_CHANGELOG}" | jq -r '.docs[]?' 2>/dev/null || echo "")
if [ -n "${docs}" ]; then
  formatted+="### 📚 Documentation\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${docs}"
  formatted+="\n"
  has_content=true
fi

other=$(echo "${RAW_CHANGELOG}" | jq -r '.other[]?' 2>/dev/null || echo "")
if [ -n "${other}" ]; then
  formatted+="### 📦 Other\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="- ${item}\n"
  done <<< "${other}"
  formatted+="\n"
  has_content=true
fi

if [ "${has_content}" = false ]; then
  formatted+="No changes in this release.\n"
fi

{
  echo "changelog-markdown<<EOF"
  printf "%b" "${formatted}"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
