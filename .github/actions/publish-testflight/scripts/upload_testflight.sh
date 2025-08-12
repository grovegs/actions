#!/bin/bash

if [ "$#" -ne 6 ]; then
    echo "::error::Usage: $0 <file> <api_key> <api_key_id> <api_issuer_id> <release_notes> <tester_groups>"
    exit 1
fi

file="$1"
api_key="$2"
api_key_id="$3"
api_issuer_id="$4"
release_notes="$5"
tester_groups="$6"

private_keys_dir="${HOME}/.appstoreconnect/private_keys"
api_key_file="${private_keys_dir}/AuthKey_${api_key_id}.p8"

cleanup() {
    echo "::notice::Cleaning up temporary files..."
    rm -f "${api_key_file}" || true
    rm -f /tmp/jwt_token.txt || true
    unset jwt_header jwt_payload jwt_header_b64 jwt_payload_b64 jwt_signature_input jwt_signature || true
    unset output_param || true
}
trap cleanup EXIT

if [ ! -f "${file}" ]; then
    echo "::error::IPA file not found: ${file}"
    exit 1
fi

if [ -z "${api_key_id}" ] || [ -z "${api_issuer_id}" ] || [ -z "${api_key}" ]; then
    echo "::error::API key credentials are required"
    exit 1
fi

echo "::notice::Setting up App Store Connect API authentication"
mkdir -p "${private_keys_dir}"
if ! echo -n "${api_key}" | base64 -d > "${api_key_file}"; then
    echo "::error::Failed to decode API private key"
    exit 1
fi

chmod 600 "${api_key_file}"

file_size=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo "unknown")
echo "::notice::Uploading IPA to TestFlight: ${file} (${file_size} bytes)"
echo "::notice::Using API Key ID: ${api_key_id}"

is_retryable_error() {
    output_param="$2"
    
    if echo "$output_param" | grep -q "500.*Internal Server Error"; then
        return 0
    fi
    if echo "$output_param" | grep -q "503.*Service Unavailable"; then
        return 0
    fi
    if echo "$output_param" | grep -q "502.*Bad Gateway"; then
        return 0
    fi
    if echo "$output_param" | grep -q "504.*Gateway Timeout"; then
        return 0
    fi
    if echo "$output_param" | grep -q "timeout"; then
        return 0
    fi
    if echo "$output_param" | grep -q "network.*error"; then
        return 0
    fi
    
    return 1
}

max_attempts=5
attempt=1
success=false

while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
    if [ $attempt -gt 1 ]; then
        wait_time=$((attempt * 30))
        echo "::notice::Attempt $attempt/$max_attempts - waiting ${wait_time}s before retry..."
        sleep $wait_time
    else
        echo "::notice::Attempt $attempt/$max_attempts - starting upload..."
    fi
    
    output=$(xcrun altool --upload-app \
        --type ios \
        --file "${file}" \
        --apiKey "${api_key_id}" \
        --apiIssuer "${api_issuer_id}" 2>&1)
    
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "::notice::✅ TestFlight upload completed successfully!"
        success=true
    else
        echo "::warning::❌ Upload attempt $attempt failed with exit code $exit_code"
        echo "::warning::Error output:"
        echo "$output"
        
        if is_retryable_error "$output"; then
            if [ $attempt -lt $max_attempts ]; then
                echo "::notice::🔄 This appears to be a temporary server error. Will retry..."
            else
                echo "::error::💀 Maximum retry attempts reached. This appears to be a persistent server issue."
                echo "::error::Suggestions:"
                echo "::error::1. Check Apple's System Status: https://developer.apple.com/system-status/"
                echo "::error::2. Try uploading manually using Xcode or Application Loader"
                echo "::error::3. Wait 10-30 minutes and re-run the workflow"
                echo "::error::4. Contact Apple Developer Support if the issue persists"
            fi
        else
            echo "::error::💀 Non-retryable error detected. This requires manual intervention."
            echo "::error::Common causes:"
            echo "::error::- Invalid API credentials"
            echo "::error::- App record not found in App Store Connect"
            echo "::error::- Bundle ID mismatch"
            echo "::error::- Invalid provisioning profile"
            echo "::error::- Missing required app metadata"
            break
        fi
    fi
    
    attempt=$((attempt + 1))
done

if [ "$success" = false ]; then
    echo "::error::TestFlight upload failed after $max_attempts attempts"
    exit 1
fi

if [ -n "$release_notes" ] || [ -n "$tester_groups" ]; then
    echo "::notice::Configuring build settings..."
    
    generate_jwt_token() {
        jwt_header='{"alg":"ES256","kid":"'${api_key_id}'","typ":"JWT"}'
        jwt_payload='{"iss":"'${api_issuer_id}'","exp":'$(($(date +%s) + 1200))',"aud":"appstoreconnect-v1"}'
        
        jwt_header_b64=$(echo -n "$jwt_header" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
        jwt_payload_b64=$(echo -n "$jwt_payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
        jwt_signature_input="${jwt_header_b64}.${jwt_payload_b64}"
        
        jwt_signature=$(echo -n "$jwt_signature_input" | openssl dgst -sha256 -sign "${api_key_file}" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
        
        echo "${jwt_signature_input}.${jwt_signature}"
    }
    
    jwt_token=$(generate_jwt_token)
    
    if [ -z "$jwt_token" ]; then
        echo "::error::Failed to generate JWT token for API calls"
        exit 1
    fi
    
    echo "::notice::Extracting app information..."
    
    temp_dir=$(mktemp -d)
    unzip -q "${file}" -d "${temp_dir}"
    info_plist_path=$(find "${temp_dir}" -name "Info.plist" | head -1)
    
    if [ -z "$info_plist_path" ]; then
        echo "::error::Could not find Info.plist in IPA file"
        rm -rf "${temp_dir}"
        exit 1
    fi
    
    bundle_id=$(plutil -p "$info_plist_path" | grep CFBundleIdentifier | sed 's/.*=> "\(.*\)"/\1/')
    bundle_version=$(plutil -p "$info_plist_path" | grep CFBundleVersion | sed 's/.*=> "\(.*\)"/\1/')
    
    rm -rf "${temp_dir}"
    
    if [ -z "$bundle_id" ] || [ -z "$bundle_version" ]; then
        echo "::error::Could not extract bundle ID or version from IPA"
        exit 1
    fi
    
    echo "::notice::Bundle ID: $bundle_id"
    echo "::notice::Bundle Version: $bundle_version"
    
    echo "::notice::Finding app in App Store Connect..."
    apps_response=$(curl -s -H "Authorization: Bearer $jwt_token" \
        "https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=${bundle_id}")
    
    app_id=$(echo "$apps_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data.get('data') and len(data['data']) > 0:
        print(data['data'][0]['id'])
    else:
        print('')
except:
    print('')
")
    
    if [ -z "$app_id" ]; then
        echo "::error::Could not find app with bundle ID: $bundle_id"
        exit 1
    fi
    
    echo "::notice::Found app ID: $app_id"
    
    echo "::notice::Waiting for build to appear in App Store Connect..."
    build_id=""
    max_wait_attempts=20
    wait_attempt=1
    
    while [ $wait_attempt -le $max_wait_attempts ] && [ -z "$build_id" ]; do
        echo "::notice::Checking for build... (attempt $wait_attempt/$max_wait_attempts)"
        
        builds_response=$(curl -s -H "Authorization: Bearer $jwt_token" \
            "https://api.appstoreconnect.apple.com/v1/builds?filter[app]=${app_id}&filter[version]=${bundle_version}&sort=-uploadedDate&limit=1")
        
        temp_build_id=$(echo "$builds_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data.get('data') and len(data['data']) > 0:
        print(data['data'][0]['id'])
    else:
        print('')
except:
    print('')
")
        
        if [ -n "$temp_build_id" ]; then
            build_id="$temp_build_id"
            echo "::notice::✅ Found build ID: $build_id"
            break
        fi
        
        if [ $wait_attempt -eq $max_wait_attempts ]; then
            echo "::warning::⚠️  Build not found in App Store Connect yet. Skipping configuration."
            echo "::notice::You can manually configure changelog and testers in App Store Connect once the build appears."
            exit 0
        fi
        
        sleep 30
        wait_attempt=$((wait_attempt + 1))
    done
    
    if [ -n "$release_notes" ]; then
        echo "::notice::Setting release notes for build..."
        
        changelog_data=$(cat << EOF
{
  "data": {
    "type": "buildLocalizations",
    "attributes": {
      "whatsNew": "$release_notes",
      "locale": "en-US"
    },
    "relationships": {
      "build": {
        "data": {
          "type": "builds",
          "id": "$build_id"
        }
      }
    }
  }
}
EOF
)
        
        changelog_response=$(curl -s -X POST \
            -H "Authorization: Bearer $jwt_token" \
            -H "Content-Type: application/json" \
            -d "$changelog_data" \
            "https://api.appstoreconnect.apple.com/v1/buildLocalizations")
        
        if echo "$changelog_response" | grep -q '"type":"buildLocalizations"'; then
            echo "::notice::✅ Release notes set successfully!"
        else
            echo "::warning::⚠️  Failed to set release notes. Response: $changelog_response"
        fi
    fi
    
    if [ -n "$tester_groups" ]; then
        echo "::notice::Adding tester groups to build..."
        
        groups_response=$(curl -s -H "Authorization: Bearer $jwt_token" \
            "https://api.appstoreconnect.apple.com/v1/apps/${app_id}/betaGroups")
        
        IFS=',' read -ra GROUP_NAMES <<< "$tester_groups"
        
        for group_name in "${GROUP_NAMES[@]}"; do
            trimmed_group_name=$(echo "$group_name" | xargs)
            
            group_id=$(echo "$groups_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for item in data.get('data', []):
        if item.get('attributes', {}).get('name', '').lower() == '${trimmed_group_name}'.lower():
            print(item['id'])
            break
    else:
        print('')
except:
    print('')
")
            
            if [ -n "$group_id" ]; then
                add_group_data=$(cat << EOF
{
  "data": [
    {
      "type": "betaGroups",
      "id": "$group_id"
    }
  ]
}
EOF
)
                
                curl -s -X POST \
                    -H "Authorization: Bearer $jwt_token" \
                    -H "Content-Type: application/json" \
                    -d "$add_group_data" \
                    "https://api.appstoreconnect.apple.com/v1/builds/${build_id}/relationships/betaGroups" > /dev/null
                
                if [ $? -eq 0 ]; then
                    echo "::notice::✅ Added tester group: $trimmed_group_name"
                else
                    echo "::warning::⚠️  Failed to add tester group: $trimmed_group_name"
                fi
            else
                echo "::warning::⚠️  Tester group not found: $trimmed_group_name"
            fi
        done
    fi
    
    echo "::notice::🎉 Build configuration completed!"
fi

echo "::notice::The build will appear in TestFlight for testers after Apple's processing (usually 5-15 minutes)"