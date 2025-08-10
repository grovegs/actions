using UnityEditor;
using UnityEngine;
using System.Linq;
using System;
using UnityEditor.Build;
using UnityEditor.Build.Profile;

public static class BuildAndroid
{
    public static void Build()
    {
        try
        {
            Debug.Log("BuildAndroid.Build() started (using Build Profiles)");
            
            var args = Environment.GetCommandLineArgs();
            
            string outputPath = GetArg(args, "-outputPath");
            string defineSymbols = GetArg(args, "-defineSymbols");
            string keystorePath = GetArg(args, "-keystorePath");
            string keystorePass = GetArg(args, "-keystorePass");
            string keyaliasName = GetArg(args, "-keyaliasName");
            string keyaliasPass = GetArg(args, "-keyaliasPass");
            string buildConfig = GetArg(args, "-buildConfig");
            string versionName = GetArg(args, "-versionName");
            string buildFormat = GetArg(args, "-buildFormat");
            string profileName = GetArg(args, "-profileName") ?? "Android";

            Debug.Log($"Build parameters:");
            Debug.Log($"  Output path: {outputPath}");
            Debug.Log($"  Profile name: {profileName}");
            Debug.Log($"  Define symbols: {defineSymbols}");
            Debug.Log($"  Build config: {buildConfig}");
            Debug.Log($"  Version name: {versionName}");
            Debug.Log($"  Build format: {buildFormat}");
            Debug.Log($"  Keystore path: {(string.IsNullOrEmpty(keystorePath) ? "None" : "Provided")}");

            if (string.IsNullOrEmpty(outputPath))
            {
                Debug.LogError("Output path is required but was not provided");
                EditorApplication.Exit(1);
                return;
            }

            BuildProfile buildProfile = FindOrCreateBuildProfile(profileName, BuildTarget.Android);
            
            if (buildProfile == null)
            {
                Debug.LogError($"Failed to find or create build profile: {profileName}");
                EditorApplication.Exit(1);
                return;
            }

            Debug.Log($"Using build profile: {buildProfile.name}");

            ConfigurePlayerSettings(versionName, defineSymbols, keystorePath, keystorePass, keyaliasName, keyaliasPass, buildConfig, buildFormat);

            var buildPlayerOptions = new BuildPlayerOptions
            {
                scenes = EditorBuildSettings.scenes
                    .Where(scene => scene.enabled)
                    .Select(scene => scene.path)
                    .ToArray(),
                locationPathName = outputPath,
                target = BuildTarget.Android,
                options = GetBuildOptions(buildConfig)
            };

            if (buildPlayerOptions.scenes.Length == 0)
            {
                Debug.LogError("No enabled scenes found in build settings");
                EditorApplication.Exit(1);
                return;
            }

            Debug.Log($"Building {buildPlayerOptions.scenes.Length} scenes:");
            foreach (string scene in buildPlayerOptions.scenes)
            {
                Debug.Log($"  - {scene}");
            }

            Debug.Log("Starting Unity build process with Build Profile...");
            
            var result = BuildPipeline.BuildPlayer(buildPlayerOptions);
            
            if (result.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
            {
                Debug.LogError($"Build failed with result: {result.summary.result}");
                
                if (result.summary.totalErrors > 0)
                {
                    Debug.LogError($"Total errors: {result.summary.totalErrors}");
                }
                
                if (result.summary.totalWarnings > 0)
                {
                    Debug.LogWarning($"Total warnings: {result.summary.totalWarnings}");
                }
                
                EditorApplication.Exit(1);
                return;
            }

            Debug.Log($"Build succeeded! Output size: {result.summary.totalSize} bytes");
            Debug.Log($"Build time: {result.summary.totalTime}");
            Debug.Log("BuildAndroid.Build() completed successfully");
        }
        catch (Exception e)
        {
            Debug.LogError($"BuildAndroid.Build() failed with exception: {e.Message}");
            Debug.LogError($"Stack trace: {e.StackTrace}");
            EditorApplication.Exit(1);
        }
    }

    static BuildProfile FindOrCreateBuildProfile(string profileName, BuildTarget target)
    {
        var existingProfile = BuildProfile.GetAvailableBuildProfiles()
            .FirstOrDefault(p => p.name == profileName && p.buildTarget == target);
            
        if (existingProfile != null)
        {
            Debug.Log($"Found existing build profile: {profileName}");
            return existingProfile;
        }

        Debug.Log($"Creating new build profile: {profileName}");
        var newProfile = BuildProfile.CreateInstance(target);
        newProfile.name = profileName;
        
        string profilePath = $"Assets/Settings/BuildProfiles/{profileName}.buildprofile";
        System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(profilePath));
        AssetDatabase.CreateAsset(newProfile, profilePath);
        AssetDatabase.SaveAssets();
        
        Debug.Log($"Created new build profile at: {profilePath}");
        return newProfile;
    }

    static void ConfigurePlayerSettings(string versionName, string defineSymbols, string keystorePath, 
        string keystorePass, string keyaliasName, string keyaliasPass, string buildConfig, string buildFormat)
    {
        if (!string.IsNullOrEmpty(versionName))
        {
            PlayerSettings.bundleVersion = versionName;
            var versionParts = versionName.Split('.');

            if (versionParts.Length >= 3 && 
                int.TryParse(versionParts[0], out int major) &&
                int.TryParse(versionParts[1], out int minor) &&
                int.TryParse(versionParts[2], out int patch))
            {
                long versionCode = (long)major * 10000000L + (long)minor * 10000L + (long)patch;
                PlayerSettings.Android.bundleVersionCode = (int)Math.Min(2147483647L, versionCode);
                Debug.Log($"Set bundle version to {versionName} (code: {PlayerSettings.Android.bundleVersionCode})");
            }
        }

        if (!string.IsNullOrEmpty(defineSymbols))
        {
            PlayerSettings.SetScriptingDefineSymbols(NamedBuildTarget.Android, defineSymbols);
            Debug.Log($"Set define symbols: {defineSymbols}");
        }

        if (!string.IsNullOrEmpty(keystorePath) && System.IO.File.Exists(keystorePath))
        {
            PlayerSettings.Android.keystoreName = keystorePath;
            PlayerSettings.Android.keystorePass = keystorePass;
            PlayerSettings.Android.keyaliasName = keyaliasName;
            PlayerSettings.Android.keyaliasPass = keyaliasPass;
            Debug.Log("Configured Android keystore for signing");
        }

        bool buildAAB = (buildFormat == "aab");
        EditorUserBuildSettings.buildAppBundle = buildAAB;
        Debug.Log($"Build format: {(buildAAB ? "AAB" : "APK")}");
    }

    static BuildOptions GetBuildOptions(string buildConfig)
    {
        BuildOptions buildOptions = BuildOptions.None;
        if (buildConfig == "Debug")
        {
            buildOptions |= BuildOptions.Development | BuildOptions.AllowDebugging;
            Debug.Log("Using Debug build configuration");
        }
        else
        {
            Debug.Log("Using Release build configuration");
        }
        return buildOptions;
    }

    static string GetArg(string[] args, string name)
    {
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == name)
            {
                return args[i + 1];
            }
        }
        return null;
    }
}