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

case "${RUNNER_OS}" in
  "Linux")
    GODOT_EXECUTABLE="${HOME}/.godot/Godot_v${GODOT_VERSION}/Godot_v${GODOT_VERSION}-${GODOT_STAGE}_mono_linux.x86_64"
    GODOT_SHARP="${HOME}/.godot/Godot_v${GODOT_VERSION}/GodotSharp"
    ;;
  "macOS")
    GODOT_EXECUTABLE="${HOME}/.godot/Godot_v${GODOT_VERSION}.app/Contents/MacOS/Godot"
    GODOT_SHARP="${HOME}/.godot/Godot_v${GODOT_VERSION}.app/Contents/Resources/GodotSharp"
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

if [ -L "/usr/local/bin/godot" ]; then
  echo "::notice::Removing existing Godot symlink"
  sudo rm -f /usr/local/bin/godot
fi

if [ -L "/usr/local/bin/GodotSharp" ]; then
  echo "::notice::Removing existing GodotSharp symlink"
  sudo rm -f /usr/local/bin/GodotSharp
fi

echo "::notice::Creating symlink for Godot executable"
sudo ln -s "${GODOT_EXECUTABLE}" /usr/local/bin/godot

echo "::notice::Creating symlink for GodotSharp"
sudo ln -s "${GODOT_SHARP}" /usr/local/bin/GodotSharp

echo "::notice::✓ Godot installation completed successfully"
