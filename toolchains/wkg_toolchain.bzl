"""WebAssembly Package Tools (wkg) toolchain definitions"""

load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")

# Platform-specific wkg binary information
WKG_PLATFORMS = {
    "darwin_amd64": struct(
        url_suffix = "wkg-x86_64-apple-darwin",
        binary_name = "wkg-x86_64-apple-darwin",
    ),
    "darwin_arm64": struct(
        url_suffix = "wkg-aarch64-apple-darwin",
        binary_name = "wkg-aarch64-apple-darwin",
    ),
    "linux_amd64": struct(
        url_suffix = "wkg-x86_64-unknown-linux-gnu",
        binary_name = "wkg-x86_64-unknown-linux-gnu",
    ),
    "linux_arm64": struct(
        url_suffix = "wkg-aarch64-unknown-linux-gnu",
        binary_name = "wkg-aarch64-unknown-linux-gnu",
    ),
    "windows_amd64": struct(
        url_suffix = "wkg-x86_64-pc-windows-gnu",
        binary_name = "wkg-x86_64-pc-windows-gnu",
    ),
}

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

def _detect_platform(ctx):
    """Detect the current platform for tool downloads"""
    if ctx.os.name.startswith("mac"):
        if ctx.os.arch == "aarch64":
            return "darwin_arm64"
        else:
            return "darwin_amd64"
    elif ctx.os.name.startswith("linux"):
        if ctx.os.arch == "aarch64":
            return "linux_arm64"
        else:
            return "linux_amd64"
    elif ctx.os.name.startswith("windows"):
        return "windows_amd64"
    else:
        fail("Unsupported platform: {} {}".format(ctx.os.name, ctx.os.arch))

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
        platform = _detect_platform(ctx)
        platform_info = WKG_PLATFORMS[platform]

        # Construct download URL
        base_url = ctx.attr.url or "https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v{version}"
        url = base_url.format(version = version) + "/" + platform_info.url_suffix

        # Get the expected checksum for this platform and version (hardcoded from verified checksums)
        checksums = {
            "0.13.0": {
                "darwin_amd64": "6e9e260d45c8873d942ea5a1640692fdf01268c4b7906b48705dadaf1726a458",
                "darwin_arm64": "e8abc8195201fab2769a79ca3f831c3a7830714cd9508c3d1defff348942cbc6",
                "linux_amd64": "59bb3bce8a0f7d150ab57cef7743fddd7932772c4df71d09072ed83acb609323",
                "linux_arm64": "522d400dc919f026137c97a35bccc8a7b583aa29722a8cb4f470ff39de8161a0",
                "windows_amd64": "fdb964cc986578778543890b19c9e96d6b8f1cbb2c1c45a6dafcf542141a59a4",
            },
            "0.12.0": {
                "darwin_amd64": "15ea13c8fc1d2fe93fcae01f3bdb6da6049e3edfce6a6c6e7ce9d3c620a6defd",
                "darwin_arm64": "0048768e7046a5df7d8512c4c87c56cbf66fc12fa8805e8fe967ef2118230f6f",
                "linux_amd64": "444e568ce8c60364b9887301ab6862ef382ac661a4b46c2f0d2f0f254bd4e9d4",
                "linux_arm64": "ebd6ffba1467c16dba83058a38e894496247fc58112efd87d2673b40fc406652",
                "windows_amd64": "930adea31da8d2a572860304c00903f7683966e722591819e99e26787e58416b",
            },
            "0.11.0": {
                "darwin_amd64": "f1b6f71ce8b45e4fae0139f4676bc3efb48a89c320b5b2df1a1fd349963c5f82",
                "darwin_arm64": "e90a1092b1d1392052f93684afbd28a18fdf5f98d7175f565e49389e913d7cea",
                "linux_amd64": "e3bec9add5a739e99ee18503ace07d474ce185d3b552763785889b565cdcf9f2",
                "linux_arm64": "159ffe5d321217bf0f449f2d4bde9fe82fee2f9387b55615f3e4338eb0015e96",
                "windows_amd64": "ac7b06b91ea80973432d97c4facd78e84187e4d65b42613374a78c4c584f773c",
            },
        }

        expected_sha256 = checksums.get(version, {}).get(platform)
        if not expected_sha256:
            fail("No checksum found for wkg version {} platform {}".format(version, platform))

        # Download the binary directly (no extraction needed) with checksum verification
        ctx.download(
            url = url,
            output = platform_info.binary_name,
            executable = True,
            sha256 = expected_sha256,
        )

        # Use the downloaded binary
        wkg_binary = platform_info.binary_name

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
