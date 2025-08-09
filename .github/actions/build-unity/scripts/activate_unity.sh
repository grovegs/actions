#!/bin/bash
set -e

if [ "$#" -ne 3 ]; then
    echo "::error::Usage: $0 <username> <password> <serial>"
    exit 1
fi

username="$1"
password="$2"
serial="$3"

if ! command -v unity &> /dev/null; then
    echo "::error::Unity command not found. Please ensure Unity is installed and in PATH."
    exit 1
fi

get_license_path() {
    if [[ "$RUNNER_OS" == "macOS" ]]; then
        echo "/Library/Application Support/Unity/Unity_lic.ulf"
    elif [[ "$RUNNER_OS" == "Linux" ]]; then
        echo "$HOME/.local/share/unity3d/Unity/Unity_lic.ulf"
    else
        echo ""
    fi
}

ulf_path=$(get_license_path)

if [ -z "$ulf_path" ]; then
    echo "::error::Unsupported operating system: $RUNNER_OS"
    exit 1
fi

if [ -f "$ulf_path" ]; then
    echo "::notice::Unity license file already exists, checking validity..."
    if unity -batchmode -nographics -quit -logFile - 2>&1 | grep -q "LICENSE SYSTEM.*OK"; then
        echo "::notice::Existing Unity license is valid"
        exit 0
    else
        echo "::notice::Existing license is invalid, removing..."
        rm -f "$ulf_path"
    fi
fi

echo "::notice::Attempting to activate Unity license..."

for attempt in {1..3}; do
    echo "::notice::License activation attempt $attempt..."
    
    if unity -batchmode -nographics -quit -username "${username}" -password "${password}" -serial "${serial}" -logFile - 2>&1 | tr -d '\r'; then
        if [ -f "$ulf_path" ]; then
            echo "::notice::Unity license activated successfully on attempt $attempt"
            exit 0
        fi
    fi
    
    if [ "$attempt" -lt 3 ]; then
        echo "::warning::License activation attempt $attempt failed, retrying in 5 seconds..."
        sleep 5
    fi
done

echo "::error::Unity license activation failed after 3 attempts"
exit 1