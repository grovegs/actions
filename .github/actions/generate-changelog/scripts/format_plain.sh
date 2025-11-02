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

branch=$(echo "${RAW_CHANGELOG}" | jq -r '.branch // ""')

if [ -n "${branch}" ]; then
  formatted="What's New (${branch})\n\n"
else
  formatted="What's New\n\n"
fi

has_content=false

features=$(echo "${RAW_CHANGELOG}" | jq -r '.features[]?' 2>/dev/null || echo "")
if [ -n "${features}" ]; then
  formatted+="\nFeatures:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${features}"
  has_content=true
fi

fixes=$(echo "${RAW_CHANGELOG}" | jq -r '.fixes[]?' 2>/dev/null || echo "")
if [ -n "${fixes}" ]; then
  formatted+="\nBug Fixes:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${fixes}"
  has_content=true
fi

chores=$(echo "${RAW_CHANGELOG}" | jq -r '.chores[]?' 2>/dev/null || echo "")
if [ -n "${chores}" ]; then
  formatted+="\nChores:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${chores}"
  has_content=true
fi

refactors=$(echo "${RAW_CHANGELOG}" | jq -r '.refactors[]?' 2>/dev/null || echo "")
if [ -n "${refactors}" ]; then
  formatted+="\nRefactors:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${refactors}"
  has_content=true
fi

tests=$(echo "${RAW_CHANGELOG}" | jq -r '.tests[]?' 2>/dev/null || echo "")
if [ -n "${tests}" ]; then
  formatted+="\nTests:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${tests}"
  has_content=true
fi

ci=$(echo "${RAW_CHANGELOG}" | jq -r '.ci[]?' 2>/dev/null || echo "")
if [ -n "${ci}" ]; then
  formatted+="\nCI/CD:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${ci}"
  has_content=true
fi

reverts=$(echo "${RAW_CHANGELOG}" | jq -r '.reverts[]?' 2>/dev/null || echo "")
if [ -n "${reverts}" ]; then
  formatted+="\nReverts:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${reverts}"
  has_content=true
fi

docs=$(echo "${RAW_CHANGELOG}" | jq -r '.docs[]?' 2>/dev/null || echo "")
if [ -n "${docs}" ]; then
  formatted+="\nDocumentation:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${docs}"
  has_content=true
fi

other=$(echo "${RAW_CHANGELOG}" | jq -r '.other[]?' 2>/dev/null || echo "")
if [ -n "${other}" ]; then
  formatted+="\nOther:\n"
  while IFS= read -r item; do
    [ -n "${item}" ] && formatted+="• ${item}\n"
  done <<< "${other}"
  has_content=true
fi

if [ "${has_content}" = false ]; then
  formatted+="No changes in this release.\n"
fi

{
  echo "changelog-plain<<EOF"
  printf "%b" "${formatted}"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
