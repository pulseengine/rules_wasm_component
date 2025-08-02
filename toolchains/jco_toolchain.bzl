"""jco (JavaScript Component Tools) toolchain definitions"""

load("//toolchains:tool_versions.bzl", "get_tool_info")
load("//toolchains:diagnostics.bzl", "format_diagnostic_error", "validate_system_tool")
load("//toolchains:tool_cache.bzl", "cache_tool", "retrieve_cached_tool", "validate_tool_functionality")

# jco platform mapping
JCO_PLATFORMS = {
    "darwin_amd64": {
        "binary_name": "jco-x86_64-apple-darwin",
        "sha256": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
    },
    "darwin_arm64": {
        "binary_name": "jco-aarch64-apple-darwin",
        "sha256": "c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4",
    },
    "linux_amd64": {
        "binary_name": "jco-x86_64-unknown-linux-musl",
        "sha256": "e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6",
    },
    "linux_arm64": {
        "binary_name": "jco-aarch64-unknown-linux-musl",
        "sha256": "a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8",
    },
    "windows_amd64": {
        "binary_name": "jco-x86_64-pc-windows-gnu.exe",
        "sha256": "c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0",
    },
}

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

    strategy = repository_ctx.attr.strategy
    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.version

    if strategy == "system":
        _setup_system_jco_tools(repository_ctx)
    elif strategy == "download":
        _setup_downloaded_jco_tools(repository_ctx, platform, version)
    elif strategy == "npm":
        _setup_npm_jco_tools(repository_ctx)
    else:
        fail(format_diagnostic_error(
            "E001",
            "Unknown jco strategy: {}".format(strategy),
            "Must be 'system', 'download', or 'npm'",
        ))

    # Create BUILD files
    _create_jco_build_files(repository_ctx)

def _setup_system_jco_tools(repository_ctx):
    """Set up system-installed jco tools"""

    # Validate system tools
    tools = [("jco", "jco"), ("node", "node"), ("npm", "npm")]

    for tool_name, binary_name in tools:
        validation_result = validate_system_tool(repository_ctx, binary_name)

        if not validation_result["valid"]:
            fail(validation_result["error"])

        if "warning" in validation_result:
            print(validation_result["warning"])

        # Create wrapper executable
        repository_ctx.file(tool_name, """#!/bin/bash
exec {} "$@"
""".format(binary_name), executable = True)

        print("Using system {}: {} at {}".format(
            tool_name,
            binary_name,
            validation_result.get("path", "system PATH"),
        ))

def _setup_downloaded_jco_tools(repository_ctx, platform, version):
    """Download prebuilt jco tools"""

    # Try to retrieve from cache first
    cached_jco = retrieve_cached_tool(repository_ctx, "jco", version, platform, "download")
    if not cached_jco:
        # Download jco binary
        if platform not in JCO_PLATFORMS:
            fail(format_diagnostic_error(
                "E001",
                "Unsupported platform {} for jco".format(platform),
                "Use 'npm' or 'system' strategy instead",
            ))

        platform_info = JCO_PLATFORMS[platform]
        binary_name = platform_info["binary_name"]

        # jco releases are available from GitHub
        jco_url = "https://github.com/bytecodealliance/jco/releases/download/v{}/{}".format(
            version,
            binary_name,
        )

        result = repository_ctx.download(
            url = jco_url,
            output = "jco",
            sha256 = platform_info["sha256"],
            executable = True,
        )
        if not result or (hasattr(result, "return_code") and result.return_code != 0):
            fail(format_diagnostic_error(
                "E003",
                "Failed to download jco",
                "Try 'npm' strategy: npm install -g @bytecodealliance/jco",
            ))

        # Validate downloaded tool
        validation_result = validate_tool_functionality(repository_ctx, "jco", "jco")
        if not validation_result["valid"]:
            fail(format_diagnostic_error(
                "E007",
                "Downloaded jco failed validation: {}".format(validation_result["error"]),
                "Try npm strategy or check platform compatibility",
            ))

        # Cache the tool
        tool_binary = repository_ctx.path("jco")
        cache_tool(repository_ctx, "jco", tool_binary, version, platform, "download", platform_info["sha256"])

    # Set up Node.js and npm (assume system installation)
    _setup_node_tools_system(repository_ctx)

def _setup_npm_jco_tools(repository_ctx):
    """Set up jco via npm installation"""

    # Check if npm is available
    npm_validation = validate_system_tool(repository_ctx, "npm")
    if not npm_validation["valid"]:
        fail(format_diagnostic_error(
            "E006",
            "npm not found for jco installation",
            "Install Node.js and npm, then try again",
        ))

    # Install jco and componentize-js globally via npm
    result = repository_ctx.execute([
        "npm",
        "install",
        "-g",
        "@bytecodealliance/jco@{}".format(repository_ctx.attr.version),
        "@bytecodealliance/componentize-js",
    ])

    if result.return_code != 0:
        fail(format_diagnostic_error(
            "E003",
            "Failed to install jco via npm: {}".format(result.stderr),
            "Check npm configuration and network connectivity",
        ))

    # Find the installed jco binary path
    jco_result = repository_ctx.execute(["which", "jco"])
    if jco_result.return_code != 0:
        fail(format_diagnostic_error(
            "E003",
            "jco binary not found after installation",
            "Check npm global installation path",
        ))

    jco_path = jco_result.stdout.strip()

    # Set up Node.js and npm first to get paths
    _setup_node_tools_system(repository_ctx)

    # Get Node.js path for JCO wrapper
    node_validation = validate_system_tool(repository_ctx, "node")
    node_path = node_validation.get("path", "node")

    # Create wrapper that uses Node.js to run JCO
    repository_ctx.file("jco", """#!/bin/bash
exec {} {} "$@"
""".format(node_path, jco_path), executable = True)

    print("Installed jco via npm globally")

def _setup_node_tools_system(repository_ctx):
    """Set up system Node.js and npm tools"""

    # Validate Node.js
    node_validation = validate_system_tool(repository_ctx, "node")
    if not node_validation["valid"]:
        fail(format_diagnostic_error(
            "E006",
            "Node.js not found",
            "Install Node.js to use JavaScript component features",
        ))

    # Validate npm
    npm_validation = validate_system_tool(repository_ctx, "npm")
    if not npm_validation["valid"]:
        fail(format_diagnostic_error(
            "E006",
            "npm not found",
            "Install npm (usually comes with Node.js)",
        ))

    # Get absolute paths to tools
    node_path = node_validation.get("path", "node")
    npm_path = npm_validation.get("path", "npm")

    # Create wrapper executables with absolute paths
    repository_ctx.file("node", """#!/bin/bash
exec {} "$@"
""".format(node_path), executable = True)

    repository_ctx.file("npm", """#!/bin/bash
exec {} "$@"
""".format(npm_path), executable = True)

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
        "strategy": attr.string(
            doc = "Tool acquisition strategy: 'system', 'download', or 'npm'",
            default = "system",
            values = ["system", "download", "npm"],
        ),
        "version": attr.string(
            doc = "jco version to use",
            default = "1.4.0",
        ),
    },
)
