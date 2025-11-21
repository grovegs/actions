#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GODOT_VERSION:-}" ]; then
  echo "::error::GODOT_VERSION environment variable is required"
  exit 1
fi

if [ -z "${GODOT_STAGE:-}" ]; then
  echo "::error::GODOT_STAGE environment variable is required"
  exit 1
fi

if [ -z "${RUNNER_OS:-}" ]; then
  echo "::error::RUNNER_OS environment variable is required"
  exit 1
fi

GODOT_PATH_INPUT="${GODOT_PATH:-}"

if [ -n "${GODOT_PATH_INPUT}" ]; then
  EDITOR_DIR="${GODOT_PATH_INPUT}"
else
  EDITOR_DIR="${HOME}/.godot"
fi

case "${RUNNER_OS}" in
  "Linux")
    GODOT_EXECUTABLE="${EDITOR_DIR}/Godot_v${GODOT_VERSION}/Godot_v${GODOT_VERSION}-${GODOT_STAGE}_mono_linux.x86_64"
    GODOT_SHARP="${EDITOR_DIR}/Godot_v${GODOT_VERSION}/GodotSharp"
    ;;
  "macOS")
    GODOT_EXECUTABLE="${EDITOR_DIR}/Godot_v${GODOT_VERSION}.app/Contents/MacOS/Godot"
    GODOT_SHARP="${EDITOR_DIR}/Godot_v${GODOT_VERSION}.app/Contents/Resources/GodotSharp"
    ;;
  *)
    echo "::error::Unsupported platform: ${RUNNER_OS}"
    exit 1
    ;;
esac

if [ ! -f "${GODOT_EXECUTABLE}" ]; then
  echo "::error::Godot executable not found: ${GODOT_EXECUTABLE}"
  exit 1
fi

if [ ! -d "${GODOT_SHARP}" ]; then
  echo "::error::GodotSharp directory not found: ${GODOT_SHARP}"
  exit 1
fi

echo "::notice::Exporting Godot environment variables"

echo "GODOT_PATH=${EDITOR_DIR}" >> "${GITHUB_ENV}"
echo "godot-path=${EDITOR_DIR}" >> "${GITHUB_OUTPUT}"

echo "::notice::Environment variables exported:"
echo "::notice::  GODOT_PATH=${EDITOR_DIR}"

echo "::notice::✅ Godot installation completed successfully"
