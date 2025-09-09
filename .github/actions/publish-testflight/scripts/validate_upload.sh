#!/bin/bash

set -euo pipefail

validate_file() {
    local file="$1"
    
    if [ ! -f "${file}" ]; then
        echo "::error::❌ IPA file not found: ${file}"
        exit 1
    fi
    
    local file_size
    file_size=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo "unknown")
    echo "::notice::📱 IPA file: ${file} (${file_size} bytes)"
    
    if [ "${file_size}" = "unknown" ] || [ "${file_size}" -eq 0 ] 2>/dev/null; then
        echo "::error::❌ IPA file appears to be empty or unreadable"
        exit 1
    fi
    
    if [ "${file_size}" -lt 1000000 ] 2>/dev/null; then
        echo "::warning::⚠️  IPA file is unusually small (${file_size} bytes)"
        echo "::warning::⚠️  This might indicate an incomplete build"
    fi
}

validate_sdk() {
    echo "::notice::🔍 Checking iOS SDK compatibility..."
    
    if command -v xcrun >/dev/null 2>&1; then
        local current_sdk
        current_sdk=$(xcrun --show-sdk-version --sdk iphoneos 2>/dev/null || echo "unknown")
        echo "::notice::🍎 Current iOS SDK: ${current_sdk}"
        
        if [ "$current_sdk" != "unknown" ]; then
            local sdk_major
            sdk_major=$(echo "${current_sdk}" | cut -d. -f1)
            
            if [ "${sdk_major}" -lt 18 ] 2>/dev/null; then
                echo "::warning::⚠️  iOS SDK ${current_sdk} may cause TestFlight upload failure"
                echo "::warning::⚠️  Apple requires iOS 18.0 SDK or later (Xcode 16+) for uploads"
                echo "::warning::⚠️  If upload fails with SDK error, rebuild with Xcode 16+"
                echo "::warning::"
                echo "::warning::Expected error: 'SDK version issue. This app was built with iOS ${current_sdk} SDK'"
                echo "::warning::Solution: Use validate_xcode_version.sh before building"
            else
                echo "::notice::✅ iOS SDK ${current_sdk} is compatible with TestFlight requirements"
            fi
        else
            echo "::warning::⚠️  Cannot detect iOS SDK version"
            echo "::warning::⚠️  Ensure Xcode command line tools are properly installed"
        fi
    else
        echo "::warning::⚠️  xcrun not available - cannot check SDK version"
        echo "::warning::⚠️  Ensure Xcode is installed and selected"
    fi
}

validate_credentials() {
    local api_key="$1"
    local api_key_id="$2"
    local api_issuer_id="$3"
    
    echo "::notice::🔐 Validating App Store Connect credentials..."
    
    if [ -z "${api_key_id}" ]; then
        echo "::error::❌ API Key ID is required but not provided"
        exit 1
    fi
    
    if [ -z "${api_issuer_id}" ]; then
        echo "::error::❌ API Issuer ID is required but not provided"
        exit 1
    fi
    
    if [ -z "${api_key}" ]; then
        echo "::error::❌ API Key is required but not provided"
        exit 1
    fi
    
    if ! echo -n "${api_key}" | base64 -d >/dev/null 2>&1; then
        echo "::error::❌ API Key appears to be invalid base64"
        exit 1
    fi
    
    echo "::notice::✅ API Key ID: ${api_key_id}"
    echo "::notice::✅ API Issuer ID: ${api_issuer_id}"
    echo "::notice::✅ Credentials validation completed"
}

validate_environment() {
    echo "::notice::🔍 Checking upload environment..."
    
    if ! command -v xcrun >/dev/null 2>&1; then
        echo "::error::❌ xcrun not found - Xcode command line tools required"
        echo "::error::Install with: xcode-select --install"
        exit 1
    fi
    
    local xcode_path
    xcode_path=$(xcode-select -p 2>/dev/null || echo "unknown")
    if [ "$xcode_path" = "unknown" ] || [ ! -d "$xcode_path" ]; then
        echo "::error::❌ No active Xcode installation found"
        echo "::error::Set with: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        exit 1
    fi
    
    local xcode_version
    if command -v xcodebuild >/dev/null 2>&1; then
        xcode_version=$(xcodebuild -version 2>/dev/null | head -n1 || echo "unknown")
        echo "::notice::🍎 Active Xcode: ${xcode_version}"
        echo "::notice::🍎 Xcode Path: ${xcode_path}"
    fi
    
    echo "::notice::✅ Environment validation completed"
}

main() {
    local file="$1"
    local api_key="$2"
    local api_key_id="$3"
    local api_issuer_id="$4"
    
    echo "::notice::🔍 Starting TestFlight upload validation..."
    echo "::notice::"
    
    validate_environment
    validate_file "${file}"
    validate_sdk
    validate_credentials "${api_key}" "${api_key_id}" "${api_issuer_id}"
    
    echo "::notice::"
    echo "::notice::✅ All validations passed - ready for TestFlight upload"
}

main "$@"