#!/usr/bin/env bats

# Load bats-support and bats-assert
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load

# Path to the script under test
BUILD_SCRIPT="../../.github/actions/build-dotnet/scripts/build_project.sh"

# Helper function to set up a mock project directory
setup_project() {
    mkdir -p test_project
    cat <<EOL >test_project/test_project.csproj
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
EOL
}

# Clean up mock project directory
teardown_project() {
    rm -rf test_project
}

# Test: Script fails if insufficient arguments are provided
@test "Fails with insufficient arguments" {
    run bash "$BUILD_SCRIPT"
    assert_failure
    assert_output "::error::Usage: $BUILD_SCRIPT <project> <configuration> [<version>] [<define_symbols>]"
}

# Test: Script fails if the project directory does not exist
@test "Fails when project directory does not exist" {
    run bash "$BUILD_SCRIPT" nonexistent_project Release
    assert_failure
    assert_output "::error::Project directory 'nonexistent_project' does not exist."
}

# Test: Script fails if the project file does not exist
@test "Fails when project file does not exist" {
    mkdir nonexistent_project
    run bash "$BUILD_SCRIPT" nonexistent_project Release
    assert_failure
    assert_output "::error::Project file 'nonexistent_project/nonexistent_project.csproj' does not exist."
    rmdir nonexistent_project
}

# Test: Script builds successfully with valid inputs
@test "Builds successfully with valid inputs" {
    setup_project
    run bash "$BUILD_SCRIPT" test_project Release
    assert_success
    assert_output --partial "::group::Building test_project/test_project.csproj"
    assert_output --partial "::notice::Configuration: Release"
    teardown_project
}

# Test: Handles optional version flag
@test "Handles version flag" {
    setup_project
    run bash "$BUILD_SCRIPT" test_project Release 1.0.0
    assert_success
    assert_output --partial "-p:Version=1.0.0"
    teardown_project
}

# Test: Handles optional define symbols flag
@test "Handles optional define symbols flag" {
    setup_project
    run bash "$BUILD_SCRIPT" test_project Release "" "DEBUG;TRACE"
    assert_success
    assert_output --partial "-p:DefineSymbols=\"DEBUG;TRACE\""
    teardown_project
}

@test "Fails when build command fails" {
    setup_project
    # Replace TargetFramework with an invalid value
    sed -i '' 's/net8.0/invalid-framework/' test_project/test_project.csproj
    # Run the build script
    run bash "$BUILD_SCRIPT" test_project Release
    assert_failure
    assert_output --partial "::error::Build failed with exit code"
    teardown_project
}
