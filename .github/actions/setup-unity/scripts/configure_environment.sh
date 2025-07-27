#!/bin/bash
set -e
if [ "$#" -ne 1 ]; then echo "::error::Usage: $0 <unity_version>"; exit 1; fi
unity_version="$1"; echo "::notice::Locating Unity ${unity_version} to configure environment..."; unity_exe_path=""; editor_dir=""
if [[ "$RUNNER_OS" == "macOS" ]]; then
    unity_app_path=$(find /Applications -path "*/Unity.app" -type d 2>/dev/null | grep -i "${unity_version}" | head -1)
    if [ -n "$unity_app_path" ]; then unity_exe_path="${unity_app_path}/Contents/MacOS/Unity"; fi
elif [[ "$RUNNER_OS" == "Linux" ]]; then
    unity_exe_path=$(find "$HOME/Unity-${unity_version}" -name Unity -type f -executable | head -1)
fi
if [ -z "$unity_exe_path" ]; then echo "::error::Failed to find Unity ${unity_version} installation after setup."; exit 1; fi
echo "::notice::Found Unity executable at: ${unity_exe_path}"; editor_dir=$(dirname "${unity_exe_path}")
echo "::notice::Adding Unity to the PATH..."; echo "UNITY_PATH=${unity_exe_path}" >> "$GITHUB_ENV"; echo "UNITY_VERSION=${unity_version}" >> "$GITHUB_ENV"; echo "${editor_dir}" >> "$GITHUB_PATH"
echo "::notice::Unity environment configured successfully."