"""Wasmtime toolchain definitions for WebAssembly component runtime"""

load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:tool_registry.bzl", "tool_registry")

def _wasmtime_toolchain_impl(ctx):
    """Implementation of wasmtime_toolchain rule"""

    toolchain_info = platform_common.ToolchainInfo(
        wasmtime = ctx.file.wasmtime,
    )

    return [toolchain_info]

wasmtime_toolchain = rule(
    implementation = _wasmtime_toolchain_impl,
    attrs = {
        "wasmtime": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasmtime binary",
        ),
    },
    doc = "Declares a Wasmtime WebAssembly runtime toolchain",
)

def _wasmtime_repository_impl(repository_ctx):
    """Create wasmtime repository with downloadable binary"""

    strategy = repository_ctx.attr.strategy
    platform = tool_registry.detect_platform(repository_ctx)
    bundle_name = repository_ctx.attr.bundle

    # Resolve version from bundle if specified, otherwise use explicit version
    if bundle_name:
        version = get_version_for_tool(
            repository_ctx,
            "wasmtime",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.version,
        )
        log_bundle_usage(repository_ctx, "wasmtime", version, bundle_name)
    else:
        version = repository_ctx.attr.version

    print("Setting up wasmtime {} for platform {} using strategy {}".format(
        version,
        platform,
        strategy,
    ))

    if strategy == "download":
        # Use unified tool registry for download
        tool_registry.download(repository_ctx, "wasmtime", version, platform, output_name = "wasmtime")
    else:
        fail("Unknown strategy: {}. Must be 'download'".format(strategy))

    # Create BUILD file
    repository_ctx.file("BUILD.bazel", '''"""Wasmtime toolchain repository"""

load("@rules_wasm_component//toolchains:wasmtime_toolchain.bzl", "wasmtime_toolchain")

package(default_visibility = ["//visibility:public"])

wasmtime_toolchain(
    name = "wasmtime_toolchain_impl",
    wasmtime = ":wasmtime",
)

toolchain(
    name = "wasmtime_toolchain",
    exec_compatible_with = [],
    target_compatible_with = [],
    toolchain = ":wasmtime_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:wasmtime_toolchain_type",
)
''')

wasmtime_repository = repository_rule(
    implementation = _wasmtime_repository_impl,
    attrs = {
        "bundle": attr.string(
            doc = "Toolchain bundle name. If set, version is read from checksums/toolchain_bundles.json",
            default = "",
        ),
        "strategy": attr.string(
            doc = "Installation strategy: 'download'",
            default = "download",
        ),
        "version": attr.string(
            doc = "Wasmtime version to install. Ignored if bundle is specified.",
            default = "39.0.1",  # Latest version with integrated wizer support
        ),
    },
    doc = "Repository rule for setting up Wasmtime WebAssembly runtime",
)
