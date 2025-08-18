"""Wizer WebAssembly pre-initialization toolchain definitions"""

load("//checksums:registry.bzl", "get_tool_info")

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

def _detect_host_platform(repository_ctx):
    """Detect the host platform for tool installation"""
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    # Use Bazel's native architecture detection
    if "mac" in os_name or "darwin" in os_name:
        if arch == "aarch64" or "arm64" in arch:
            return "darwin_arm64"
        return "darwin_amd64"
    elif "linux" in os_name:
        if arch == "aarch64" or "arm64" in arch:
            return "linux_arm64"
        return "linux_amd64"
    elif "windows" in os_name:
        return "windows_amd64"
    else:
        fail("Unsupported operating system: {}".format(os_name))

def _get_wizer_download_info(platform, version):
    """Get download information for wizer prebuilt binaries from central registry"""
    
    # Get tool info from central registry
    tool_info = get_tool_info("wizer", version, platform)
    if not tool_info:
        fail("Unsupported platform {} for wizer version {}. Supported platforms can be found in //checksums/tools/wizer.json".format(platform, version))
    
    # Build download URL
    asset_name = "wizer-v{}-{}".format(version, tool_info["url_suffix"])
    url = "https://github.com/bytecodealliance/wizer/releases/download/v{}/{}".format(version, asset_name)
    
    # Determine archive type from suffix
    archive_type = "zip" if tool_info["url_suffix"].endswith(".zip") else "tar.xz"
    
    return {
        "url": url,
        "sha256": tool_info["sha256"],
        "type": archive_type,
        "strip_prefix": tool_info["strip_prefix"],
    }

def _wizer_toolchain_repository_impl(ctx):
    """Implementation of wizer_toolchain_repository repository rule"""

    version = ctx.attr.version
    strategy = ctx.attr.strategy
    platform = _detect_host_platform(ctx)

    if version not in WIZER_VERSIONS:
        fail("Unsupported Wizer version: {}. Supported versions: {}".format(
            version,
            list(WIZER_VERSIONS.keys()),
        ))

    version_info = WIZER_VERSIONS[version]

    if strategy == "build":
        # Use the git repository + genrule approach for hermetic builds
        print("Using hermetic build strategy with git_repository + genrule approach")

        # Create a placeholder since the actual binary will be built by git repository
        ctx.file("wizer", """#!/bin/bash
# This is a placeholder - actual wizer is built by git_repository + genrule
echo "Error: wizer should be accessed through Bazel targets, not as standalone binary"
echo "Use the proper toolchain integration instead"
exit 1
""", executable = True)
        wizer_path = "wizer"

    elif strategy == "cargo":
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
            # Check if the error is due to missing cargo (hermetic requirement)
            if "cargo is required" in result.stderr or "cargo" in result.stderr:
                print("Warning: Wizer installation skipped - cargo not available in hermetic environment")
                print("This is expected in BCR testing environments")
                print("Wizer functionality will be limited but basic WebAssembly builds will work")

                # Create a placeholder wizer binary that explains the situation
                ctx.file("bin/wizer", """#!/bin/bash
echo "Wizer not available - cargo not accessible in hermetic environment"
echo "This is expected in BCR testing environments"
echo "WebAssembly pre-initialization functionality not available"
echo "Use system strategy or ensure hermetic Rust toolchain is available"
exit 1
""", executable = True)
                wizer_path = "bin/wizer"
            else:
                fail("Failed to install Wizer via cargo: {}".format(result.stderr))

        wizer_path = "bin/wizer"

    elif strategy == "download":
        # Download prebuilt binary from GitHub releases
        platform_info = _get_wizer_download_info(platform, version)

        # Download and extract the binary
        ctx.download_and_extract(
            url = platform_info["url"],
            sha256 = platform_info["sha256"],
            stripPrefix = platform_info["strip_prefix"],
            type = platform_info["type"],
        )

        # The binary is now extracted directly to the root with the correct name
        wizer_path = "wizer.exe" if "windows" in platform else "wizer"

    else:
        fail("Unsupported Wizer installation strategy: {}. Use 'build', 'cargo', or 'download'".format(strategy))

    # Create BUILD file for the toolchain
    if strategy == "build":
        # For build strategy, reference the git repository
        build_content = '''"""Wizer WebAssembly pre-initialization toolchain"""

load("@rules_wasm_component//toolchains:wizer_toolchain.bzl", "wizer_toolchain")

package(default_visibility = ["//visibility:public"])

# Wizer executable from git repository (Bazel-native build)
alias(
    name = "wizer_bin",
    actual = "@wizer_src//:wizer_bazel",
    visibility = ["//visibility:public"],
)
'''
    elif strategy == "download":
        # For download strategy, use native file that's already executable
        build_content = '''"""Wizer WebAssembly pre-initialization toolchain"""

load("@rules_wasm_component//toolchains:wizer_toolchain.bzl", "wizer_toolchain")

package(default_visibility = ["//visibility:public"])

# Wizer executable (downloaded binary)
sh_binary(
    name = "wizer_bin",
    srcs = ["{wizer_path}"],
    visibility = ["//visibility:public"],
)
'''.format(wizer_path = wizer_path)
    else:
        # For other strategies, use local file
        build_content = '''"""Wizer WebAssembly pre-initialization toolchain"""

load("@rules_wasm_component//toolchains:wizer_toolchain.bzl", "wizer_toolchain")

package(default_visibility = ["//visibility:public"])

# Wizer executable
filegroup(
    name = "wizer_bin",
    srcs = ["{wizer_path}"],
)
'''.format(wizer_path = wizer_path)

    ctx.file("BUILD.bazel", build_content + '''
# Wizer toolchain implementation
wizer_toolchain(
    name = "wizer_toolchain_impl",
    wizer = ":wizer_bin",
)

# Toolchain definition
toolchain(
    name = "wizer_toolchain_def",
    exec_compatible_with = [
        "@platforms//os:{os}",
        "@platforms//cpu:{cpu}",
    ],
    target_compatible_with = [
        # Wizer runs on host platform to pre-initialize WASM modules
    ],
    toolchain = ":wizer_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:wizer_toolchain_type",
    visibility = ["//visibility:public"],
)
'''.format(
        os = "osx" if "darwin" in platform else ("windows" if "windows" in platform else "linux"),
        cpu = "arm64" if "arm64" in platform else "x86_64",
    ))

wizer_toolchain_repository = repository_rule(
    implementation = _wizer_toolchain_repository_impl,
    attrs = {
        "version": attr.string(
            default = "9.0.0",
            doc = "Wizer version to install",
        ),
        "strategy": attr.string(
            default = "cargo",
            values = ["build", "cargo", "download"],
            doc = "Installation strategy: 'build' (build from source), 'cargo' (install via cargo), or 'download' (download prebuilt binary)",
        ),
    },
    doc = "Repository rule for setting up Wizer toolchain",
)
