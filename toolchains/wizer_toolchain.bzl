"""Wizer WebAssembly pre-initialization toolchain definitions"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//toolchains:tool_versions.bzl", "get_tool_info", "validate_tool_compatibility")
load("//toolchains:diagnostics.bzl", "format_diagnostic_error", "create_retry_wrapper")
load("//toolchains:tool_cache.bzl", "retrieve_cached_tool", "cache_tool", "validate_tool_functionality")

WIZER_VERSIONS = {
    "9.0.0": {
        "release_date": "2024-06-03",
        "cargo_install": True,  # Primary installation method
        "git_commit": "090082b", 
    },
    "8.0.0": {
        "release_date": "2024-02-28", 
        "cargo_install": True,
        "git_commit": "unknown",
    },
}

def _wizer_toolchain_impl(ctx):
    """Implementation of wizer_toolchain rule"""
    
    toolchain_info = platform_common.ToolchainInfo(
        wizer = ctx.file.wizer,
    )
    
    return [toolchain_info]

wizer_toolchain = rule(
    implementation = _wizer_toolchain_impl,
    attrs = {
        "wizer": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Wizer pre-initialization tool executable",
        ),
    },
)

def _wizer_toolchain_repository_impl(ctx):
    """Implementation of wizer_toolchain_repository repository rule"""
    
    version = ctx.attr.version
    strategy = ctx.attr.strategy
    
    if version not in WIZER_VERSIONS:
        fail("Unsupported Wizer version: {}. Supported versions: {}".format(
            version, list(WIZER_VERSIONS.keys())
        ))
    
    version_info = WIZER_VERSIONS[version]
    
    if strategy == "cargo":
        # Create a script that installs Wizer via Cargo
        ctx.file("install_wizer.sh", """#!/bin/bash
set -euo pipefail

WIZER_VERSION="{version}"
INSTALL_DIR="$PWD/bin"

# Ensure install directory exists
mkdir -p "$INSTALL_DIR"

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo "Error: cargo is required to install Wizer but is not available"
    echo "Please install Rust and Cargo, or use strategy='system'"
    exit 1
fi

# Install Wizer using cargo
echo "Installing Wizer v$WIZER_VERSION via cargo..."
cargo install wizer --version "=$WIZER_VERSION" --root . --all-features

# Verify installation
if [[ -f "$INSTALL_DIR/wizer" ]]; then
    echo "Successfully installed Wizer v$WIZER_VERSION"
    "$INSTALL_DIR/wizer" --version
else
    echo "Error: Wizer installation failed"
    exit 1
fi
""".format(version = version), executable = True)
        
        # Execute installation script
        result = ctx.execute(["./install_wizer.sh"])
        if result.return_code != 0:
            fail("Failed to install Wizer via cargo: {}".format(result.stderr))
            
        wizer_path = "bin/wizer"
        
    elif strategy == "system":
        # Check for system-installed Wizer using Bazel-native function
        wizer_path = ctx.which("wizer")
        if not wizer_path:
            fail("Wizer not found in system PATH. Install with 'cargo install wizer --all-features'")
        
        # Verify version if possible
        version_result = ctx.execute([wizer_path, "--version"])
        if version_result.return_code == 0:
            print("Found system Wizer: {}".format(version_result.stdout.strip()))
        
        # Create symlink for consistent access
        ctx.symlink(wizer_path, "bin/wizer")
        wizer_path = "bin/wizer"
        
    else:
        fail("Unsupported Wizer installation strategy: {}. Use 'cargo' or 'system'".format(strategy))
    
    # Create BUILD file for the toolchain
    ctx.file("BUILD.bazel", '''"""Wizer WebAssembly pre-initialization toolchain"""

load("//toolchains:wizer_toolchain.bzl", "wizer_toolchain")

package(default_visibility = ["//visibility:public"])

# Wizer executable
filegroup(
    name = "wizer_bin",
    srcs = ["{wizer_path}"],
)

# Wizer toolchain implementation
wizer_toolchain(
    name = "wizer_toolchain_impl",
    wizer = ":wizer_bin",
)

# Toolchain definition
toolchain(
    name = "wizer_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//os:macos", 
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:wasm32",
    ],
    toolchain = ":wizer_toolchain_impl",
    toolchain_type = "//toolchains:wizer_toolchain_type",
    visibility = ["//visibility:public"],
)
'''.format(wizer_path = wizer_path))

wizer_toolchain_repository = repository_rule(
    implementation = _wizer_toolchain_repository_impl,
    attrs = {
        "version": attr.string(
            default = "9.0.0",
            doc = "Wizer version to install",
        ),
        "strategy": attr.string(
            default = "cargo",
            values = ["cargo", "system"],
            doc = "Installation strategy: 'cargo' (install via cargo) or 'system' (use system install)",
        ),
    },
    doc = "Repository rule for setting up Wizer toolchain",
)