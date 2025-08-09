#!/bin/bash

if [ $# -ne 14 ]; then
    echo "::error::Invalid number of arguments. Expected 14, got $#"
    exit 1
fi

project_dir="$1"
version="$2"
configuration="$3"
filename="$4"
unity_email="$5"
unity_password="$6"
unity_license_key="$7"
define_symbols="$8"
team_id="$9"
certificate="${10}"
certificate_password="${11}"
provisioning_profile="${12}"
bundle_identifier="${13}"
build_method="${14}"

builds_dir="${HOME}/.builds/ios"
xcode_project_dir="${builds_dir}/${filename}"
archive_path="${builds_dir}/${filename}.xcarchive"
export_path="${builds_dir}/${filename}.ipa"

# Create build directory
echo "::notice::Creating build directory..."
mkdir -p "${builds_dir}" || {
    echo "::error::Failed to create directory: ${builds_dir}"
    exit 1
}

# Build Unity project to Xcode
echo "::notice::Building Unity project for iOS..."

build_args=(
    -batchmode
    -nographics
    -quit
    -username "${unity_email}"
    -password "${unity_password}"
    -serial "${unity_license_key}"
    -projectPath "${project_dir}"
    -buildTarget iOS
    -logFile -
)

# Add custom build method or use default
if [ -n "${build_method}" ]; then
    build_args+=(-executeMethod "${build_method}")
else
    # Create build script
    build_script="${project_dir}/Assets/Editor/Build.cs"
    mkdir -p "${project_dir}/Assets/Editor"
    
    cat > "${build_script}" << 'EOF'
using UnityEditor;
using UnityEditor.iOS.Xcode;
using UnityEngine;
using System.Linq;
using System.IO;

public static class Build
{
    public static void BuildiOS()
    {
        var args = System.Environment.GetCommandLineArgs();
        string outputPath = GetArg(args, "-outputPath");
        string defineSymbols = GetArg(args, "-defineSymbols");
        string buildConfig = GetArg(args, "-buildConfig");
        string versionName = GetArg(args, "-versionName");
        string bundleId = GetArg(args, "-bundleId");
        string teamId = GetArg(args, "-teamId");

        // Set version
        if (!string.IsNullOrEmpty(versionName))
        {
            PlayerSettings.bundleVersion = versionName;
            PlayerSettings.iOS.buildNumber = versionName;
        }

        // Set bundle identifier
        if (!string.IsNullOrEmpty(bundleId))
        {
            PlayerSettings.applicationIdentifier = bundleId;
        }

        // Set team ID
        if (!string.IsNullOrEmpty(teamId))
        {
            PlayerSettings.iOS.appleDeveloperTeamID = teamId;
        }

        // Set define symbols
        if (!string.IsNullOrEmpty(defineSymbols))
        {
            PlayerSettings.SetScriptingDefineSymbolsForGroup(
                BuildTargetGroup.iOS, defineSymbols);
        }

        // Set build options
        BuildOptions buildOptions = BuildOptions.None;
        if (buildConfig == "Debug")
        {
            buildOptions |= BuildOptions.Development | BuildOptions.AllowDebugging;
        }

        // Get scenes
        string[] scenes = EditorBuildSettings.scenes
            .Where(scene => scene.enabled)
            .Select(scene => scene.path)
            .ToArray();

        // Build
        BuildPipeline.BuildPlayer(scenes, outputPath, BuildTarget.iOS, buildOptions);
    }

    static string GetArg(string[] args, string name)
    {
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == name)
                return args[i + 1];
        }
        return null;
    }
}
EOF

    build_args+=(-executeMethod Build.BuildiOS)
fi

# Add parameters
build_args+=(-outputPath "${xcode_project_dir}")
build_args+=(-defineSymbols "${define_symbols}")
build_args+=(-versionName "${version}")
build_args+=(-buildConfig "${configuration}")
build_args+=(-bundleId "${bundle_identifier}")
build_args+=(-teamId "${team_id}")

# Execute Unity build
if ! unity "${build_args[@]}"; then
    echo "::error::Unity build failed for iOS"
    exit 1
fi

# Setup certificates and profiles if provided
if [ -n "${certificate}" ] && [ -n "${provisioning_profile}" ]; then
    echo "::notice::Setting up iOS signing..."
    
    # Import certificate
    keychain_file="${RUNNER_TEMP}/ios.keychain-db"
    certificate_file="${RUNNER_TEMP}/ios.p12"
    provisioning_file="${RUNNER_TEMP}/profile.mobileprovision"
    keychain_password=$(openssl rand -base64 32)
    
    echo -n "${certificate}" | base64 -d > "${certificate_file}"
    echo -n "${provisioning_profile}" | base64 -d > "${provisioning_file}"
    
    security create-keychain -p "${keychain_password}" "${keychain_file}"
    security set-keychain-settings -lut 3600 "${keychain_file}"
    security unlock-keychain -p "${keychain_password}" "${keychain_file}"
    security list-keychains -d user -s "${keychain_file}"
    security import "${certificate_file}" -k "${keychain_file}" -P "${certificate_password}" -T /usr/bin/codesign
    
    mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
    cp "${provisioning_file}" "$HOME/Library/MobileDevice/Provisioning Profiles/"
    
    # Build with Xcode
    echo "::notice::Building Xcode project..."
    
    xcodebuild -project "${xcode_project_dir}/Unity-iPhone.xcodeproj" \
        -scheme "Unity-iPhone" \
        -configuration "${configuration}" \
        -archivePath "${archive_path}" \
        archive
    
    # Export IPA
    echo "::notice::Exporting IPA..."
    
    cat > "${builds_dir}/export.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${team_id}</string>
</dict>
</plist>
EOF
    
    xcodebuild -exportArchive \
        -archivePath "${archive_path}" \
        -exportPath "${builds_dir}" \
        -exportOptionsPlist "${builds_dir}/export.plist"
    
    # Cleanup
    security delete-keychain "${keychain_file}" || true
    rm -f "${certificate_file}" "${provisioning_file}"
fi

echo "::notice::Build completed successfully"
echo "file=${export_path}" >> "${GITHUB_OUTPUT}"