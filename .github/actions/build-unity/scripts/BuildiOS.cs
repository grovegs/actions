using UnityEditor;
using UnityEditor.iOS.Xcode;
using UnityEngine;
using System.Linq;
using System.IO;

public static class BuildiOS
{
    public static void Build()
    {
        var args = System.Environment.GetCommandLineArgs();
        string outputPath = GetArg(args, "-outputPath");
        string defineSymbols = GetArg(args, "-defineSymbols");
        string buildConfig = GetArg(args, "-buildConfig");
        string versionName = GetArg(args, "-versionName");
        string bundleId = GetArg(args, "-bundleId");
        string teamId = GetArg(args, "-teamId");

        if (!string.IsNullOrEmpty(versionName))
        {
            PlayerSettings.bundleVersion = versionName;
            PlayerSettings.iOS.buildNumber = versionName;
        }

        if (!string.IsNullOrEmpty(bundleId))
        {
            PlayerSettings.applicationIdentifier = bundleId;
        }

        if (!string.IsNullOrEmpty(teamId))
        {
            PlayerSettings.iOS.appleDeveloperTeamID = teamId;
        }

        if (!string.IsNullOrEmpty(defineSymbols))
        {
            PlayerSettings.SetScriptingDefineSymbolsForGroup(BuildTargetGroup.iOS, defineSymbols);
        }

        BuildOptions buildOptions = BuildOptions.None;
        if (buildConfig == "Debug")
        {
            buildOptions |= BuildOptions.Development | BuildOptions.AllowDebugging;
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

        var result = BuildPipeline.BuildPlayer(scenes, outputPath, BuildTarget.iOS, buildOptions);
        
        if (result.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
        {
            Debug.LogError($"Build failed: {result.summary.result}");
            EditorApplication.Exit(1);
        }
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