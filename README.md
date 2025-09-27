# Actions

[![Tests](https://github.com/grovegs/actions/actions/workflows/tests.yml/badge.svg)](https://github.com/grovegs/actions/actions/workflows/tests.yml)

Grove Games Composite GitHub Actions for development workflows.

## Table of Contents

- [build-dotnet](#build-dotnet)
- [build-godot](#build-godot)
- [build-unity](#build-unity)
- [bump-version](#bump-version)
- [format-dotnet](#format-dotnet)
- [generate-changelog](#generate-changelog)
- [pack-dotnet](#pack-dotnet)
- [pack-godot-addon](#pack-godot-addon)
- [pack-unity-package](#pack-unity-package)
- [publish-firebase](#publish-firebase)
- [publish-github](#publish-github)
- [publish-nuget](#publish-nuget)
- [publish-testflight](#publish-testflight)
- [setup-android](#setup-android)
- [setup-dotnet](#setup-dotnet)
- [setup-godot](#setup-godot)
- [setup-unity](#setup-unity)
- [setup-xcode](#setup-xcode)
- [test-dotnet](#test-dotnet)
- [test-godot](#test-godot)

## build-dotnet

Build a .NET project.

**Inputs:**

- `project` (required): Path to the project file
- `configuration`: Build configuration (default: Release)
- `version`: Version to build with
- `define-symbols`: Define symbols for compilation

## build-godot

Build Godot project for selected platforms.

**Inputs:**

- `project` (required): Path to the Godot project
- `global-json-file`: Path to global.json file
- `version`: Version to build with
- `platform` (required): Target platform (Android, iOS)
- `preset` (required): Export preset name
- `configuration`: Build configuration
- `filename`: Output filename

**Platform-specific inputs:**

- Android: `android-keystore-base64`, `android-keystore-password`, `android-keystore-alias`
- iOS: `ios-certificate-base64`, `ios-certificate-password`, `ios-provisioning-profile-base64`

**Outputs:**

- `file`: Path to the generated build

## build-unity

Build Unity project for Android and iOS platforms using Build Profiles.

**Inputs:**

- `project` (required): Path to the Unity project
- `version`: Version to build with
- `platform` (required): Target platform (Android, iOS)
- `configuration`: Build configuration
- `filename`: Output filename
- `unity-email` (required): Unity account email
- `unity-password` (required): Unity account password
- `unity-license-key` (required): Unity license key

**Platform-specific inputs:**

- Android: `android-keystore-base64`, `android-keystore-password`, `android-keystore-alias`
- iOS: `ios-certificate-base64`, `ios-certificate-password`, `ios-provisioning-profile-base64`

**Outputs:**

- `file`: Path to the generated build

## bump-version

Calculate and bump the next version based on the latest Git tag.

**Inputs:**

- `version-type`: Version bump type (major, minor, patch)

**Outputs:**

- `latest-version`: Current latest version
- `next-version`: Next calculated version

## format-dotnet

Format a .NET project.

**Inputs:**

- `project` (required): Path to the project file

## generate-changelog

Generate structured changelog and format in multiple formats.

**Inputs:**

- `next-version` (required): Next version for changelog

**Outputs:**

- `changelog-raw`: Raw changelog data
- `changelog-plain`: Plain text changelog
- `changelog-markdown`: Markdown formatted changelog

## pack-dotnet

Package a .NET project.

**Inputs:**

- `project` (required): Path to the project file
- `configuration`: Build configuration (default: Release)
- `version`: Version to package with
- `filename`: Output filename

**Outputs:**

- `file`: Path to the generated package

## pack-godot-addon

Package the Godot addon.

**Inputs:**

- `addon` (required): Path to the addon
- `version`: Version to package with
- `filename`: Output filename

**Outputs:**

- `file`: Path to the generated package

## pack-unity-package

Package the Unity package as a local tarball.

**Inputs:**

- `package` (required): Path to the package
- `version`: Version to package with
- `filename`: Output filename

**Outputs:**

- `file`: Path to the generated package

## publish-firebase

Upload a build file to Firebase App Distribution.

**Inputs:**

- `file` (required): Path to the build file
- `app-id` (required): Firebase app ID
- `credentials` (required): Firebase service account credentials (base64)
- `release-notes`: Release notes for the build
- `tester-groups`: Comma-separated list of tester groups

## publish-github

Create a GitHub release and upload specified artifacts.

**Inputs:**

- `title` (required): Release title
- `version` (required): Release version/tag
- `changelog`: Release changelog/notes
- `github-token` (required): GitHub token for API access
- `assets`: Comma-separated list of assets to upload

## publish-nuget

Upload NuGet package to nuget.org.

**Inputs:**

- `file` (required): Path to the NuGet package
- `api-key` (required): NuGet API key

## publish-testflight

Upload an IPA file to TestFlight using App Store Connect API.

**Inputs:**

- `file` (required): Path to the IPA file
- `api-key` (required): App Store Connect API key (base64)
- `api-key-id` (required): API key ID
- `api-issuer-id` (required): API issuer ID

## setup-android

Set up Java and Android SDK with specified packages.

**Inputs:**

- `java-version`: Java version to install (default: 17)
- `java-distribution`: Java distribution (default: temurin)
- `android-packages`: Android SDK packages to install

## setup-dotnet

Setup a .NET project.

**Inputs:**

- `global-json-file`: Path to global.json file
- `cache`: Enable caching (default: true)

**Outputs:**

- `dotnet-version`: Installed .NET version

## setup-godot

Download, install, and cache Godot for the specified platform.

**Inputs:**

- `global-json-file`: Path to global.json file
- `target-platforms`: Target platforms for export templates
- `cache`: Enable caching (default: true)

## setup-unity

Download, install, and cache Unity for macOS and Linux platforms with iOS and Android support.

**Inputs:**

- `project`: Path to the Unity project
- `unity-version`: Unity version to install
- `unity-modules`: Unity modules to install (e.g., 'android ios')
- `cache`: Enable caching (default: true)

## setup-xcode

Validate and select the appropriate Xcode version with iOS SDK compatibility.

**Inputs:**

- `xcode-version` (required): Xcode version to select

## test-dotnet

Test a .NET project.

**Inputs:**

- `project` (required): Path to the project file
- `configuration`: Test configuration (default: Release)

## test-godot

Test a Godot project.

**Inputs:**

- `project` (required): Path to the Godot project
- `global-json-file`: Path to global.json file

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
