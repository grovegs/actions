#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <unity_path>"
    exit 1
fi

unity_path="$1"

echo "::notice::Verifying Unity installation at: ${unity_path}"

if [[ "$RUNNER_OS" == "Windows" ]]; then
    unity_exe="${unity_path}"
elif [[ "$RUNNER_OS" == "macOS" ]]; then
    unity_exe="${unity_path}/Contents/MacOS/Unity"
else
    unity_exe="${unity_path}"
fi

if [ ! -f "${unity_exe}" ]; then
    echo "::error::Unity executable not found at: ${unity_exe}"
    exit 1
fi

echo "::notice::Getting Unity version information..."
if [[ "$RUNNER_OS" == "Windows" ]]; then
    "${unity_exe}" -version || true
else
    "${unity_exe}" -version 2>&1 || true
fi

echo "::notice::Checking Unity license status..."
if [[ "$RUNNER_OS" == "Windows" ]]; then
    "${unity_exe}" -batchmode -quit -logFile - -serial || true
else
    "${unity_exe}" -batchmode -quit -logFile /dev/stdout -serial || true
fi

echo "::notice::Available build targets:"
if [[ "$RUNNER_OS" == "Windows" ]]; then
    "${unity_exe}" -batchmode -quit -logFile - -buildTarget || true
else
    "${unity_exe}" -batchmode -quit -logFile /dev/stdout -buildTarget || true
fi

echo "::notice::Unity installation verified successfully"