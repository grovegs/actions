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

activation_output=$(mktemp)
activation_command=(
    "$UNITY_PATH"
    -batchmode
    -nographics
    -quit
    -username "$username"
    -password "$password"
    -serial "$serial"
    -logFile "$activation_output"
)

"${activation_command[@]}" || true

if [ -f "$activation_output" ]; then
    echo "::notice::Unity activation log:"
    cat "$activation_output" | tr -d '\r'
    rm -f "$activation_output"
fi

ulf_path=""
case "$RUNNER_OS" in
    "macOS")
        ulf_path="/Library/Application Support/Unity/Unity_lic.ulf"
        ;;
    "Linux")
        ulf_path="$HOME/.local/share/unity3d/Unity/Unity_lic.ulf"
        ;;
    "Windows")
        ulf_path="/c/ProgramData/Unity/Unity_lic.ulf"
        ;;
    *)
        echo "::error::Unsupported platform for license activation: $RUNNER_OS"
        exit 1
        ;;
esac

if [ -f "$ulf_path" ]; then
    echo "::notice::Unity license activated successfully."
    echo "::notice::License file location: $ulf_path"
else
    echo "::error::Unity license activation failed."
    echo "::error::License file not found at expected location: $ulf_path"
    exit 1
fi