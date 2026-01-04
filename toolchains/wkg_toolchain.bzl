"""WebAssembly Package Tools (wkg) toolchain definitions"""

load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:tool_registry.bzl", "tool_registry")

def _wkg_toolchain_impl(ctx):
    """Implementation of wkg_toolchain rule"""

    toolchain_info = platform_common.ToolchainInfo(
        wkg = ctx.file.wkg,
    )

    return [toolchain_info]

wkg_toolchain = rule(
    implementation = _wkg_toolchain_impl,
    attrs = {
        "wkg": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wkg (WebAssembly Package Tools) binary",
        ),
    },
)

def _wkg_toolchain_repository_impl(ctx):
    """Repository rule implementation for wkg toolchain"""

    strategy = ctx.attr.strategy
    bundle_name = ctx.attr.bundle

    # Resolve version from bundle if specified, otherwise use explicit version
    if bundle_name:
        version = get_version_for_tool(
            ctx,
            "wkg",
            bundle_name = bundle_name,
            fallback_version = ctx.attr.version,
        )
        log_bundle_usage(ctx, "wkg", version, bundle_name)
    else:
        version = ctx.attr.version

    if strategy == "download":
        # Use unified tool registry for download
        platform = tool_registry.detect_platform(ctx)
        result = tool_registry.download(ctx, "wkg", version, platform, output_name = "wkg")
        wkg_binary = result["binary_path"]

        ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:wkg_toolchain.bzl", "wkg_toolchain")

wkg_toolchain(
    name = "wkg_toolchain",
    wkg = "{wkg_binary}",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "wkg_toolchain_def",
    toolchain = ":wkg_toolchain",
    toolchain_type = "@rules_wasm_component//toolchains:wkg_toolchain_type",
    visibility = ["//visibility:public"],
)
""".format(wkg_binary = wkg_binary))

    elif strategy == "build":
        # Build from source using git
        git_url = ctx.attr.git_url or "https://github.com/bytecodealliance/wasm-pkg-tools.git"
        git_commit = ctx.attr.git_commit or "main"

        # Clone the repository
        ctx.download_and_extract(
            url = "{}/archive/{}.tar.gz".format(git_url.rstrip(".git"), git_commit),
            stripPrefix = "wasm-pkg-tools-{}".format(git_commit),
        )

        # Build with cargo
        result = ctx.execute([
            "cargo",
            "build",
            "--release",
            "--bin",
            "wkg",
        ])
        if result.return_code != 0:
            fail("Failed to build wkg: {}".format(result.stderr))

        # Copy the binary using Bazel-native operations
        ctx.symlink("target/release/wkg", "wkg")

        ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:wkg_toolchain.bzl", "wkg_toolchain")

wkg_toolchain(
    name = "wkg_toolchain",
    wkg = "wkg",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "wkg_toolchain_def",
    toolchain = ":wkg_toolchain",
    toolchain_type = "@rules_wasm_component//toolchains:wkg_toolchain_type",
    visibility = ["//visibility:public"],
)
""")

    elif strategy == "source":
        # Use git_repository approach (modernized)
        ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:wkg_toolchain.bzl", "wkg_toolchain")

wkg_toolchain(
    name = "wkg_toolchain",
    wkg = "@wkg_src//:wkg",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "wkg_toolchain_def",
    toolchain = ":wkg_toolchain",
    toolchain_type = "@rules_wasm_component//toolchains:wkg_toolchain_type",
    visibility = ["//visibility:public"],
)
""")

    else:
        fail("Unknown strategy: {}. Supported: download, build, source".format(strategy))

wkg_toolchain_repository = repository_rule(
    implementation = _wkg_toolchain_repository_impl,
    attrs = {
        "bundle": attr.string(
            doc = "Toolchain bundle name. If set, version is read from checksums/toolchain_bundles.json",
            default = "",
        ),
        "strategy": attr.string(
            doc = "Tool acquisition strategy: 'download', 'build', or 'source'",
            default = "download",
            values = ["download", "build", "source"],
        ),
        "version": attr.string(
            doc = "Version to download/build. Ignored if bundle is specified.",
            default = "0.11.0",
        ),
        "url": attr.string(
            doc = "Custom base URL for downloads (optional)",
        ),
        "git_url": attr.string(
            doc = "Git repository URL for build strategy (optional)",
        ),
        "git_commit": attr.string(
            doc = "Git commit/tag to build from (optional)",
        ),
    },
    local = True,
)
