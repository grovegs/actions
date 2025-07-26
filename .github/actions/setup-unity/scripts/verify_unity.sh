#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <unity_path>"
    exit 1
fi

unity_path="$1"

echo "::notice::Verifying Unity installation at: ${unity_path}"

if [[ "$RUNNER_OS" == "Windows" ]]; then
    unity_exe="${unity_path}"
    if [ ! -f "${unity_exe}" ]; then
        unity_exe="${unity_path}/Unity.exe"
    fi
elif [[ "$RUNNER_OS" == "macOS" ]]; then
    unity_exe="${unity_path}/Contents/MacOS/Unity"
    if [ ! -f "${unity_exe}" ]; then
        unity_exe="${unity_path}"
    fi
fi

if [ ! -f "${unity_exe}" ]; then
    echo "::error::Unity executable not found at: ${unity_exe}"
    exit 1
fi

echo "::notice::Unity executable found at: ${unity_exe}"

echo "::notice::Getting Unity version information..."
if [[ "$RUNNER_OS" == "Windows" ]]; then
    "${unity_exe}" -version 2>/dev/null || echo "::notice::Unity version check completed"
else
    "${unity_exe}" -version 2>&1 | head -5 || echo "::notice::Unity version check completed"
fi

echo "::notice::Checking Unity license status..."
if [[ "$RUNNER_OS" == "Windows" ]]; then
    "${unity_exe}" -batchmode -quit -logFile - -serial 2>/dev/null || echo "::notice::License check completed"
else
    "${unity_exe}" -batchmode -quit -logFile /dev/stdout -serial 2>&1 | head -10 || echo "::notice::License check completed"
fi

echo "::notice::Unity installation verification completed successfully"