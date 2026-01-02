"""jco (JavaScript Component Tools) toolchain definitions"""

load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:diagnostics.bzl", "format_diagnostic_error")
load("//toolchains:tool_registry.bzl", "tool_registry")

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

# Platform detection now uses tool_registry.detect_platform

def _jco_toolchain_repository_impl(repository_ctx):
    """Create jco toolchain repository"""

    platform = tool_registry.detect_platform(repository_ctx)
    bundle_name = repository_ctx.attr.bundle

    # Resolve versions from bundle if specified, otherwise use explicit versions
    if bundle_name:
        jco_version = get_version_for_tool(
            repository_ctx,
            "jco",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.version,
        )
        node_version = get_version_for_tool(
            repository_ctx,
            "nodejs",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.node_version,
        )
        log_bundle_usage(repository_ctx, "jco", jco_version, bundle_name)
        log_bundle_usage(repository_ctx, "nodejs", node_version, bundle_name)
    else:
        jco_version = repository_ctx.attr.version
        node_version = repository_ctx.attr.node_version

    # Always use download strategy with hermetic Node.js + jco
    _setup_downloaded_jco_tools(repository_ctx, platform, jco_version, node_version)

    # Create BUILD files
    _create_jco_build_files(repository_ctx)

def _setup_downloaded_jco_tools(repository_ctx, platform, jco_version, node_version):
    """Download hermetic Node.js and install jco via npm

    Uses tool_registry.download() for Node.js with:
    - SHA256 checksum verification from checksums/tools/nodejs.json
    - Enterprise mirror support (BAZEL_WASM_MIRROR)
    - Offline mode support (BAZEL_WASM_OFFLINE)

    npm registry can be configured via:
    - BAZEL_NPM_REGISTRY: Override npm registry URL (default: https://registry.npmjs.org)
    """

    print("Setting up hermetic Node.js {} + jco {} for platform {}".format(
        node_version,
        jco_version,
        platform,
    ))

    # Download Node.js via unified registry (with checksums + enterprise support!)
    node_result = tool_registry.download(
        repository_ctx,
        "nodejs",
        node_version,
        platform,
    )

    # Get paths from tool_info
    tool_info = node_result["tool_info"]
    if not tool_info:
        fail(format_diagnostic_error(
            "E001",
            "Unsupported platform {} for Node.js {}".format(platform, node_version),
            "Check //checksums/tools/nodejs.json for supported platforms",
        ))

    # Get paths to Node.js binaries
    node_binary_path = tool_info["binary_path"].format(node_version)
    npm_binary_path = tool_info["npm_path"].format(node_version)

    # Verify Node.js installation
    node_binary = repository_ctx.path(node_binary_path)
    npm_binary = repository_ctx.path(npm_binary_path)

    if not node_binary.exists:
        fail("Node.js binary not found at: {}".format(node_binary_path))

    if not npm_binary.exists:
        fail("npm binary not found at: {}".format(npm_binary_path))

    # Get npm registry configuration
    npm_registry = repository_ctx.os.environ.get("BAZEL_NPM_REGISTRY", "https://registry.npmjs.org")

    print("Node.js toolchain configured")

    # Install jco using the hermetic npm
    print("Installing jco {} using hermetic npm...".format(jco_version))

    # Configure npm to use custom registry if specified
    if npm_registry != "https://registry.npmjs.org":
        print("Configuring npm to use custom registry: {}".format(npm_registry))
        npmrc_content = "registry={}\n".format(npm_registry)
        repository_ctx.file("jco_workspace/.npmrc", npmrc_content)

    # Create a local node_modules for jco
    # Set up environment so npm can find node binary
    node_dir = str(node_binary.dirname)
    npm_env = {
        "PATH": node_dir + ":/usr/bin:/bin",  # Hermetic node + essential system tools (no WASI SDK)
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

    print("JCO dependencies configured")

    # Install packages with retry logic for transient registry failures
    max_retries = 3
    retry_delay_seconds = 5
    npm_install_result = None

    for attempt in range(1, max_retries + 1):
        if attempt > 1:
            print("Retrying npm install (attempt {}/{}) after {}s delay...".format(
                attempt, max_retries, retry_delay_seconds
            ))
            # Simple delay using execute with sleep
            repository_ctx.execute(["sleep", str(retry_delay_seconds)])
            retry_delay_seconds *= 2  # Exponential backoff

        npm_install_result = repository_ctx.execute([
            str(npm_binary),
            "install",
            "--global-style",
            "--no-package-lock",
        ] + install_packages, environment = npm_env, working_directory = "jco_workspace")

        if npm_install_result.return_code == 0:
            break

        print("npm install attempt {} failed (return code: {})".format(
            attempt, npm_install_result.return_code
        ))
        if attempt < max_retries:
            print("STDERR:", npm_install_result.stderr)

    if npm_install_result.return_code != 0:
        print("ERROR: npm install failed after {} attempts:".format(max_retries))
        print("STDOUT:", npm_install_result.stdout)
        print("STDERR:", npm_install_result.stderr)
        fail("Failed to install jco dependencies after {} retries: {}".format(
            max_retries, npm_install_result.stderr
        ))

    print("JCO installation completed successfully")

    # Create robust wrapper script for jco that always uses hermetic Node.js
    workspace_path = repository_ctx.path("jco_workspace").realpath

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

    # Create wrapper script for npm (similar to jco) because npm is a node script
    if platform.startswith("windows"):
        npm_wrapper_content = """@echo off
"{node}" "{npm}" %*
""".format(
            node = node_binary.realpath,
            npm = npm_binary.realpath,
        )
        repository_ctx.file("npm_wrapper.cmd", npm_wrapper_content, executable = True)
        repository_ctx.symlink("npm_wrapper.cmd", "npm_wrapper")
    else:
        npm_wrapper_content = """#!/bin/bash
exec "{node}" "{npm}" "$@"
""".format(
            node = node_binary.realpath,
            npm = npm_binary.realpath,
        )
        repository_ctx.file("npm_wrapper", npm_wrapper_content, executable = True)

    # Create symlinks for Node.js binary and use wrapper for npm
    repository_ctx.symlink(node_binary, "node")
    repository_ctx.symlink("npm_wrapper", "npm")

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
        "bundle": attr.string(
            doc = "Toolchain bundle name. If set, versions are read from checksums/toolchain_bundles.json",
            default = "",
        ),
        "version": attr.string(
            doc = "jco version to use. Ignored if bundle is specified.",
            default = "1.4.0",
        ),
        "node_version": attr.string(
            doc = "Node.js version to use for download strategy. Ignored if bundle is specified.",
            default = "18.19.0",
        ),
    },
)
