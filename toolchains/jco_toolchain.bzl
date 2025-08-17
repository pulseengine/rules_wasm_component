"""jco (JavaScript Component Tools) toolchain definitions"""

load("//toolchains:diagnostics.bzl", "format_diagnostic_error", "validate_system_tool")
load("//toolchains:tool_cache.bzl", "cache_tool", "retrieve_cached_tool", "validate_tool_functionality")
load("//checksums:registry.bzl", "get_tool_info")

def _get_nodejs_toolchain_info(repository_ctx):
    """Get Node.js toolchain info from the registered hermetic toolchain"""

    # In MODULE.bazel mode with rules_nodejs, we need to access the hermetic binaries
    # The nodejs toolchain should make node and npm available through PATH

    # Try to find binaries through repository_ctx.which
    # This should work if the nodejs toolchain properly sets up the PATH
    node_binary = repository_ctx.which("node")
    npm_binary = repository_ctx.which("npm")

    if node_binary and npm_binary:
        return struct(
            node = str(node_binary),
            npm = str(npm_binary),
        )

    return None

def _jco_toolchain_impl(ctx):
    """Implementation of jco_toolchain rule"""

    # Create toolchain info
    toolchain_info = platform_common.ToolchainInfo(
        jco = ctx.file.jco,
        node = ctx.file.node,
        npm = ctx.file.npm,
    )

    return [toolchain_info]

jco_toolchain = rule(
    implementation = _jco_toolchain_impl,
    attrs = {
        "jco": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "jco binary",
        ),
        "node": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Node.js binary",
        ),
        "npm": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "npm binary",
        ),
    },
    doc = "Declares a jco (JavaScript Component Tools) toolchain",
)

def _detect_host_platform(repository_ctx):
    """Detect the host platform for jco"""

    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    if os_name == "mac os x":
        os_name = "darwin"

    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"

    return "{}_{}".format(os_name, arch)

def _jco_toolchain_repository_impl(repository_ctx):
    """Create jco toolchain repository"""

    platform = _detect_host_platform(repository_ctx)
    jco_version = repository_ctx.attr.version
    node_version = repository_ctx.attr.node_version

    # Always use download strategy with hermetic Node.js + jco
    _setup_downloaded_jco_tools(repository_ctx, platform, jco_version, node_version)

    # Create BUILD files
    _create_jco_build_files(repository_ctx)

def _setup_downloaded_jco_tools(repository_ctx, platform, jco_version, node_version):
    """Download hermetic Node.js and install jco via npm"""

    # Get Node.js info from registry
    node_info = get_tool_info("nodejs", node_version, platform)
    if not node_info:
        fail(format_diagnostic_error(
            "E001",
            "Unsupported platform {} for Node.js {}".format(platform, node_version),
            "Check //checksums/tools/nodejs.json for supported platforms",
        ))

    print("Setting up hermetic Node.js {} + jco {} for platform {}".format(
        node_version,
        jco_version,
        platform,
    ))

    # Download Node.js
    archive_name = "node-v{}-{}".format(node_version, node_info["url_suffix"])
    node_url = "https://nodejs.org/dist/v{}/{}".format(node_version, archive_name)

    print("Downloading Node.js from: {}".format(node_url))

    # Download and extract Node.js with SHA256 verification
    if archive_name.endswith(".tar.xz"):
        # For .tar.xz files (Linux)
        result = repository_ctx.download_and_extract(
            url = node_url,
            sha256 = node_info["sha256"],
            type = "tar.xz",
        )
    elif archive_name.endswith(".tar.gz"):
        # For .tar.gz files (macOS)
        result = repository_ctx.download_and_extract(
            url = node_url,
            sha256 = node_info["sha256"],
            type = "tar.gz",
        )
    elif archive_name.endswith(".zip"):
        # For .zip files (Windows)
        result = repository_ctx.download_and_extract(
            url = node_url,
            sha256 = node_info["sha256"],
            type = "zip",
        )
    else:
        fail("Unsupported Node.js archive format: {}".format(archive_name))

    if not result or (hasattr(result, "return_code") and result.return_code != 0):
        fail(format_diagnostic_error(
            "E003",
            "Failed to download Node.js {}".format(node_version),
            "Check network connectivity and Node.js version availability",
        ))

    # Get paths to Node.js binaries
    node_binary_path = node_info["binary_path"].format(node_version)
    npm_binary_path = node_info["npm_path"].format(node_version)

    # Verify Node.js installation
    node_binary = repository_ctx.path(node_binary_path)
    npm_binary = repository_ctx.path(npm_binary_path)

    if not node_binary.exists:
        fail("Node.js binary not found at: {}".format(node_binary_path))

    if not npm_binary.exists:
        fail("npm binary not found at: {}".format(npm_binary_path))

    # Test Node.js installation
    node_test = repository_ctx.execute([node_binary, "--version"])
    if node_test.return_code != 0:
        fail("Node.js installation test failed: {}".format(node_test.stderr))

    print("Successfully installed hermetic Node.js: {}".format(node_test.stdout.strip()))

    # Install jco using the hermetic npm
    print("Installing jco {} using hermetic npm...".format(jco_version))

    # Create a local node_modules for jco
    # Set up environment so npm can find node binary
    node_dir = str(node_binary.dirname)
    npm_env = {
        "PATH": node_dir + ":" + repository_ctx.os.environ.get("PATH", ""),
        "NODE_PATH": "",  # Clear any existing NODE_PATH
    }
    
    # Install platform-specific oxc-parser bindings first
    platform_binding = ""
    if platform == "linux_amd64":
        platform_binding = "@oxc-parser/binding-linux-x64-gnu"
    elif platform == "darwin_amd64":
        platform_binding = "@oxc-parser/binding-darwin-x64"
    elif platform == "darwin_arm64":
        platform_binding = "@oxc-parser/binding-darwin-arm64"
    elif platform == "windows_amd64":
        platform_binding = "@oxc-parser/binding-win32-x64-msvc"
    
    install_packages = [
        "@bytecodealliance/jco@{}".format(jco_version),
        "@bytecodealliance/componentize-js",  # Required dependency
    ]
    
    if platform_binding:
        install_packages.append(platform_binding)
        print("Installing platform-specific oxc-parser binding: {}".format(platform_binding))
    
    npm_install_result = repository_ctx.execute(
        [
            npm_binary,
            "install",
            "--prefix",
            "jco_workspace",
            "--force",  # Force reinstall to ensure platform-specific bindings
        ] + install_packages,
        environment = npm_env,
    )

    if npm_install_result.return_code != 0:
        fail(format_diagnostic_error(
            "E003",
            "Failed to install jco via hermetic npm: {}".format(npm_install_result.stderr),
            "Check jco version availability and network connectivity",
        ))

    print("Successfully installed jco via hermetic npm")
    
    # Try to rebuild native modules to ensure platform compatibility
    print("Rebuilding native modules for platform compatibility...")
    rebuild_result = repository_ctx.execute(
        [
            npm_binary,
            "rebuild",
            "--prefix",
            "jco_workspace",
        ],
        environment = npm_env,
    )
    
    if rebuild_result.return_code != 0:
        print("Warning: npm rebuild failed, but continuing: {}".format(rebuild_result.stderr))
    else:
        print("Successfully rebuilt native modules")

    # Create robust wrapper script for jco that always uses hermetic Node.js
    # Use npx with the jco package to ensure proper module resolution
    workspace_path = repository_ctx.path("jco_workspace").realpath

    # Verify jco was installed
    jco_package_path = repository_ctx.path("jco_workspace/node_modules/@bytecodealliance/jco/package.json")
    if not jco_package_path.exists:
        fail(format_diagnostic_error(
            "E004",
            "jco installation failed - package.json not found",
            "Check npm install output above for errors",
        ))

    print("jco installation verified, creating hermetic wrapper...")

    if platform.startswith("windows"):
        wrapper_content = """@echo off
set NODE_PATH={workspace}/node_modules
"{node}" "{workspace}/node_modules/@bytecodealliance/jco/src/jco.js" %*
""".format(
            node = node_binary.realpath,
            workspace = workspace_path,
        )
        repository_ctx.file("jco.cmd", wrapper_content, executable = True)
        repository_ctx.symlink("jco.cmd", "jco")
    else:
        wrapper_content = """#!/bin/bash
export NODE_PATH="{workspace}/node_modules"
exec "{node}" "{workspace}/node_modules/@bytecodealliance/jco/src/jco.js" "$@"
""".format(
            node = node_binary.realpath,
            workspace = workspace_path,
        )
        repository_ctx.file("jco", wrapper_content, executable = True)

    # Create symlinks for Node.js and npm binaries for the toolchain
    repository_ctx.symlink(node_binary, "node")
    repository_ctx.symlink(npm_binary, "npm")

    print("Hermetic jco toolchain setup complete")

def _create_jco_build_files(repository_ctx):
    """Create BUILD files for jco toolchain"""

    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:jco_toolchain.bzl", "jco_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for executables
filegroup(
    name = "jco_binary",
    srcs = ["jco"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "node_binary",
    srcs = ["node"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "npm_binary",
    srcs = ["npm"],
    visibility = ["//visibility:public"],
)

# Toolchain implementation
jco_toolchain(
    name = "jco_toolchain_impl",
    jco = ":jco_binary",
    node = ":node_binary",
    npm = ":npm_binary",
)

# Toolchain registration
toolchain(
    name = "jco_toolchain",
    toolchain = ":jco_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:jco_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)

# Alias for toolchain registration
alias(
    name = "all",
    actual = ":jco_toolchain",
    visibility = ["//visibility:public"],
)
""")

jco_toolchain_repository = repository_rule(
    implementation = _jco_toolchain_repository_impl,
    attrs = {
        "version": attr.string(
            doc = "jco version to use",
            default = "1.4.0",
        ),
        "node_version": attr.string(
            doc = "Node.js version to use for download strategy",
            default = "18.19.0",
        ),
    },
)
