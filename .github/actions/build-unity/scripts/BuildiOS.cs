using UnityEditor;
using UnityEngine;
using System.Linq;
using System;
using UnityEditor.Build.Profile;

public static class BuildiOS
{
    public static void Build()
    {
        try
        {
            Debug.Log("BuildiOS.Build() started");
            
            var args = Environment.GetCommandLineArgs();
            
            string outputPath = GetArg(args, "-outputPath");
            string buildConfig = GetArg(args, "-buildConfig");
            string versionName = GetArg(args, "-versionName");
            string profileId = GetArg(args, "-profileId");
            string teamId = GetArg(args, "-teamId");
            string profileName = GetArg(args, "-profileName") ?? "iOS";

            Debug.Log($"Build parameters:");
            Debug.Log($"  Output path: {outputPath}");
            Debug.Log($"  Profile name: {profileName}");
            Debug.Log($"  Build config: {buildConfig}");
            Debug.Log($"  Version name: {versionName}");
            Debug.Log($"  Profile ID: {profileId}");
            Debug.Log($"  Team ID: {teamId}");

            if (string.IsNullOrEmpty(outputPath))
            {
                Debug.LogError("Output path is required but was not provided");
                EditorApplication.Exit(1);
                return;
            }

            if (!string.IsNullOrEmpty(profileName))
            {
                if (!SetBuildProfile(profileName))
                {
                    Debug.LogWarning($"Could not find or set build profile: {profileName}. Using current active profile.");
                }
            }

            if (!string.IsNullOrEmpty(versionName))
            {
                PlayerSettings.bundleVersion = versionName;
                PlayerSettings.iOS.buildNumber = versionName;
                Debug.Log($"Set bundle version to {versionName}");
            }

            if (!string.IsNullOrEmpty(profileId))
            {
                PlayerSettings.iOS.iOSManualProvisioningProfileID = profileId;
                Debug.Log($"Set profile identifier to {profileId}");
            }

            if (!string.IsNullOrEmpty(teamId))
            {
                PlayerSettings.iOS.appleDeveloperTeamID = teamId;
                Debug.Log($"Set Apple Developer Team ID to {teamId}");
            }

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

            string[] scenes = EditorBuildSettings.scenes
                .Where(scene => scene.enabled)
                .Select(scene => scene.path)
                .ToArray();

            if (scenes.Length == 0)
            {
                Debug.LogError("No enabled scenes found in build settings");
                EditorApplication.Exit(1);
                return;
            }

            Debug.Log($"Building {scenes.Length} scenes:");

            foreach (string scene in scenes)
            {
                Debug.Log($"  - {scene}");
            }

            Debug.Log("Starting Unity build process with active profile");
            var result = BuildPipeline.BuildPlayer(scenes, outputPath, BuildTarget.iOS, buildOptions);
            
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
            Debug.Log("BuildiOS.Build() completed successfully");
        }
        catch (Exception e)
        {
            Debug.LogError($"BuildiOS.Build() failed with exception: {e.Message}");
            Debug.LogError($"Stack trace: {e.StackTrace}");
            EditorApplication.Exit(1);
        }
    }

    static bool SetBuildProfile(string profileName)
    {
        try
        {
            string[] guids = AssetDatabase.FindAssets($"{profileName} t:BuildProfile");
            
            if (guids.Length > 0)
            {
                string assetPath = AssetDatabase.GUIDToAssetPath(guids[0]);
                BuildProfile profile = AssetDatabase.LoadAssetAtPath<BuildProfile>(assetPath);
                
                if (profile != null)
                {
                    BuildProfile.SetActiveBuildProfile(profile);
                    Debug.Log($"Successfully set active build profile to: {profile.name} (Path: {assetPath})");
                    return true;
                }
            }
            
            Debug.LogWarning($"Build profile '{profileName}' not found. Available profiles:");
            string[] allGuids = AssetDatabase.FindAssets("t:BuildProfile");
            foreach (string guid in allGuids)
            {
                string assetPath = AssetDatabase.GUIDToAssetPath(guid);
                BuildProfile profile = AssetDatabase.LoadAssetAtPath<BuildProfile>(assetPath);

                if (profile != null)
                {
                    Debug.LogWarning($"  - {profile.name} at {assetPath}");
                }
            }
            return false;
        }
        catch (Exception e)
        {
            Debug.LogError($"Error setting build profile: {e.Message}");
            return false;
        }
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