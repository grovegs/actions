#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <ios_sdk_version>"
    exit 1
fi

ios_version="$1"

if [ -z "$ios_version" ] || [ "$ios_version" = "unknown" ]; then
    echo "::error::Invalid iOS SDK version: $ios_version"
    echo "::error::Make sure select_xcode.sh runs successfully before this script"
    exit 1
fi

accept_xcode_license() {
    echo "::notice::🔐 Accepting Xcode license..."
    
    if sudo xcodebuild -license accept 2>/dev/null; then
        echo "::notice::✅ Xcode license accepted"
        return 0
    else
        echo "::warning::⚠️  Could not accept Xcode license automatically"
        return 1
    fi
}

check_ios_platforms() {
    local target_version="$1"
    
    echo "::notice::🔍 Checking for iOS platforms version $target_version..."
    
    local all_sdks
    all_sdks="$(xcodebuild -showsdks 2>/dev/null)"
    
    if [ -z "$all_sdks" ]; then
        echo "::warning::⚠️  No SDKs found"
        return 1
    fi
    
    echo "::notice::📱 Available SDKs:"
    echo "$all_sdks" | grep -E "(iphoneos|iphonesimulator)" | while read -r line; do
        echo "::notice::  $line"
    done
    
    local has_device_sdk=false
    local has_simulator_sdk=false
    
    if echo "$all_sdks" | grep -q "iphoneos$target_version"; then
        echo "::notice::✅ Found iOS device SDK $target_version"
        has_device_sdk=true
    else
        echo "::warning::⚠️  iOS device SDK $target_version is missing"
    fi
    
    if echo "$all_sdks" | grep -q "iphonesimulator$target_version"; then
        echo "::notice::✅ Found iOS simulator SDK $target_version"
        has_simulator_sdk=true
    else
        echo "::warning::⚠️  iOS simulator SDK $target_version is missing"
    fi
    
    if [ "$has_device_sdk" = true ] && [ "$has_simulator_sdk" = true ]; then
        echo "::notice::✅ Both iOS device and simulator platforms $target_version are available"
        return 0
    else
        return 1
    fi
}

install_ios_platforms() {
    local target_version="$1"
    
    echo "::notice::📥 Installing iOS platforms version $target_version..."
    echo "::notice::This may take several minutes..."
    
    if xcodebuild -downloadPlatform iOS; then
        echo "::notice::✅ Successfully downloaded iOS platform"
    else
        echo "::error::❌ Failed to download iOS platform"
        return 1
    fi
    
    echo "::notice::📥 Installing iOS Simulator platform..."
    if xcodebuild -downloadPlatform "iOS Simulator" 2>/dev/null; then
        echo "::notice::✅ Successfully downloaded iOS Simulator platform"
    else
        echo "::notice::⚠️  iOS Simulator platform download failed or not needed"
    fi
    
    if check_ios_platforms "$target_version"; then
        echo "::notice::✅ All required iOS platforms $target_version are now available"
        return 0
    else
        echo "::warning::⚠️  iOS platforms $target_version still missing after download"
        
        echo "::notice::🔧 Trying alternative installation methods..."
        
        if xcodebuild -runFirstLaunch 2>/dev/null; then
            echo "::notice::✅ Xcode first launch setup completed"
        else
            echo "::notice::⚠️  Xcode first launch setup failed or not needed"
        fi
        
        if check_ios_platforms "$target_version"; then
            echo "::notice::✅ iOS platforms $target_version are now available after refresh"
            return 0
        else
            echo "::error::❌ iOS platforms $target_version still not available"
            return 1
        fi
    fi
}

main() {
    echo "::notice::🔧 Setting up iOS platform environment..."
    echo "::notice::📱 Target iOS SDK version: $ios_version"
    echo "::notice::"
    
    accept_xcode_license
    
    if check_ios_platforms "$ios_version"; then
        echo "::notice::✅ All required iOS platforms already available"
        return 0
    fi
    
    echo "::notice::🔧 Installing missing iOS platforms for version $ios_version..."
    
    if install_ios_platforms "$ios_version"; then
        return 0
    else
        echo "::error::Failed to install required iOS platforms"
        echo "::error::Solutions:"
        echo "::error::  • Use 'macos-latest' runner (may have more platforms)"
        echo "::error::  • Use older iOS target version"
        echo "::error::  • Install platform manually in workflow"
        echo "::error::  • Check if Xcode Command Line Tools are properly installed"
        return 1
    fi
}

main "$@"