#!/bin/bash

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "::error::Usage: $0 <min_ios_sdk_version> <min_xcode_version>"
    exit 1
fi

min_ios_sdk_version="$1"
min_xcode_version="$2"

compare_versions() {
    local version1="$1"
    local version2="$2"
    
    local v1_major
    local v1_minor
    local v1_patch
    local v2_major
    local v2_minor
    local v2_patch
    
    v1_major=$(echo "$version1" | cut -d. -f1)
    v1_minor=$(echo "$version1" | cut -d. -f2 2>/dev/null || echo "0")
    v1_patch=$(echo "$version1" | cut -d. -f3 2>/dev/null || echo "0")
    
    v2_major=$(echo "$version2" | cut -d. -f1)
    v2_minor=$(echo "$version2" | cut -d. -f2 2>/dev/null || echo "0")
    v2_patch=$(echo "$version2" | cut -d. -f3 2>/dev/null || echo "0")
    
    v1_major=${v1_major#0}
    v1_minor=${v1_minor#0}
    v1_patch=${v1_patch#0}
    v2_major=${v2_major#0}
    v2_minor=${v2_minor#0}
    v2_patch=${v2_patch#0}
    
    v1_major=${v1_major:-0}
    v1_minor=${v1_minor:-0}
    v1_patch=${v1_patch:-0}
    v2_major=${v2_major:-0}
    v2_minor=${v2_minor:-0}
    v2_patch=${v2_patch:-0}
    
    local v1_numeric=$((v1_major * 10000 + v1_minor * 100 + v1_patch))
    local v2_numeric=$((v2_major * 10000 + v2_minor * 100 + v2_patch))
    
    if [ "$v1_numeric" -gt "$v2_numeric" ]; then
        echo "1"
    elif [ "$v1_numeric" -lt "$v2_numeric" ]; then
        echo "-1"
    else
        echo "0"
    fi
}

get_current_xcode_info() {
    local xcode_path
    local xcode_version
    local ios_sdk_version
    
    xcode_path=$(xcode-select -p 2>/dev/null || echo "unknown")
    
    if command -v xcodebuild >/dev/null 2>&1; then
        xcode_version=$(xcodebuild -version 2>/dev/null | head -n1)
        xcode_version=${xcode_version#Xcode }
        xcode_version=${xcode_version:-unknown}
    else
        xcode_version="unknown"
    fi
    
    ios_sdk_version="0.0"
    
    if command -v xcrun >/dev/null 2>&1; then
        ios_sdk_version=$(xcrun --show-sdk-version --sdk iphoneos 2>/dev/null || echo "0.0")
    fi
    
    if [ "$ios_sdk_version" = "0.0" ] && command -v xcodebuild >/dev/null 2>&1; then
        local sdk_output
        sdk_output=$(xcodebuild -showsdks 2>/dev/null | grep -i "iOS" | tail -n1)
        if [ -n "$sdk_output" ]; then
            ios_sdk_version=$(echo "$sdk_output" | grep -oE "iOS [0-9]+\.[0-9]+")
            ios_sdk_version=${ios_sdk_version#iOS }
            ios_sdk_version=${ios_sdk_version:-0.0}
        fi
    fi
    
    if [ "$ios_sdk_version" = "0.0" ] && command -v xcodebuild >/dev/null 2>&1; then
        local iphoneos_sdk
        iphoneos_sdk=$(xcodebuild -showsdks 2>/dev/null | grep -oE "iphoneos[0-9]+\.[0-9]+" | tail -n1)
        if [ -n "$iphoneos_sdk" ]; then
            ios_sdk_version=${iphoneos_sdk#iphoneos}
            ios_sdk_version=${ios_sdk_version:-0.0}
        fi
    fi
    
    if [ "$ios_sdk_version" = "0.0" ] && [ "$xcode_path" != "unknown" ]; then
        local sdk_path="${xcode_path}/Platforms/iPhoneOS.platform/Developer/SDKs"
        if [ -d "$sdk_path" ]; then
            local latest_sdk=""
            for sdk_file in "$sdk_path"/iPhoneOS*.sdk; do
                if [ -d "$sdk_file" ]; then
                    local sdk_name
                    sdk_name=$(basename "$sdk_file")
                    if [[ "$sdk_name" =~ iPhoneOS([0-9]+\.[0-9]+)\.sdk ]]; then
                        local version="${BASH_REMATCH[1]}"
                        if [ -z "$latest_sdk" ] || [ "$(compare_versions "$version" "$latest_sdk")" = "1" ]; then
                            latest_sdk="$version"
                        fi
                    fi
                fi
            done
            if [ -n "$latest_sdk" ]; then
                ios_sdk_version="$latest_sdk"
            fi
        fi
    fi
    
    echo "${xcode_path}|${xcode_version}|${ios_sdk_version}"
}

find_xcode_installations() {
    echo "::notice::🔍 Scanning for Xcode installations..."
    
    local installations=()
    
    for xcode_path in /Applications/Xcode*.app; do
        if [ -d "${xcode_path}" ] && [ -d "${xcode_path}/Contents/Developer" ]; then
            local xcode_name
            local developer_path
            local xcode_version="unknown"
            local ios_sdk_version="0.0"
            
            xcode_name=$(basename "${xcode_path}")
            developer_path="${xcode_path}/Contents/Developer"
            
            if [ -x "${developer_path}/usr/bin/xcodebuild" ]; then
                xcode_version=$("${developer_path}/usr/bin/xcodebuild" -version 2>/dev/null | head -n1)
                xcode_version=${xcode_version#Xcode }
                xcode_version=${xcode_version:-unknown}
            fi
            
            if [ -x "${developer_path}/usr/bin/xcrun" ]; then
                ios_sdk_version=$("${developer_path}/usr/bin/xcrun" --show-sdk-version --sdk iphoneos 2>/dev/null || echo "0.0")
            fi
            
            if [ "$ios_sdk_version" = "0.0" ] && [ -x "${developer_path}/usr/bin/xcodebuild" ]; then
                local sdk_output
                sdk_output=$("${developer_path}/usr/bin/xcodebuild" -showsdks 2>/dev/null | grep -i "iOS" | tail -n1)
                if [ -n "$sdk_output" ]; then
                    ios_sdk_version=$(echo "$sdk_output" | grep -oE "iOS [0-9]+\.[0-9]+")
                    ios_sdk_version=${ios_sdk_version#iOS }
                    ios_sdk_version=${ios_sdk_version:-0.0}
                fi
            fi
            
            if [ "$ios_sdk_version" = "0.0" ] && [ -x "${developer_path}/usr/bin/xcodebuild" ]; then
                local iphoneos_sdk
                iphoneos_sdk=$("${developer_path}/usr/bin/xcodebuild" -showsdks 2>/dev/null | grep -oE "iphoneos[0-9]+\.[0-9]+" | tail -n1)
                if [ -n "$iphoneos_sdk" ]; then
                    ios_sdk_version=${iphoneos_sdk#iphoneos}
                    ios_sdk_version=${ios_sdk_version:-0.0}
                fi
            fi
            
            if [ "$ios_sdk_version" = "0.0" ]; then
                local sdk_path="${developer_path}/Platforms/iPhoneOS.platform/Developer/SDKs"
                if [ -d "$sdk_path" ]; then
                    local latest_sdk=""
                    for sdk_file in "$sdk_path"/iPhoneOS*.sdk; do
                        if [ -d "$sdk_file" ]; then
                            local sdk_name
                            sdk_name=$(basename "$sdk_file")
                            if [[ "$sdk_name" =~ iPhoneOS([0-9]+\.[0-9]+)\.sdk ]]; then
                                local version="${BASH_REMATCH[1]}"
                                if [ -z "$latest_sdk" ] || [ "$(compare_versions "$version" "$latest_sdk")" = "1" ]; then
                                    latest_sdk="$version"
                                fi
                            fi
                        fi
                    done
                    if [ -n "$latest_sdk" ]; then
                        ios_sdk_version="$latest_sdk"
                    fi
                fi
            fi
            
            installations+=("${xcode_path}|${xcode_name}|${xcode_version}|${ios_sdk_version}")
            echo "::notice::  📱 ${xcode_name}: Xcode ${xcode_version}, iOS SDK ${ios_sdk_version}"
        fi
    done
    
    if [ "${#installations[@]}" -eq 0 ]; then
        echo "::error::❌ No Xcode installations found in /Applications/"
        return 1
    fi
    
    printf '%s\n' "${installations[@]}"
    return 0
}

select_best_xcode() {
    local min_sdk_version="$1"
    local installations
    
    if ! installations=$(find_xcode_installations); then
        echo "::error::❌ No Xcode installations found"
        return 1
    fi
    
    local best_xcode=""
    local best_sdk_version="0.0"
    local best_xcode_name=""
    local best_xcode_version=""
    
    echo "::notice::🎯 Looking for Xcode with iOS SDK ${min_sdk_version}+"
    
    while IFS='|' read -r xcode_path xcode_name xcode_version ios_sdk_version; do
        if [ -n "${xcode_path}" ] && [ -n "${ios_sdk_version}" ]; then
            local comparison
            comparison=$(compare_versions "${ios_sdk_version}" "${min_sdk_version}")
            
            if [ "$comparison" -ge 0 ]; then
                echo "::notice::  ✅ ${xcode_name} (SDK ${ios_sdk_version}) meets requirements"
                
                local sdk_comparison
                sdk_comparison=$(compare_versions "${ios_sdk_version}" "${best_sdk_version}")
                if [ "$sdk_comparison" -gt 0 ]; then
                    best_xcode="${xcode_path}"
                    best_sdk_version="${ios_sdk_version}"
                    best_xcode_name="${xcode_name}"
                    best_xcode_version="${xcode_version}"
                fi
            else
                echo "::notice::  ❌ ${xcode_name} (SDK ${ios_sdk_version}) is too old"
            fi
        fi
    done <<< "$installations"
    
    if [ -z "$best_xcode" ]; then
        echo "::error::💀 No compatible Xcode installation found!"
        echo "::error::Required: iOS SDK ${min_sdk_version}+ (Xcode ${min_xcode_version}+)"
        echo "::error::"
        echo "::error::Solutions:"
        echo "::error::  • Use 'macos-latest' runner image"
        echo "::error::  • Install Xcode ${min_xcode_version}+ manually"
        echo "::error::  • Check Apple Developer downloads"
        return 1
    fi
    
    echo "${best_xcode}|${best_xcode_name}|${best_xcode_version}|${best_sdk_version}"
    return 0
}

switch_xcode() {
    local target_xcode="$1"
    local target_name="$2"
    local target_version="$3"
    local target_sdk="$4"
    
    echo "::notice::🔄 Switching to ${target_name}..."
    echo "::notice::  Xcode: ${target_version}"
    echo "::notice::  iOS SDK: ${target_sdk}"
    echo "::notice::  Path: ${target_xcode}"
    
    if ! sudo xcode-select -s "${target_xcode}/Contents/Developer"; then
        echo "::error::❌ Failed to switch to ${target_name}"
        return 1
    fi
    
    local new_info
    local new_version
    local new_sdk
    
    new_info=$(get_current_xcode_info)
    IFS='|' read -r _ new_version new_sdk <<< "$new_info"
    
    if [ "$new_sdk" = "0.0" ] || [ "$new_sdk" = "unknown" ]; then
        echo "::error::❌ Failed to verify Xcode switch - SDK detection failed"
        return 1
    fi
    
    local sdk_comparison
    sdk_comparison=$(compare_versions "${new_sdk}" "${min_ios_sdk_version}")
    if [ "$sdk_comparison" -lt 0 ]; then
        echo "::error::❌ After switching, iOS SDK is still incompatible: ${new_sdk}"
        return 1
    fi
    
    echo "::notice::✅ Successfully switched to Xcode ${new_version}"
    echo "::notice::✅ Now using iOS SDK ${new_sdk}"
    return 0
}

main() {
    echo "::notice::🔍 Validating Xcode and iOS SDK compatibility..."
    echo "::notice::Required: iOS SDK ${min_ios_sdk_version}+ (Xcode ${min_xcode_version}+)"
    echo "::notice::"
    
    local current_info
    local current_path
    local current_version
    local current_sdk
    
    current_info=$(get_current_xcode_info)
    IFS='|' read -r current_path current_version current_sdk <<< "$current_info"
    
    echo "::notice::📱 Current build environment:"
    echo "::notice::  Xcode Path: ${current_path}"
    echo "::notice::  Xcode Version: ${current_version}"
    echo "::notice::  iOS SDK: ${current_sdk}"
    echo "::notice::"
    
    if [ "$current_sdk" != "unknown" ] && [ "$current_sdk" != "0.0" ]; then
        local comparison
        comparison=$(compare_versions "${current_sdk}" "${min_ios_sdk_version}")
        
        if [ "$comparison" -ge 0 ]; then
            echo "::notice::✅ Current iOS SDK ${current_sdk} meets requirements!"
            echo "::notice::✅ No Xcode version change needed"
            return 0
        else
            echo "::warning::⚠️  Current iOS SDK ${current_sdk} is incompatible"
            echo "::warning::⚠️  Need iOS SDK ${min_ios_sdk_version}+ for compatibility"
        fi
    else
        echo "::warning::⚠️  Could not detect current iOS SDK version"
    fi
    
    echo "::notice::🔄 Searching for compatible Xcode installation..."
    
    local best_xcode_info
    if ! best_xcode_info=$(select_best_xcode "${min_ios_sdk_version}"); then
        exit 1
    fi
    
    local best_path
    local best_name
    local best_version
    local best_sdk
    IFS='|' read -r best_path best_name best_version best_sdk <<< "$best_xcode_info"
    
    if ! switch_xcode "$best_path" "$best_name" "$best_version" "$best_sdk"; then
        exit 1
    fi
    
    echo "::notice::"
    echo "::notice::🎉 Xcode selection completed successfully!"
}

main "$@"