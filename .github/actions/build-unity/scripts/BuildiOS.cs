using UnityEditor;
using UnityEngine;
using System.Linq;
using System.IO;
using UnityEditor.Build;

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
            string bundleId = GetArg(args, "-bundleId");
            string teamId = GetArg(args, "-teamId");

            Debug.Log($"Build parameters:");
            Debug.Log($"  Output path: {outputPath}");
            Debug.Log($"  Build config: {buildConfig}");
            Debug.Log($"  Version name: {versionName}");
            Debug.Log($"  Bundle ID: {bundleId}");
            Debug.Log($"  Team ID: {teamId}");

            if (string.IsNullOrEmpty(outputPath))
            {
                Debug.LogError("Output path is required but was not provided");
                EditorApplication.Exit(1);
                return;
            }

            if (!string.IsNullOrEmpty(versionName))
            {
                PlayerSettings.bundleVersion = versionName;
                PlayerSettings.iOS.buildNumber = versionName;
                Debug.Log($"Set bundle version to {versionName}");
            }

            if (!string.IsNullOrEmpty(bundleId))
            {
                PlayerSettings.applicationIdentifier = bundleId;
                Debug.Log($"Set bundle identifier to {bundleId}");
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

            Debug.Log("Starting Unity build process...");
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