#!/bin/bash
set -e
if [ "$#" -ne 4 ]; then
    echo "::error::Usage: $0 <version> <changeset> <modules> <download_dir>"
    exit 1
fi
version="$1"
changeset="$2"
modules="$3"
download_dir="$4"
mkdir -p "${download_dir}"
download_file() {
    local url="$1"; local file_path="$2"; echo "::notice::Downloading from ${url} to ${file_path}"
    if ! curl -L -o "${file_path}" "${url}"; then echo "::error::Failed to download from ${url}"; exit 1; fi
}
base_url="https://download.unity3d.com/download_unity/${changeset}"
if [[ "$RUNNER_OS" == "macOS" ]]; then
    echo "::notice::Forcing Apple Silicon (arm64) download for macOS."
    mac_editor_segment="MacEditorInstallerArm64"
    mac_module_segment="MacEditorTargetInstallerArm64"
    editor_url="${base_url}/${mac_editor_segment}/Unity-${version}.pkg"
elif [[ "$RUNNER_OS" == "Linux" ]]; then
    editor_url="${base_url}/LinuxEditorInstaller/Unity.tar.xz"
fi
download_file "${editor_url}" "${download_dir}/$(basename "${editor_url}")"
if [ -n "${modules}" ]; then
    IFS=',' read -ra MODULE_ARRAY <<< "${modules}"
    for module in "${MODULE_ARRAY[@]}"; do
        module_trimmed=$(echo "${module}" | xargs); module_url=""
        case "${module_trimmed}" in
            "android")
                if [[ "$RUNNER_OS" == "macOS" ]]; then module_url="${base_url}/${mac_module_segment}/UnitySetup-Android-Support-for-Editor-${version}.pkg";
                elif [[ "$RUNNER_OS" == "Linux" ]]; then module_url="${base_url}/TargetSupportInstaller/Unity-Linux-Android-Support-for-Editor-${version}.tar.xz"; fi;;
            "ios")
                if [[ "$RUNNER_OS" == "macOS" ]]; then module_url="${base_url}/${mac_module_segment}/UnitySetup-iOS-Support-for-Editor-${version}.pkg"; fi;;
            "webgl")
                if [[ "$RUNNER_OS" == "macOS" ]]; then module_url="${base_url}/${mac_module_segment}/UnitySetup-WebGL-Support-for-Editor-${version}.pkg";
                elif [[ "$RUNNER_OS" == "Linux" ]]; then module_url="${base_url}/TargetSupportInstaller/Unity-Linux-WebGL-Support-for-Editor-${version}.tar.xz"; fi;;
            *) echo "::warning::Skipping unknown module: ${module_trimmed}";;
        esac
        if [ -n "${module_url}" ]; then download_file "${module_url}" "${download_dir}/$(basename "${module_url}")"; fi
    done
fi