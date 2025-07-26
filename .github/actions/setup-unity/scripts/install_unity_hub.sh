#!/bin/bash

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <hub_version>"
    exit 1
fi

hub_version="$1"

echo "::notice::Installing Unity Hub ${hub_version}"

if command -v unityhub &>/dev/null; then
    echo "::notice::Unity Hub is already installed"
    unityhub --version || true
    echo "hub_path=$(which unityhub)" >> "$GITHUB_OUTPUT"
    exit 0
fi

if [[ "$RUNNER_OS" == "Linux" ]]; then
    echo "::notice::Installing Unity Hub on Linux"
    
    # Use the updated repository URL and modern keyring approach
    curl -fsSL https://hub.unity3d.com/linux/keys/public | sudo gpg --dearmor -o /usr/share/keyrings/unity-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/unity-archive-keyring.gpg] https://hub.unity3d.com/linux/repos/deb stable main" | sudo tee /etc/apt/sources.list.d/unityhub.list
    
    sudo apt-get update
    sudo apt-get install -y unityhub
    
    hub_path="/usr/bin/unityhub"
    
    echo "::notice::Setting up Unity Hub directories"
    mkdir -p ~/.config/UnityHub
    mkdir -p ~/Unity/Hub/Editor
    
elif [[ "$RUNNER_OS" == "macOS" ]]; then
    echo "::notice::Installing Unity Hub on macOS"
    
    hub_url="https://public-cdn.cloud.unity3d.com/hub/prod/UnityHubSetup.dmg"
    curl -L -o UnityHub.dmg "${hub_url}"
    
    echo "::notice::Attaching DMG..."
    sudo hdiutil attach UnityHub.dmg
    
    # Find the mounted volume dynamically
    echo "::notice::Finding mounted Unity Hub volume..."
    unity_hub_volume=$(find /Volumes -name "*Unity Hub*" -type d | head -1)
    
    if [ -z "$unity_hub_volume" ]; then
        echo "::error::Could not find Unity Hub volume in /Volumes"
        sudo hdiutil detach /dev/disk* 2>/dev/null || true
        exit 1
    fi
    
    echo "::notice::Found Unity Hub volume at: ${unity_hub_volume}"
    
    # Find Unity Hub.app within the volume
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
    
    ./UnityHubSetup.exe /S
    
    sleep 30
    
    hub_path="C:/Program Files/Unity Hub/Unity Hub.exe"
    
else
    echo "::error::Unsupported OS: $RUNNER_OS"
    exit 1
fi

# Updated validation logic to check for the correct command names
if [[ "$RUNNER_OS" == "Linux" ]]; then
    # On Linux, check for unityhub command
    if [ ! -f "${hub_path}" ] && ! command -v unityhub &>/dev/null; then
        echo "::error::Unity Hub installation failed"
        exit 1
    fi
else
    # On macOS and Windows, check for unity-hub command
    if [ ! -f "${hub_path}" ] && ! command -v unity-hub &>/dev/null; then
        echo "::error::Unity Hub installation failed"
        exit 1
    fi
fi

echo "::notice::Unity Hub installed successfully"
echo "hub_path=${hub_path}" >> "$GITHUB_OUTPUT"

echo "::notice::Accepting Unity Hub license"
if [[ "$RUNNER_OS" == "Linux" ]]; then
    if command -v unityhub &>/dev/null; then
        unityhub -- --accept-license || true
    else
        "${hub_path}" -- --accept-license || true
    fi
else
    if command -v unity-hub &>/dev/null; then
        unity-hub -- --accept-license || true
    else
        "${hub_path}" -- --accept-license || true
    fi
fi