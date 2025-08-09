#!/bin/bash
set -e
if [ "$#" -ne 3 ]; then
    echo "::error::Usage: $0 <username> <password> <serial>"
    exit 1
fi
username="$1"
password="$2"
serial="$3"
if [ -z "$UNITY_PATH" ]; then
    echo "::error::UNITY_PATH environment variable not set. Run configure_environment.sh first."
    exit 1
fi
echo "::notice::Attempting to activate Unity license..."
activation_command=(
    "$UNITY_PATH"
    -batchmode
    -nographics
    -quit
    -username "$username"
    -password "$password"
    -serial "$serial"
)
"${activation_command[@]}" | tr -d '\r' || true
ulf_path=""
if [[ "$RUNNER_OS" == "macOS" ]]; then
    ulf_path="/Library/Application Support/Unity/Unity_lic.ulf"
elif [[ "$RUNNER_OS" == "Linux" ]]; then
    ulf_path="$HOME/.local/share/unity3d/Unity/Unity_lic.ulf"
fi
if [ -f "$ulf_path" ]; then
    echo "::notice::Unity license activated successfully."
else
    echo "::error::Unity license activation failed."
    exit 1
fi