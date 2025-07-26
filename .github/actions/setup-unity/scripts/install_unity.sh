#!/bin/bash

if [ $# -ne 2 ]; then
    echo "::error::Usage: $0 <unity_version> <modules>"
    exit 1
fi

unity_version="$1"
modules="$2"

echo "::notice::Installing Unity ${unity_version}"

if [[ "$RUNNER_OS" != "Windows" && "$RUNNER_OS" != "macOS" ]]; then
    echo "::error::Unity is only supported on Windows and macOS platforms"
    echo "::error::Current platform: $RUNNER_OS"
    exit 1
fi

if [[ "$RUNNER_OS" == "Windows" ]]; then
    UNITY_HUB="C:/Program Files/Unity Hub/Unity Hub.exe"
elif [[ "$RUNNER_OS" == "macOS" ]]; then
    UNITY_HUB="/Applications/Unity Hub.app/Contents/MacOS/Unity Hub"
fi

if ! command -v unity-hub &>/dev/null && [ ! -f "${UNITY_HUB}" ]; then
    echo "::error::Unity Hub not found"
    echo "::error::Expected location: ${UNITY_HUB}"
    echo "::error::Please ensure Unity Hub is properly installed"
    exit 1
fi

echo "::notice::Installing Unity ${unity_version} via Unity Hub"
"${UNITY_HUB}" -- --headless install \
    --version "${unity_version}" \
    --changeset auto \
    || {
        echo "::error::Failed to install Unity ${unity_version}"
        exit 1
    }

if [ -n "${modules}" ]; then
    echo "::notice::Installing additional modules: ${modules}"
    
    IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
    
    for module in "${MODULE_ARRAY[@]}"; do
        module=$(echo "${module}" | xargs)
        
        case "${module}" in
            "android")
                module_id="android-open-jdk-and-android-sdk-ndk-tools"
                ;;
            "ios")
                module_id="ios"
                ;;
            "webgl")
                module_id="webgl"
                ;;
            "windows-il2cpp")
                module_id="windows-il2cpp"
                ;;
            "linux-il2cpp")
                module_id="linux-il2cpp"
                ;;
            "mac-il2cpp")
                module_id="mac-il2cpp"
                ;;
            *)
                module_id="${module}"
                ;;
        esac
        
        echo "::notice::Installing module: ${module_id}"
        "${UNITY_HUB}" -- --headless install-modules \
            --version "${unity_version}" \
            --module "${module_id}" \
            || {
                echo "::warning::Failed to install module: ${module_id}"
            }
    done
fi

echo "::notice::Waiting for Unity installation to complete..."
sleep 10

echo "::notice::Verifying Unity installation..."
"${UNITY_HUB}" -- --headless editors --installed || true

echo "::notice::Unity ${unity_version} installation completed"