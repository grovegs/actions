#!/bin/bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
    echo "::error::Usage: $0"
    exit 1
fi

echo "::group::🍎 Setting up Xcode for Unity iOS builds"

setup_xcode_for_unity() {
    local xcode_path=""
    
    echo "::notice::Available Xcode installations:"
    for xcode_app in /Applications/Xcode*.app; do
        if [ -d "$xcode_app/Contents/Developer" ]; then
            local version_info
            version_info=$("$xcode_app/Contents/Developer/usr/bin/xcodebuild" -version 2>/dev/null | head -1 || echo "Unknown")
            echo "::notice::  - $(basename "$xcode_app"): $version_info"
        fi
    done
    
    echo "::notice::Selecting Xcode for optimal iOS storyboard generation..."
    
    if [ -d "/Applications/Xcode_15.4.app" ]; then
        xcode_path="/Applications/Xcode_15.4.app/Contents/Developer"
        echo "::notice::Using Xcode 15.4"
    elif [ -d "/Applications/Xcode_15.0.app" ]; then
        xcode_path="/Applications/Xcode_15.0.app/Contents/Developer"
        echo "::notice::Using Xcode 15.0"
    elif [ -d "/Applications/Xcode_14.3.app" ]; then
        xcode_path="/Applications/Xcode_14.3.app/Contents/Developer"
        echo "::notice::Using Xcode 14.3"
    elif [ -d "/Applications/Xcode_16.0.app" ]; then
        xcode_path="/Applications/Xcode_16.0.app/Contents/Developer"
        echo "::warning::Using Xcode 16.0 (may generate iOS 18.0 storyboards)"
    else
        echo "::error::No compatible Xcode found"
        exit 1
    fi
    
    if [ -n "$xcode_path" ] && [ -d "$xcode_path" ]; then
        echo "::notice::Setting Xcode to: $xcode_path"
        sudo xcode-select -s "$xcode_path"
    else
        echo "::error::Failed to set Xcode path"
        exit 1
    fi
    
    echo "::notice::Current Xcode: $(xcode-select -p)"
    xcodebuild -version | head -2
    
    echo "::notice::Available iOS SDKs:"
    xcodebuild -showsdks | grep iOS || echo "No iOS SDKs found"
    
    local default_ios_sdk
    default_ios_sdk=$(xcodebuild -showsdks | grep iOS | tail -1)
    if echo "$default_ios_sdk" | grep -q "18\."; then
        echo "::warning::Default iOS SDK is 18.0 - may cause storyboard generation issues"
    else
        echo "::notice::Default iOS SDK: $(echo "$default_ios_sdk" | awk '{print $NF}')"
    fi
    
    sudo xcodebuild -license accept || echo "::warning::Could not accept Xcode license"
}

validate_ios_setup() {
    echo "::notice::Validating iOS build environment..."
    
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "::error::Xcode command line tools not properly configured"
        exit 1
    fi
    
    if ! xcodebuild -version >/dev/null 2>&1; then
        echo "::error::xcodebuild is not working properly"
        exit 1
    fi
    
    local ios_sdk_count
    ios_sdk_count=$(xcodebuild -showsdks | grep -c "iOS" || echo "0")
    
    if [ "$ios_sdk_count" -eq 0 ]; then
        echo "::error::No iOS SDKs found"
        exit 1
    fi
    
    echo "::notice::iOS build environment validation passed"
    echo "::notice::Found $ios_sdk_count iOS SDK(s)"
}

display_ios_setup_summary() {
    echo "::notice::iOS Build Environment Setup Complete!"
    echo "::notice::Xcode Path: $(xcode-select -p)"
    echo "::notice::Xcode Version: $(xcodebuild -version | head -1)"
    echo "::notice::iOS SDKs: $(xcodebuild -showsdks | grep iOS | wc -l | tr -d ' ') available"
}

main() {
    echo "::notice::Starting iOS environment setup"
    echo "::notice::Platform: $RUNNER_OS"
    
    if [[ "$RUNNER_OS" != "macOS" ]]; then
        echo "::error::iOS builds require macOS runner"
        exit 1
    fi
    
    setup_xcode_for_unity
    validate_ios_setup
    display_ios_setup_summary
    
    echo "::notice::iOS environment setup completed successfully"
}

main "$@"

echo "::endgroup::"