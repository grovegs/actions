#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "::error::Usage: $0 <ios_version>"
    exit 1
fi

ios_version="$1"

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

check_ios_platform() {
    local ios_version="$1"
    
    echo "::notice::🔍 Checking iOS ${ios_version} platform availability..."
    
    if xcodebuild -showsdks | grep -q "iphoneos${ios_version}"; then
        echo "::notice::✅ iOS ${ios_version} platform is available"
        return 0
    else
        echo "::warning::⚠️  iOS ${ios_version} platform is missing"
        return 1
    fi
}

install_ios_platform() {
    local ios_version="$1"
    
    echo "::notice::📥 Installing iOS ${ios_version} platform..."
    echo "::notice::This may take several minutes..."
    
    if xcodebuild -downloadPlatform iOS; then
        echo "::notice::✅ Successfully downloaded iOS platform"
        
        if check_ios_platform "$ios_version"; then
            echo "::notice::✅ iOS ${ios_version} platform is now available"
            return 0
        else
            echo "::warning::⚠️  iOS ${ios_version} platform still not available after download"
            return 1
        fi
    else
        echo "::error::❌ Failed to download iOS platform"
        return 1
    fi
}

main() {
    echo "::notice::🔧 Setting up iOS platform environment..."
    
    accept_xcode_license
    
    if check_ios_platform "$ios_version"; then
        return 0
    fi
    
    echo "::notice::🔧 Attempting to install missing iOS ${ios_version} platform..."
    
    if install_ios_platform "$ios_version"; then
        return 0
    else
        echo "::error::Failed to install iOS ${ios_version} platform"
        echo "::error::Solutions:"
        echo "::error::  • Use 'macos-latest' runner (may have more platforms)"
        echo "::error::  • Use older iOS target version"
        echo "::error::  • Install platform manually in workflow"
        return 1
    fi
}

main "$@"