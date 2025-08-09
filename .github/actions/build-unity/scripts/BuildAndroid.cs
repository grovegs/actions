using UnityEditor;
using UnityEngine;
using System.Linq;
using System;

public static class BuildAndroid
{
    public static void Build()
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
            }
        }

        if (!string.IsNullOrEmpty(defineSymbols))
        {
            PlayerSettings.SetScriptingDefineSymbolsForGroup(BuildTargetGroup.Android, defineSymbols);
        }

        if (!string.IsNullOrEmpty(keystorePath) && System.IO.File.Exists(keystorePath))
        {
            PlayerSettings.Android.keystoreName = keystorePath;
            PlayerSettings.Android.keystorePass = keystorePass;
            PlayerSettings.Android.keyaliasName = keyaliasName;
            PlayerSettings.Android.keyaliasPass = keyaliasPass;
        }

        BuildOptions buildOptions = BuildOptions.None;
        if (buildConfig == "Debug")
        {
            buildOptions |= BuildOptions.Development | BuildOptions.AllowDebugging;
        }

        EditorUserBuildSettings.buildAppBundle = (buildFormat == "aab");

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

        var result = BuildPipeline.BuildPlayer(scenes, outputPath, BuildTarget.Android, buildOptions);
        
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