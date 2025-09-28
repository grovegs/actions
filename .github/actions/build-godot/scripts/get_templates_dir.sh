#!/bin/bash

if [ $# -ne 1 ]; then
  echo "::error::Usage: $0 <runner_os>"
  exit 1
fi

runner_os="$1"
echo "::notice::Processing templates directory for ${runner_os}"

case ${runner_os} in
  "Linux")
    templates_dir=~/.local/share/godot/export_templates
    ;;
  "macOS")
    templates_dir=~/Library/Application\ Support/Godot/export_templates
    ;;
  *)
    echo "::error::Unsupported platform ${runner_os}."
    exit 1
    ;;
esac

echo "::notice::Templates directory set to: ${templates_dir}"
echo templates_dir="${templates_dir}" >> "$GITHUB_OUTPUT"
