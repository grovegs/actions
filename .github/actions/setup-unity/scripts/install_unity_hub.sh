#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <hub_version>"
    exit 1
fi

hub_version="$1"

echo "::notice::Installing Unity Hub ${hub_version}"

if [[ "$RUNNER_OS" != "Windows" && "$RUNNER_OS" != "macOS" ]]; then
    echo "::error::Unity Hub is only supported on Windows and macOS platforms"
    echo "::error::Current platform: $RUNNER_OS"
    echo "::error::Please use a Windows or macOS runner for Unity development"
    exit 1
fi

if command -v unity-hub &>/dev/null; then
    echo "::notice::Unity Hub is already installed"
    unity-hub --version || true
    echo "hub_path=$(which unity-hub)" >> "$GITHUB_OUTPUT"
    exit 0
fi

if [[ "$RUNNER_OS" == "macOS" ]]; then
    echo "::notice::Installing Unity Hub on macOS"
    
    hub_url="https://public-cdn.cloud.unity3d.com/hub/prod/UnityHubSetup.dmg"
    curl -L -o UnityHub.dmg "${hub_url}"
    
    echo "::notice::Attaching DMG..."
    sudo hdiutil attach UnityHub.dmg
    
    echo "::notice::Finding mounted Unity Hub volume..."
    unity_hub_volume=$(find /Volumes -name "*Unity Hub*" -type d | head -1)
    
    if [ -z "$unity_hub_volume" ]; then
        echo "::error::Could not find Unity Hub volume in /Volumes"
        sudo hdiutil detach /dev/disk* 2>/dev/null || true
        exit 1
    fi
    
    echo "::notice::Found Unity Hub volume at: ${unity_hub_volume}"
    
    unity_hub_app=$(find "$unity_hub_volume" -name "Unity Hub.app" -type d | head -1)
    
    if [ -z "$unity_hub_app" ]; then
        echo "::error::Could not find Unity Hub.app in ${unity_hub_volume}"
        sudo hdiutil detach "$unity_hub_volume" 2>/dev/null || true
        exit 1
    fi
    
    echo "::notice::Found Unity Hub.app at: ${unity_hub_app}"
    echo "::notice::Copying Unity Hub to Applications..."
    sudo cp -R "$unity_hub_app" /Applications/
    
    echo "::notice::Detaching DMG..."
    sudo hdiutil detach "$unity_hub_volume"
    rm UnityHub.dmg
    
    sudo ln -s "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub" /usr/local/bin/unity-hub
    
    hub_path="/usr/local/bin/unity-hub"
    
elif [[ "$RUNNER_OS" == "Windows" ]]; then
    echo "::notice::Installing Unity Hub on Windows"
    
    hub_url="https://public-cdn.cloud.unity3d.com/hub/prod/UnityHubSetup.exe"
    curl -L -o UnityHubSetup.exe "${hub_url}"
    
    echo "::notice::Running Unity Hub installer..."
    ./UnityHubSetup.exe /S
    
    echo "::notice::Waiting for installation to complete..."
    sleep 30
    
    hub_path="C:/Program Files/Unity Hub/Unity Hub.exe"
fi

if [ ! -f "${hub_path}" ] && ! command -v unity-hub &>/dev/null; then
    echo "::error::Unity Hub installation failed"
    echo "::error::Expected path: ${hub_path}"
    exit 1
fi

echo "::notice::Unity Hub installed successfully"
echo "hub_path=${hub_path}" >> "$GITHUB_OUTPUT"

echo "::notice::Accepting Unity Hub license"
if command -v unity-hub &>/dev/null; then
    unity-hub -- --accept-license || true
else
    "${hub_path}" -- --accept-license || true
fi