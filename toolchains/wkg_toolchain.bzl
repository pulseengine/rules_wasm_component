"""WebAssembly Package Tools (wkg) toolchain definitions"""

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
    version = ctx.attr.version

    if strategy == "download":
        platform = _detect_platform(ctx)
        platform_info = WKG_PLATFORMS[platform]

        # Construct download URL
        base_url = ctx.attr.url or "https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v{version}"
        url = base_url.format(version = version) + "/" + platform_info.url_suffix

        # Get the expected checksum for this platform and version (hardcoded from verified checksums)
        checksums = {
            "0.11.0": {
                "darwin_amd64": "f1b6f71ce8b45e4fae0139f4676bc3efb48a89c320b5b2df1a1fd349963c5f82",
                "darwin_arm64": "e90a1092b1d1392052f93684afbd28a18fdf5f98d7175f565e49389e913d7cea",
                "linux_amd64": "e3bec9add5a739e99ee18503ace07d474ce185d3b552763785889b565cdcf9f2",
                "linux_arm64": "159ffe5d321217bf0f449f2d4bde9fe82fee2f9387b55615f3e4338eb0015e96",
                "windows_amd64": "ac7b06b91ea80973432d97c4facd78e84187e4d65b42613374a78c4c584f773c",
            },
            "0.12.0": {
                "darwin_amd64": "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5",
                "darwin_arm64": "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5",
                "linux_amd64": "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5",
                "linux_arm64": "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5",
                "windows_amd64": "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5",
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

    else:
        fail("Unknown strategy: {}. Supported: download, build".format(strategy))

wkg_toolchain_repository = repository_rule(
    implementation = _wkg_toolchain_repository_impl,
    attrs = {
        "strategy": attr.string(
            doc = "Tool acquisition strategy: 'download' or 'build'",
            default = "download",
            values = ["download", "build"],
        ),
        "version": attr.string(
            doc = "Version to download/build",
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
