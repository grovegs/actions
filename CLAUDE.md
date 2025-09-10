# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains composite GitHub Actions by Grove Games for game development workflows. It provides reusable actions for Unity, Godot, and .NET projects with support for building, testing, and publishing across multiple platforms.

## Architecture

### Action Structure
- **Composite Actions**: Each action is defined in `.github/actions/{action-name}/action.yml`
- **Shell Scripts**: Business logic implemented in `scripts/` subdirectories within each action
- **Multi-platform Support**: Actions support macOS and Linux (Unity/Godot) with platform-specific logic
- **Caching Strategy**: Extensive use of GitHub Actions cache for installers and dependencies

### Key Action Categories
- **Setup Actions**: `setup-unity`, `setup-godot`, `setup-dotnet`, `setup-xcode` - Install and configure development environments
- **Build Actions**: `build-unity`, `build-godot`, `build-dotnet` - Compile projects for various platforms (Android, iOS, etc.)
- **Test Actions**: `test-unity`, `test-godot`, `test-dotnet` - Run automated tests
- **Package Actions**: `pack-dotnet`, `pack-godot-addon` - Create distributable packages
- **Publish Actions**: `publish-firebase`, `publish-testflight`, `publish-nuget`, `publish-github` - Deploy to various platforms

## Development Commands

### Testing
```bash
# Test specific actions using GitHub workflows
# Example: Test Unity setup action
gh workflow run .github/workflows/test-unity-setup.yml

# Run workflows locally (if act is installed)
act -j test-basic-setup
```

### Validation
- **Shell Script Validation**: All shell scripts should be executable and follow bash best practices
- **Action Validation**: Use GitHub's action validation in workflow runs
- **Platform Testing**: Actions are tested on both `ubuntu-latest` and `macos-latest`

## Important Patterns

### Input Validation
- Platform-specific validation scripts (e.g., `validate_platform_inputs.sh`)
- Required vs optional inputs clearly defined in `action.yml`
- Secure handling of credentials via base64 encoding

### Error Handling
- Scripts use proper exit codes (`exit 1` for failures)
- GitHub Actions `continue-on-error` for expected failure scenarios
- Comprehensive error messages with `echo "::error::"`

### Caching Strategy
- Download caches keyed by version, OS, architecture, and modules
- Cache validation with `cache-hit` output checks
- Fallback installation when cache misses

### Security Considerations
- Sensitive inputs (certificates, passwords) handled as secrets
- Base64 encoding for binary assets (keystores, certificates)
- Platform-specific credential management (iOS certificates, Android keystores)

## Script Execution Patterns
- All scripts require `chmod +x` before execution
- Scripts accept parameters in consistent order
- Output variables set via `echo "key=value" >> $GITHUB_OUTPUT`
- GitHub Action path references via `${{ github.action_path }}`

## Sandbox Projects
- `sandbox/UnityApplication` - Unity project for testing Unity actions
- `sandbox/ConsoleApp` - .NET project for testing .NET actions

## Platform Support Matrix
- **Unity**: macOS, Linux with iOS/Android module support
- **Godot**: Cross-platform with Android/iOS export capabilities
- **.NET**: Standard .NET SDK operations
- **Xcode**: macOS-only for iOS builds