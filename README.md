# Actions

[![Tests](https://github.com/grovegs/actions/actions/workflows/tests.yml/badge.svg)](https://github.com/grovegs/actions/actions/workflows/tests.yml)
[![Latest Release](https://img.shields.io/github/v/release/grovegs/actions)](https://github.com/grovegs/actions/releases/latest)

---

## Overview

A comprehensive collection of reusable GitHub Actions designed specifically for game development workflows. These actions provide seamless automation for building, testing, formatting, packaging, and publishing Unity, Godot, and .NET projects across multiple platforms including Android, iOS, Windows, macOS, and Linux.

**Key Differentiators:**

- **Game Engine Focused**: Purpose-built for Unity and Godot workflows with deep integration support
- **Cross-Platform**: Native support for mobile (Android, iOS), desktop (Windows, macOS, Linux), and web platforms
- **Production Ready**: Battle-tested actions with extensive error handling, caching, and retry logic
- **Zero Configuration**: Smart defaults with minimal required inputs for quick setup

**Ideal For:**

- Game studios automating their CI/CD pipeline
- Independent developers needing reliable build automation
- Teams requiring consistent cross-platform builds
- Projects targeting Native AOT compilation or mobile platforms

---

## Features

- **Multi-Engine Support**: Seamless integration with Unity, Godot, and .NET projects
- **Mobile Builds**: Full Android and iOS build support with code signing
- **Automated Testing**: Run unit tests and validation across all platforms
- **Code Formatting**: Automatic formatting for C#, YAML, JSON, Markdown, and Shell scripts
- **Package Management**: Create NuGet packages, Unity packages, and Godot addons
- **Distribution**: Publish to Firebase, TestFlight, NuGet, and GitHub Releases
- **Smart Caching**: Intelligent caching for Unity, Godot, .NET, and build dependencies
- **Version Management**: Automatic version bumping and changelog generation

---

## Requirements

**GitHub Runners:**

- `ubuntu-latest` - For .NET, Android, and Godot Linux builds
- `macos-latest` - Required for iOS and macOS builds
- `windows-latest` - Optional for Windows-specific builds

**Additional Requirements:**

- Secrets configured for signing (keystores, certificates, provisioning profiles)
- Unity/Godot license keys for engine-specific builds

---

## Installation

These actions are designed to be used directly in your GitHub workflows. No installation is required - simply reference the actions in your workflow files.

### Basic Usage

Add actions to your `.github/workflows` directory:

```yaml
name: Build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Project
        uses: grovegs/actions/build-unity@v1.0.0
        with:
          project: ./MyGame
          platform: Android
```

---

## Quick Start

### Unity Project Example

Build a Unity project for Android:

```yaml
name: Unity Build

on:
  push:
    branches: [main]

jobs:
  build-android:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Android SDK
        uses: grovegs/actions/setup-android@v1.0.0
        with:
          java-version: 17
          android-packages: "platform-tools platforms;android-34 build-tools;34.0.0 ndk;25.1.8937393"

      - name: Setup Unity
        uses: grovegs/actions/setup-unity@v1.0.0
        with:
          project: ./MyGame
          unity-modules: android
          cache: true

      - name: Build Android
        uses: grovegs/actions/build-unity@v1.0.0
        with:
          project: ./MyGame
          platform: Android
          configuration: Release
          filename: MyGame
          unity-email: ${{ secrets.UNITY_EMAIL }}
          unity-password: ${{ secrets.UNITY_PASSWORD }}
          unity-license-key: ${{ secrets.UNITY_LICENSE }}
          android-keystore: ${{ secrets.ANDROID_KEYSTORE }}
          android-keystore-user: ${{ secrets.ANDROID_KEYSTORE_USER }}
          android-keystore-password: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          android-format: aab
```

### Godot Project Example

Build a Godot project for iOS:

```yaml
name: Godot Build

on:
  push:
    branches: [main]

jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: grovegs/actions/setup-dotnet@v1.0.0
        with:
          global-json-file: ./MyGame/global.json

      - name: Setup Xcode
        uses: grovegs/actions/setup-xcode@v1.0.0
        with:
          xcode-version: "16.2"

      - name: Setup Godot
        uses: grovegs/actions/setup-godot@v1.0.0
        with:
          global-json-file: ./MyGame/global.json
          target-platforms: iOS
          cache: true

      - name: Build iOS
        uses: grovegs/actions/build-godot@v1.0.0
        with:
          project: ./MyGame
          global-json-file: ./MyGame/global.json
          version: 1.0.0
          platform: iOS
          preset: iOS
          configuration: Release
          filename: MyGame
          ios-team-id: ${{ secrets.IOS_TEAM_ID }}
          ios-certificate: ${{ secrets.IOS_CERTIFICATE }}
          ios-certificate-password: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
          ios-provisioning-profile: ${{ secrets.IOS_PROVISIONING_PROFILE }}
          ios-provisioning-profile-uuid: ${{ secrets.IOS_PROVISIONING_PROFILE_UUID }}
```

### .NET Project Example

Build and publish a NuGet package:

```yaml
name: .NET Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: grovegs/actions/setup-dotnet@v1.0.0
        with:
          global-json-file: ./global.json
          cache: true

      - name: Test
        uses: grovegs/actions/test-dotnet@v1.0.0
        with:
          project: ./MyLibrary
          configuration: Debug

      - name: Build
        uses: grovegs/actions/build-dotnet@v1.0.0
        with:
          project: ./MyLibrary
          configuration: Release
          version: 1.0.0

      - name: Pack
        uses: grovegs/actions/pack-dotnet@v1.0.0
        with:
          project: ./MyLibrary
          configuration: Release
          version: 1.0.0
          filename: MyLibrary

      - name: Publish to NuGet
        uses: grovegs/actions/publish-nuget@v1.0.0
        with:
          file: ~/.nupkgs/MyLibrary.nupkg
          api-key: ${{ secrets.NUGET_API_KEY }}
```

---

## Available Actions

### Setup Actions

**setup-dotnet** - Configure .NET environment
- Inputs: `global-json-file`, `cache`
- Outputs: `dotnet-version`

**setup-godot** - Install Godot engine and export templates
- Inputs: `global-json-file`, `target-platforms`, `cache`
- Supports: Linux, macOS

**setup-unity** - Install Unity editor and modules
- Inputs: `project`, `unity-version`, `unity-modules`, `cache`
- Supports: Linux, macOS with iOS/Android modules

**setup-android** - Configure Android SDK, NDK, and Java
- Inputs: `java-version`, `java-distribution`, `android-packages`

**setup-xcode** - Select and configure Xcode version
- Inputs: `xcode-version`
- Requires: macOS runner

### Build Actions

**build-dotnet** - Build .NET projects
- Inputs: `project`, `configuration`, `version`, `define-symbols`

**build-godot** - Build Godot projects for mobile platforms
- Inputs: `project`, `global-json-file`, `version`, `platform`, `preset`, `configuration`, `filename`
- Supports: Android (APK/AAB), iOS (IPA)

**build-unity** - Build Unity projects using Build Profiles
- Inputs: `project`, `version`, `platform`, `configuration`, `filename`, `profile-name`
- Supports: Android (APK/AAB), iOS (IPA)

### Test Actions

**test-dotnet** - Run .NET unit tests
- Inputs: `project`, `configuration`

**test-godot** - Run Godot project tests
- Inputs: `project`, `global-json-file`

### Format Actions

**format-dotnet** - Format C# code using dotnet format
- Inputs: `project`

**format-files** - Format YAML, JSON, Markdown, Shell scripts using Prettier
- Inputs: `files`, `ignore-path`

### Package Actions

**pack-dotnet** - Create NuGet packages
- Inputs: `project`, `configuration`, `version`, `filename`
- Outputs: `file`

**pack-godot-addon** - Package Godot addons
- Inputs: `addon`, `version`, `filename`
- Outputs: `file`

**pack-unity-package** - Package Unity packages as tarballs
- Inputs: `package`, `version`, `filename`
- Outputs: `file`

### Publish Actions

**publish-firebase** - Upload to Firebase App Distribution
- Inputs: `file`, `app-id`, `credentials`, `release-notes`, `tester-groups`

**publish-testflight** - Upload to Apple TestFlight
- Inputs: `file`, `api-key`, `api-key-id`, `api-issuer-id`
- Requires: macOS runner

**publish-nuget** - Publish to NuGet.org
- Inputs: `file`, `api-key`

**publish-github** - Create GitHub releases with assets
- Inputs: `title`, `version`, `changelog`, `github-token`, `assets`

### Utility Actions

**bump-version** - Automatic version bumping based on Git tags
- Inputs: `version-type` (major, minor, patch)
- Outputs: `latest-version`, `next-version`

**generate-changelog** - Generate structured release notes
- Inputs: `next-version`
- Outputs: `changelog-raw`, `changelog-plain`, `changelog-markdown`

---

## Advanced Usage

### Complete Release Workflow

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      version-type:
        description: Version to increment
        required: true
        type: choice
        options:
          - major
          - minor
          - patch

permissions:
  contents: write

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.bump.outputs.next-version }}
      changelog: ${{ steps.changelog.outputs.changelog-markdown }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Bump Version
        id: bump
        uses: grovegs/actions/bump-version@v1.0.0
        with:
          version-type: ${{ inputs.version-type }}

      - name: Generate Changelog
        id: changelog
        uses: grovegs/actions/generate-changelog@v1.0.0
        with:
          next-version: ${{ steps.bump.outputs.next-version }}

  build-unity:
    needs: prepare
    strategy:
      matrix:
        platform: [Android, iOS]
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup
        uses: grovegs/actions/setup-unity@v1.0.0
        with:
          project: ./Game
          unity-modules: ${{ matrix.platform == 'Android' && 'android' || 'ios' }}

      - name: Build
        uses: grovegs/actions/build-unity@v1.0.0
        with:
          project: ./Game
          platform: ${{ matrix.platform }}
          version: ${{ needs.prepare.outputs.version }}
          # ... additional inputs

  publish:
    needs: [prepare, build-unity]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create GitHub Release
        uses: grovegs/actions/publish-github@v1.0.0
        with:
          title: "Release v${{ needs.prepare.outputs.version }}"
          version: "v${{ needs.prepare.outputs.version }}"
          changelog: ${{ needs.prepare.outputs.changelog }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Multi-Platform Build Matrix

```yaml
jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - platform: Android
            runner: ubuntu-latest
            format: aab
          - platform: iOS
            runner: macos-latest
            format: ipa
          - platform: Windows
            runner: windows-latest
            format: exe
    
    runs-on: ${{ matrix.runner }}
    steps:
      # Build steps using matrix values
```

### Conditional Publishing

```yaml
- name: Publish to Firebase
  if: github.ref == 'refs/heads/develop'
  uses: grovegs/actions/publish-firebase@v1.0.0

- name: Publish to TestFlight
  if: github.ref == 'refs/heads/main'
  uses: grovegs/actions/publish-testflight@v1.0.0
```

---

## Troubleshooting

### Common Issues

**Issue: Unity build fails with licensing error**

**Solution:** Ensure you have set up the required secrets:
```yaml
UNITY_EMAIL: Your Unity account email
UNITY_PASSWORD: Your Unity account password
UNITY_LICENSE: Your Unity serial key
```

---

**Issue: Android build fails with keystore error**

**Solution:** Keystore must be base64 encoded:
```bash
base64 -i your-keystore.jks | pbcopy  # macOS
base64 -i your-keystore.jks          # Linux
```

Then add as a secret: `ANDROID_KEYSTORE`

---

**Issue: iOS build fails with provisioning profile error**

**Cause:** Missing or incorrect provisioning profile configuration

**Solution:** Ensure all iOS secrets are properly configured:
```yaml
IOS_TEAM_ID: Your Apple Developer Team ID
IOS_CERTIFICATE: Base64-encoded .p12 certificate
IOS_CERTIFICATE_PASSWORD: Certificate password
IOS_PROVISIONING_PROFILE: Base64-encoded .mobileprovision file
IOS_PROVISIONING_PROFILE_UUID: Profile UUID
```

---

**Issue: Cache not working or builds are slow**

**Solution:** Enable caching in setup actions:
```yaml
- uses: grovegs/actions/setup-unity@v1.0.0
  with:
    cache: true  # Enable caching
```

---

### Getting More Help

If you encounter issues not listed here:

1. Check [existing issues](https://github.com/grovegs/actions/issues)
2. Open a [new issue](https://github.com/grovegs/actions/issues/new) with:
   - Action name and version
   - Runner OS and version
   - Complete workflow file
   - Error logs
3. Contact us at [support@grove.gs](mailto:support@grove.gs)

---

## Contributing

Contributions are welcome! We appreciate your help in making this project better.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write or update tests
5. Ensure all tests pass (`gh workflow run tests.yml`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Contribution Guidelines

- Follow existing code style and conventions
- Test your changes thoroughly
- Update documentation as needed
- Keep commits focused and atomic
- Write clear commit messages following [Conventional Commits](https://www.conventionalcommits.org/)

### Development Setup

```bash
# Clone the repository
git clone https://github.com/grovegs/actions.git

# Navigate to directory
cd actions

# Test actions locally using act (optional)
act -j test-basic-setup
```

---

## Support

- 🐛 [Issue Tracker](https://github.com/grovegs/actions/issues) - Report bugs or request features
- 📧 [support@grove.gs](mailto:support@grove.gs) - Email support
- 🌐 [grove.gs](https://grove.gs) - Official website

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
