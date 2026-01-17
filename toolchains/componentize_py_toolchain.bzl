"""componentize-py toolchain definitions for Python WebAssembly components

This toolchain provides the componentize-py tool from Bytecode Alliance
for building Python code into WebAssembly components.

componentize-py is a standalone Rust binary that:
- Bundles Python source with a WASM interpreter
- Generates WIT bindings automatically
- Produces WASI Preview 2 components

Usage:
    load("@rules_wasm_component//toolchains:componentize_py_toolchain.bzl",
         "componentize_py_toolchain_repository")

    componentize_py_toolchain_repository(name = "componentize_py_toolchain")
"""

load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:tool_registry.bzl", "tool_registry")

def _componentize_py_toolchain_impl(ctx):
    """Implementation of componentize_py_toolchain rule"""
    toolchain_info = platform_common.ToolchainInfo(
        componentize_py = ctx.file.componentize_py,
    )
    return [toolchain_info]

componentize_py_toolchain = rule(
    implementation = _componentize_py_toolchain_impl,
    attrs = {
        "componentize_py": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "componentize-py binary",
        ),
    },
    doc = "Declares a componentize-py toolchain for Python WebAssembly components",
)

def _componentize_py_toolchain_repository_impl(repository_ctx):
    """Create componentize-py toolchain repository"""

    platform = tool_registry.detect_platform(repository_ctx)
    bundle_name = repository_ctx.attr.bundle

    # Resolve version from bundle or use explicit version
    if bundle_name:
        version = get_version_for_tool(
            repository_ctx,
            "componentize-py",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.version,
        )
        log_bundle_usage(repository_ctx, "componentize-py", version, bundle_name)
    else:
        version = repository_ctx.attr.version

    # Download componentize-py using the unified tool registry
    _download_componentize_py(repository_ctx, platform, version)

    # Create BUILD files
    _create_build_files(repository_ctx)

def _download_componentize_py(repository_ctx, platform, version):
    """Download componentize-py binary using tool_registry"""

    # Use tool_registry for standardized download with checksum verification
    # tool_registry.download() returns a dict with binary_path, extract_dir, and tool_info
    # It will call fail() if download fails, so no need to check for success
    result = tool_registry.download(
        repository_ctx,
        "componentize-py",
        version,
        platform,
    )

    # The binary path is returned directly by tool_registry
    binary_path = result.get("binary_path", "")

    # Determine expected binary name
    binary_name = "componentize-py"
    if repository_ctx.os.name.lower().find("windows") != -1:
        binary_name = "componentize-py.exe"

    # If the binary was found in a subdirectory, symlink to root for consistency
    if binary_path and binary_path != binary_name:
        if repository_ctx.path(binary_path).exists:
            repository_ctx.symlink(binary_path, binary_name)
            repository_ctx.execute(["chmod", "+x", binary_name])
        else:
            # Try to find the binary manually
            debug_result = repository_ctx.execute(["find", ".", "-name", "*componentize*", "-type", "f"])
            fail("componentize-py binary not found at {}. Find result: {}".format(
                binary_path,
                debug_result.stdout,
            ))
    elif not repository_ctx.path(binary_name).exists:
        # Binary not at expected location, try to find it
        debug_result = repository_ctx.execute(["find", ".", "-name", "*componentize*", "-type", "f"])
        fail("componentize-py binary not found. Find result: {}".format(debug_result.stdout))

def _create_build_files(repository_ctx):
    """Create BUILD files for componentize-py toolchain"""

    binary_name = "componentize-py"
    if repository_ctx.os.name.lower().find("windows") != -1:
        binary_name = "componentize-py.exe"

    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:componentize_py_toolchain.bzl", "componentize_py_toolchain")

package(default_visibility = ["//visibility:public"])

# Binary target
filegroup(
    name = "componentize_py_binary",
    srcs = ["{binary_name}"],
    visibility = ["//visibility:public"],
)

# Toolchain implementation
componentize_py_toolchain(
    name = "componentize_py_toolchain_impl",
    componentize_py = ":componentize_py_binary",
)

# Toolchain registration
toolchain(
    name = "componentize_py_toolchain",
    toolchain = ":componentize_py_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:componentize_py_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)

# Alias for easy registration
alias(
    name = "all",
    actual = ":componentize_py_toolchain",
    visibility = ["//visibility:public"],
)
""".format(binary_name = binary_name))

componentize_py_toolchain_repository = repository_rule(
    implementation = _componentize_py_toolchain_repository_impl,
    attrs = {
        "bundle": attr.string(
            doc = "Toolchain bundle name. If set, version is read from checksums/toolchain_bundles.json",
            default = "",
        ),
        "version": attr.string(
            doc = "componentize-py version to use. Ignored if bundle is specified.",
            default = "canary",
        ),
    },
    doc = "Creates a componentize-py toolchain repository",
)
