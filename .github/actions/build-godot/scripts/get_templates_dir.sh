#!/usr/bin/env bash
set -euo pipefail

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

echo "::notice::Processing templates directory for ${RUNNER_OS}"

case "${RUNNER_OS}" in
  "Linux")
    TEMPLATES_DIR=~/.local/share/godot/export_templates
    ;;
  "macOS")
    TEMPLATES_DIR=~/Library/Application\ Support/Godot/export_templates
    ;;
  *)
    echo "::error::Unsupported platform: ${RUNNER_OS}"
    exit 1
    ;;
esac

{
  echo "::notice::Templates directory set to: ${TEMPLATES_DIR}"
  echo "templates-dir=${TEMPLATES_DIR}"
} >> "${GITHUB_OUTPUT}"
