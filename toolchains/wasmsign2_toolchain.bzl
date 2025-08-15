"""WebAssembly signing toolchain using wasmsign2"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("//toolchains:tool_versions.bzl", "get_tool_info")
load("//checksums:registry.bzl", "get_tool_info")

def _get_wasmsign2_platform_info(platform, version):
    """Get platform info for wasmsign2 from centralized registry"""
    from_registry = get_tool_info("wasmsign2", version, platform)
    if not from_registry:
        fail("Unsupported platform {} for wasmsign2 version {}".format(platform, version))

    return struct(
        rust_target = from_registry.get("rust_target", ""),
        build_type = "rust_source",
    )

def _wasmsign2_toolchain_impl(ctx):
    """Implementation of wasmsign2_toolchain rule"""

    # Create toolchain info
    toolchain_info = platform_common.ToolchainInfo(
        wasmsign2 = ctx.file.wasmsign2,
    )

    return [toolchain_info]

wasmsign2_toolchain = rule(
    implementation = _wasmsign2_toolchain_impl,
    attrs = {
        "wasmsign2": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasmsign2 binary",
        ),
    },
    doc = "Toolchain rule for wasmsign2 WebAssembly signing tool",
)

def _wasmsign2_repository_impl(repository_ctx):
    """Implementation of wasmsign2_repository rule to build from source"""

    version = repository_ctx.attr.version
    platform = repository_ctx.attr.platform

    # Get platform info
    platform_info = _get_wasmsign2_platform_info(platform, version)
    rust_target = platform_info.rust_target

    # Clone the repository
    repository_ctx.execute([
        "git",
        "clone",
        "--depth",
        "1",
        "--branch",
        version,
        "https://github.com/wasm-signatures/wasmsign2.git",
        ".",
    ])

    # Build the binary
    if repository_ctx.os.name.lower().startswith("windows"):
        binary_name = "wasmsign2.exe"
    else:
        binary_name = "wasmsign2"

    # Create Cargo build command
    cargo_args = ["cargo", "build", "--release", "--bin", "wasmsign2"]
    if rust_target:
        cargo_args.extend(["--target", rust_target])

    build_result = repository_ctx.execute(cargo_args, environment = {
        "CARGO_NET_RETRY": "3",
    })

    if build_result.return_code != 0:
        fail("Failed to build wasmsign2: {}".format(build_result.stderr))

    # Determine binary path
    if rust_target:
        binary_src = "target/{}/release/{}".format(rust_target, binary_name)
    else:
        binary_src = "target/release/{}".format(binary_name)

    # Copy binary to expected location
    repository_ctx.execute(["cp", binary_src, binary_name])

    # Create BUILD file
    repository_ctx.file("BUILD.bazel", """
filegroup(
    name = "wasmsign2_files",
    srcs = ["{}"],
)

alias(
    name = "wasmsign2",
    actual = ":{}",
    visibility = ["//visibility:public"],
)
""".format(binary_name, binary_name))

wasmsign2_repository = repository_rule(
    implementation = _wasmsign2_repository_impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "Version of wasmsign2 to build",
        ),
        "platform": attr.string(
            mandatory = True,
            doc = "Target platform",
        ),
    },
    environ = [
        "CARGO_HOME",
        "RUSTUP_HOME",
        "PATH",
    ],
    doc = "Repository rule to build wasmsign2 from source",
)

def register_wasmsign2_toolchain(name = "wasmsign2", version = "0.2.6"):
    """Register wasmsign2 toolchain"""

    # Detect platform
    platform = select({
        "@platforms//os:macos": select({
            "@platforms//cpu:x86_64": "darwin_amd64",
            "@platforms//cpu:aarch64": "darwin_arm64",
        }),
        "@platforms//os:linux": select({
            "@platforms//cpu:x86_64": "linux_amd64",
            "@platforms//cpu:aarch64": "linux_arm64",
        }),
        "@platforms//os:windows": "windows_amd64",
    })

    # Create repository for building wasmsign2
    wasmsign2_repository(
        name = name + "_repo",
        version = version,
        platform = platform,
    )

    # Register toolchain
    native.register_toolchains("@{}_repo//:toolchain".format(name))
