#!/bin/bash

if [ $# -ne 13 ]; then
    echo "::error::Invalid number of arguments. Expected 13, got $#"
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
keystore="$9"
keystore_user="${10}"
keystore_password="${11}"
format="${12}"
build_method="${13}"

builds_dir="${HOME}/.builds/android"
keystore_file="${RUNNER_TEMP}/android.keystore"
output_file="${builds_dir}/${filename}.${format}"

# Cleanup function
cleanup() {
    echo "::notice::Cleaning up sensitive files..."
    rm -f "${keystore_file}" || true
}
trap cleanup EXIT

# Create build directory
echo "::notice::Creating build directory..."
mkdir -p "${builds_dir}" || {
    echo "::error::Failed to create directory: ${builds_dir}"
    exit 1
}

# Decode and save keystore if provided
if [ -n "${keystore}" ]; then
    echo "::notice::Decoding Android keystore..."
    echo -n "${keystore}" | base64 -d > "${keystore_file}" || {
        echo "::error::Failed to decode Android keystore"
        exit 1
    }
fi

# Prepare Unity build command
echo "::notice::Building Unity project for Android (${format})..."

build_args=(
    -batchmode
    -nographics
    -quit
    -username "${unity_email}"
    -password "${unity_password}"
    -serial "${unity_license_key}"
    -projectPath "${project_dir}"
    -logFile -
)

# Add build target
if [ "${format}" == "aab" ]; then
    build_args+=(-buildTarget Android)
    build_args+=(-executeMethod UnityEditor.EditorUserBuildSettings.androidBuildType=AndroidBuildType.AppBundle)
else
    build_args+=(-buildTarget Android)
fi

# Add custom build method or use default
if [ -n "${build_method}" ]; then
    build_args+=(-executeMethod "${build_method}")
else
    # Create build script on the fly
    build_script="${project_dir}/Assets/Editor/Build.cs"
    mkdir -p "${project_dir}/Assets/Editor"
    
    cat > "${build_script}" << 'EOF'
using UnityEditor;
using UnityEngine;
using System.Linq;
using System;

public static class Build
{
    public static void BuildAndroid()
    {
        var args = System.Environment.GetCommandLineArgs();
        string outputPath = GetArg(args, "-outputPath");
        string defineSymbols = GetArg(args, "-defineSymbols");
        string keystorePath = GetArg(args, "-keystorePath");
        string keystorePass = GetArg(args, "-keystorePass");
        string keyaliasName = GetArg(args, "-keyaliasName");
        string keyaliasPass = GetArg(args, "-keyaliasPass");
        string buildConfig = GetArg(args, "-buildConfig");
        string versionName = GetArg(args, "-versionName");
        string buildFormat = GetArg(args, "-buildFormat");

        // Set version
        if (!string.IsNullOrEmpty(versionName))
        {
            PlayerSettings.bundleVersion = versionName;
            var versionParts = versionName.Split('.');

            if (versionParts.Length >= 3)
            {
                int major = int.Parse(versionParts[0]);
                int minor = int.Parse(versionParts[1]);
                int patch = int.Parse(versionParts[2]);
                
                int versionCode = major * 10000000 + 
                                  minor * 10000 + 
                                  patch;
                PlayerSettings.Android.bundleVersionCode = versionCode;
            }
        }

        // Set define symbols
        if (!string.IsNullOrEmpty(defineSymbols))
        {
            PlayerSettings.SetScriptingDefineSymbolsForGroup(
                BuildTargetGroup.Android, defineSymbols);
        }

        // Set keystore
        if (!string.IsNullOrEmpty(keystorePath))
        {
            PlayerSettings.Android.keystoreName = keystorePath;
            PlayerSettings.Android.keystorePass = keystorePass;
            PlayerSettings.Android.keyaliasName = keyaliasName;
            PlayerSettings.Android.keyaliasPass = keyaliasPass;
        }

        // Set build options
        BuildOptions buildOptions = BuildOptions.None;
        if (buildConfig == "Debug")
        {
            buildOptions |= BuildOptions.Development | BuildOptions.AllowDebugging;
        }

        // Set build format
        if (buildFormat == "aab")
        {
            EditorUserBuildSettings.buildAppBundle = true;
        }
        else
        {
            EditorUserBuildSettings.buildAppBundle = false;
        }

        // Get scenes
        string[] scenes = EditorBuildSettings.scenes
            .Where(scene => scene.enabled)
            .Select(scene => scene.path)
            .ToArray();

        // Build
        BuildPipeline.BuildPlayer(scenes, outputPath, BuildTarget.Android, buildOptions);
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

    build_args+=(-executeMethod Build.BuildAndroid)
fi

# Add custom parameters
build_args+=(-outputPath "${output_file}")
build_args+=(-defineSymbols "${define_symbols}")
build_args+=(-versionName "${version}")
build_args+=(-buildConfig "${configuration}")
build_args+=(-buildFormat "${format}")

if [ -n "${keystore}" ]; then
    build_args+=(-keystorePath "${keystore_file}")
    build_args+=(-keystorePass "${keystore_password}")
    build_args+=(-keyaliasName "${keystore_user}")
    build_args+=(-keyaliasPass "${keystore_password}")
fi

# Execute Unity build
if ! unity "${build_args[@]}"; then
    echo "::error::Unity build failed for Android"
    exit 1
fi

# Verify output
if [ ! -f "${output_file}" ]; then
    echo "::error::Build output not found: ${output_file}"
    exit 1
fi

echo "::notice::Build completed successfully: ${output_file}"
echo "file=${output_file}" >> "${GITHUB_OUTPUT}"