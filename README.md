# Actions

[![Build Status](https://github.com/grovegs/actions/actions/workflows/release.yml/badge.svg)](https://github.com/grovegs/actions/actions/workflows/release.yml)
[![Tests](https://github.com/grovegs/actions/actions/workflows/tests.yml/badge.svg)](https://github.com/grovegs/actions/actions/workflows/tests.yml)
[![Latest Release](https://img.shields.io/github/v/release/grovegs/actions)](https://github.com/grovegs/actions/releases/latest)

A collection of reusable GitHub Actions for development workflows, supporting .NET, Unity, and Godot projects.

## Features

- **Cross-platform builds** - Build for Android, iOS, and desktop platforms
- **Multiple engines** - Support for Unity, Godot, and .NET projects
- **Automated workflows** - Version bumping, changelog generation, and publishing
- **Easy setup** - Pre-configured actions for common development tasks

## Quick Start

Add any of these actions to your GitHub workflow:

```yaml
- name: Build Unity Project
  uses: grovegs/actions/build-unity@v1.0.0
  with:
    project: ./MyGame
    platform: Android
    unity-email: ${{ secrets.UNITY_EMAIL }}
    unity-password: ${{ secrets.UNITY_PASSWORD }}
    unity-license-key: ${{ secrets.UNITY_LICENSE }}
```

## Available Actions

- `build-dotnet` - Build .NET projects
- `build-godot` - Build Godot projects for mobile platforms
- `build-unity` - Build Unity projects using Build Profiles
- `bump-version` - Automatic version management
- `format-dotnet` - Code formatting for .NET projects
- `format-files` - Format YAML, JSON, Markdown, Shell scripts and other files using Prettier
- `generate-changelog` - Create structured release notes
- `pack-dotnet` - Package .NET projects
- `pack-godot-addon` - Package Godot addons
- `pack-unity-package` - Package Unity packages as tarballs
- `publish-firebase` - Upload to Firebase App Distribution
- `publish-github` - Create GitHub releases with assets
- `publish-nuget` - Publish to NuGet
- `publish-testflight` - Upload to TestFlight
- `setup-android` - Configure Android SDK and Java
- `setup-dotnet` - Setup .NET environment
- `setup-godot` - Install Godot engine with export templates
- `setup-unity` - Install Unity editor with modules
- `setup-xcode` - Configure Xcode for iOS builds
- `test-dotnet` - Run .NET tests
- `test-godot` - Run Godot tests

## Usage Examples

### Building a Unity Project

```yaml
- uses: grovegs/actions/build-unity@v1.0.0
  with:
    project: ./MyGame
    platform: Android
    unity-email: ${{ secrets.UNITY_EMAIL }}
    unity-password: ${{ secrets.UNITY_PASSWORD }}
    unity-license-key: ${{ secrets.UNITY_LICENSE }}
```

### Publishing to GitHub Releases

```yaml
- uses: grovegs/actions/publish-github@v1.0.0
  with:
    title: "v1.0.0 Release"
    version: "1.0.0"
    changelog: ${{ steps.changelog.outputs.changelog-markdown }}
    github-token: ${{ secrets.GITHUB_TOKEN }}
    assets: "builds/game.apk,builds/game.ipa"
```

### Complete Workflow Example

```yaml
name: Build and Release
on:
  push:
    tags: ["v*"]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: grovegs/actions/setup-unity@v1.0.0
        with:
          project: ./MyGame
          unity-modules: android ios

      - uses: grovegs/actions/build-unity@v1.0.0
        with:
          project: ./MyGame
          platform: Android
          unity-email: ${{ secrets.UNITY_EMAIL }}
          unity-password: ${{ secrets.UNITY_PASSWORD }}
          unity-license-key: ${{ secrets.UNITY_LICENSE }}

      - uses: grovegs/actions/publish-github@v1.0.0
        with:
          title: "Release ${{ github.ref_name }}"
          version: ${{ github.ref_name }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          assets: ${{ steps.build.outputs.file }}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
