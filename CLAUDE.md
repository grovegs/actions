# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains composite GitHub Actions by Grove Games for game development workflows. It provides reusable actions for Unity, Godot, and .NET projects with support for building, testing, and publishing across multiple platforms.

## Architecture

### Action Structure

- **Composite Actions**: Each action is defined in `.github/actions/{action-name}/action.yml`
- **Shell Scripts**: Business logic implemented in `scripts/` subdirectories within each action
- **Multi-platform Support**: Actions support macOS and Linux (Unity/Godot) with platform-specific logic
- **Environment Variables**: All inputs passed to scripts via `env:` blocks, never as positional arguments
- **Self-Validating Scripts**: Each script validates its own required inputs at the start
- **Caching Strategy**: Extensive use of GitHub Actions cache for installers and dependencies

### Key Action Categories

- **Setup Actions**: `setup-unity`, `setup-godot`, `setup-dotnet`, `setup-android`, `setup-xcode` - Install and configure development environments
- **Build Actions**: `build-unity`, `build-godot`, `build-dotnet` - Compile projects for various platforms (Android, iOS, etc.)
- **Test Actions**: `test-unity`, `test-godot`, `test-dotnet` - Run automated tests
- **Format Actions**: `format-dotnet`, `format-files` - Code formatting and style consistency
- **Package Actions**: `pack-dotnet`, `pack-godot-addon`, `pack-unity-package` - Create distributable packages
- **Publish Actions**: `publish-firebase`, `publish-testflight`, `publish-nuget`, `publish-github` - Deploy to various platforms
- **Utility Actions**: `bump-version`, `generate-changelog`, `upload-artifact`, `download-artifact` - Version management and artifact handling

## Development Commands

### Testing

```bash
# Test specific actions using GitHub workflows
gh workflow run .github/workflows/tests.yml

# Run workflows locally (if act is installed)
act -j test-basic-setup
```

### Formatting

```bash
# Format .NET projects
dotnet format sandbox/ConsoleApp

# Format YAML, JSON, Markdown files
prettier --write "**/*.{yml,yaml,json,md}" --ignore-path .gitignore

# Format shell scripts
prettier --write "**/*.sh" --ignore-path .gitignore

# Run all formatting via GitHub workflow
gh workflow run .github/workflows/format.yml
```

### Validation

- **Shell Script Validation**: All shell scripts should be executable and follow bash best practices
- **Shellcheck**: Run `shellcheck .github/actions/**/scripts/*.sh` to validate shell scripts
- **Action Validation**: Use GitHub's action validation in workflow runs
- **Platform Testing**: Actions are tested on both `ubuntu-latest` and `macos-latest`

## Important Patterns

### Environment Variables for Script Input

**CRITICAL:** Always pass inputs to scripts via `env:` block, never as positional arguments.

**In action.yml:**
```yaml
- name: 📦 Pack Project
  id: pack
  shell: bash
  env:
    PROJECT_PATH: ${{ inputs.project }}
    BUILD_CONFIGURATION: ${{ inputs.configuration }}
    PACKAGE_VERSION: ${{ inputs.version }}
  run: |
    chmod +x "${{ github.action_path }}/scripts/pack_project.sh"
    "${{ github.action_path }}/scripts/pack_project.sh"
```

**In script:**
```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PROJECT_PATH:-}" ]; then
  echo "::error::PROJECT_PATH environment variable is required"
  exit 1
fi

# Script logic using environment variables
```

### Self-Validating Scripts

Each script should validate its own required inputs at the start. Avoid separate validation scripts unless validation logic is truly shared across multiple independent actions.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Validate required inputs
if [ -z "${PROJECT_DIR:-}" ]; then
  echo "::error::PROJECT_DIR environment variable is required"
  exit 1
fi

if [ -z "${ANDROID_KEYSTORE:-}" ]; then
  echo "::error::ANDROID_KEYSTORE is required for Android builds"
  exit 1
fi

# Build logic here...
```

### Input Descriptions

Use unquoted descriptions without backticks for consistency:

```yaml
inputs:
  configuration:
    description: The build configuration such as Release or Debug.
    required: false
    default: Release
  platform:
    description: The target platform for the build. Supported values are Android and iOS.
    required: true
```

### Variable Scope and Declaration

- Use `local` **ONLY inside functions** - it's invalid at script level
- Use `declare` at script level or inside functions
- Use `unset` to clean up arrays between loop iterations

**Script-level:**
```bash
#!/usr/bin/env bash
set -euo pipefail

declare -a BUILD_ARGS
BUILD_ARGS=(
  --nologo
  --configuration "${CONFIGURATION}"
)
```

**Function-level:**
```bash
restore_from_metadata() {
  local metadata_file="$1"
  local source_base="$2"
  local -a files

  # Function logic...
  return 0
}
```

### Glob Expansion

Always use `nullglob` for safe glob expansion:

```bash
shopt -s nullglob
METADATA_FILES=("${DIR}"/*.meta)
shopt -u nullglob

if [ ${#METADATA_FILES[@]} -eq 0 ]; then
  echo "::warning::No metadata files found"
  exit 0
fi

for file in "${METADATA_FILES[@]}"; do
  echo "Processing: ${file}"
done
```

### Error Handling

- Scripts use proper exit codes (`exit 1` for failures)
- GitHub Actions `continue-on-error` for expected failure scenarios
- Comprehensive error messages with `echo "::error::"`
- Always use `set -euo pipefail` in script headers

### Caching Strategy

- Download caches keyed by version, OS, architecture, and modules
- Cache validation with `cache-hit` output checks
- Fallback installation when cache misses

### Security Considerations

- Sensitive inputs (certificates, passwords) handled as secrets
- Base64 encoding for binary assets (keystores, certificates)
- Platform-specific credential management (iOS certificates, Android keystores)

### Formatting Configuration

- **EditorConfig**: `.editorconfig` defines consistent formatting rules across all editors
- **VS Code Settings**: `.vscode/settings.json` provides format-on-save and editor-specific configuration
- **Prettier**: Uses EditorConfig for formatting YAML (4 spaces), JSON/Markdown (2 spaces), and shell scripts
- **prettier-plugin-sh**: Shell script formatting plugin for Prettier with consistent indentation
- **dotnet format**: Automatic C# code formatting following .NET conventions

## Script Execution Patterns

### Script Header

**Always start scripts with:**
```bash
#!/usr/bin/env bash
set -euo pipefail
```

### Input Validation

**Always validate required environment variables:**
```bash
if [ -z "${REQUIRED_VAR:-}" ]; then
  echo "::error::REQUIRED_VAR environment variable is required"
  exit 1
fi

if [ ! -f "${FILE_PATH}" ]; then
  echo "::error::File '${FILE_PATH}' not found"
  exit 1
fi
```

### Output Redirection

**Use command grouping for efficient file operations:**
```bash
{
  echo "package=${PACKAGE_FILE}"
  echo "modified-files=${MODIFIED_FILE}"
} >> "${GITHUB_OUTPUT}"
```

### Quoting

**Always quote variables:**
```bash
if [ -d "${PROJECT_DIR}" ]; then
  cd "${PROJECT_DIR}"
  echo "Working in: ${PROJECT_DIR}"
fi
```

### Functions and Code Reuse

**Extract repeated logic into functions:**
```bash
restore_from_metadata() {
  local metadata_file="$1"
  local source_base="$2"

  if [ ! -f "${metadata_file}" ]; then
    return 1
  fi

  # Restoration logic...
  return 0
}

# Use the function multiple times
restore_from_metadata "${METADATA_1}" "${BASE_1}"
restore_from_metadata "${METADATA_2}" "${BASE_2}"
```

## Package Actions Pattern

Actions that package/build artifacts and modify source files should:
1. Update version in source files (in workspace)
2. Create packaged artifacts (outside workspace)
3. Return paths to both package and modified files

**Example outputs:**
```yaml
outputs:
  package:
    description: Path to the created package file
    value: ${{ steps.pack.outputs.package }}
  modified-files:
    description: Newline-separated paths to modified files in workspace
    value: ${{ steps.pack.outputs.modified-files }}
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Action folder | kebab-case | `pack-dotnet`, `pack-godot-addon` |
| Action name (in yml) | Title Case | `Pack .NET`, `Pack Godot Addon` |
| Input names | kebab-case | `directory-build-props`, `retention-days` |
| Output names | kebab-case | `modified-files`, `package` |
| Step IDs | kebab-case | `pack-project`, `bump-version` |
| Step names | Emoji + Sentence | `📦 Pack Project` |
| Environment vars | SCREAMING_SNAKE | `PACKAGE_VERSION`, `BUILD_CONFIGURATION` |
| Scripts | snake_case.sh | `pack_project.sh`, `pack_addon.sh` |

### Step Emoji Guide

- 📂 Checkout/Files
- 🔧 Setup/Configuration
- 🏗️ Build
- 🧪 Test
- 📦 Package
- 📤 Upload
- 📥 Download
- 🚀 Deploy
- 🎨 Format/Lint
- ✅ Verify/Validate
- 🧹 Cleanup
- 💾 Commit
- 🤖 Android
- 🍎 iOS/Xcode
- 🎮 Game Engines

## Multi-Platform Build Pattern

For actions that support multiple platforms (like Unity builds), use a wrapper script pattern:

**build-unity/scripts/build_project.sh:**
```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${PLATFORM:-}" ]; then
  echo "::error::PLATFORM environment variable is required"
  exit 1
fi

case "${PLATFORM}" in
  "Android")
    chmod +x "${GITHUB_ACTION_PATH}/scripts/build_android.sh"
    "${GITHUB_ACTION_PATH}/scripts/build_android.sh"
    ;;
  "iOS")
    chmod +x "${GITHUB_ACTION_PATH}/scripts/build_ios.sh"
    "${GITHUB_ACTION_PATH}/scripts/build_ios.sh"
    ;;
  *)
    echo "::error::Unsupported platform: ${PLATFORM}"
    exit 1
    ;;
esac
```

## Sandbox Projects

- `sandbox/UnityApplication` - Unity project for testing Unity actions
- `sandbox/ConsoleApp` - .NET project for testing .NET actions
- `sandbox/GodotApplication` - Godot project for testing Godot actions

## Platform Support Matrix

- **Unity**: macOS, Linux with iOS/Android module support
- **Godot**: Cross-platform with Android/iOS export capabilities
- **.NET**: Standard .NET SDK operations
- **Xcode**: macOS-only for iOS builds

## Best Practices

### Action Design

1. **Single Responsibility:** Each action should do one thing well
2. **Reusability:** Design actions to be used across multiple projects
3. **Clear Inputs:** Use descriptive names and provide defaults
4. **Error Handling:** Validate inputs and provide helpful error messages
5. **Documentation:** Include descriptions for all inputs/outputs
6. **Single Item:** Design for single items, use matrix strategies for multiple
7. **Environment Variables:** Always use `env:` block to pass inputs to scripts
8. **Clean YAML:** Keep action.yml steps simple; move complex logic to scripts

### Script Best Practices

1. **Shellcheck Compliance:** Run shellcheck on all scripts
2. **Self-Validating:** Each script validates its own required inputs
3. **Proper Headers:** Use `#!/usr/bin/env bash` and `set -euo pipefail`
4. **Quote Variables:** Always quote variables: `"${VAR}"`
5. **Command Grouping:** Use `{ cmd1; cmd2; } >> "${file}"` for output redirection
6. **Nullglob:** Use `shopt -s nullglob` before glob expansion
7. **Functions:** Extract repeated logic into functions for DRY principle
8. **Variable Scope:** Use `local` only in functions, `declare` at script level

### Workflow Design

1. **Meaningful Names:** Use emoji and clear job names
2. **Fast Feedback:** Put quick tests first
3. **Parallelization:** Use matrix strategies for independent tasks
4. **Appropriate Runners:** Choose the right OS for each job
5. **Caching:** Cache dependencies to speed up workflows

## Troubleshooting

### Common Issues

1. **Action not found:** Check path `./.github/actions/action-name`
2. **Script permission denied:** Add `chmod +x` before running
3. **Input not passed:** Use `env:` block in action.yml, not arguments
4. **Path issues:** Use `${{ github.action_path }}` for action-relative paths
5. **Unbound variable:** Use `set -euo pipefail` and quote all variables
6. **Shellcheck warnings:** Run `shellcheck script.sh` and fix issues
7. **`local` outside function:** Use `declare` at script level instead
8. **Glob doesn't match:** Use `shopt -s nullglob` before glob expansion
9. **Array not cleared:** Use `unset ARRAY_NAME` between loop iterations
