"""Symmetric wit-bindgen toolchain for supporting both official and cpetig's fork"""

load("//toolchains:tool_cache.bzl", "cache_tool", "retrieve_cached_tool")
load("//toolchains:diagnostics.bzl", "format_diagnostic_error")

def _detect_host_platform(repository_ctx):
    """Detect the host platform"""
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    if os_name == "mac os x":
        os_name = "darwin"

    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"

    return "{}_{}".format(os_name, arch)

def _symmetric_wit_bindgen_toolchain_impl(ctx):
    """Implementation of symmetric wit-bindgen toolchain rule"""

    return [
        platform_common.ToolchainInfo(
            wit_bindgen_official = ctx.file.wit_bindgen_official,
            wit_bindgen_symmetric = ctx.file.wit_bindgen_symmetric,
        ),
    ]

symmetric_wit_bindgen_toolchain = rule(
    implementation = _symmetric_wit_bindgen_toolchain_impl,
    attrs = {
        "wit_bindgen_official": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Official wit-bindgen binary",
        ),
        "wit_bindgen_symmetric": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Symmetric wit-bindgen binary (cpetig's fork)",
        ),
    },
    doc = "Declares a symmetric wit-bindgen toolchain with both official and fork versions",
)

def _symmetric_wit_bindgen_repository_impl(repository_ctx):
    """Create repository with both official and symmetric wit-bindgen tools"""

    platform = _detect_host_platform(repository_ctx)
    print("Setting up symmetric wit-bindgen toolchain for platform: {}".format(platform))

    # Download official wit-bindgen
    _download_official_wit_bindgen(repository_ctx, platform)

    # Build cpetig's symmetric wit-bindgen fork
    _build_symmetric_wit_bindgen(repository_ctx)

    # Create BUILD file
    _create_symmetric_build_file(repository_ctx)

def _download_official_wit_bindgen(repository_ctx, platform):
    """Download official wit-bindgen from releases"""

    version = "0.43.0"

    # Platform suffix mapping
    platform_suffixes = {
        "linux_amd64": "x86_64-linux.tar.gz",
        "linux_arm64": "aarch64-linux.tar.gz",
        "darwin_amd64": "x86_64-macos.tar.gz",
        "darwin_arm64": "aarch64-macos.tar.gz",
        "windows_amd64": "x86_64-windows.tar.gz",
    }

    suffix = platform_suffixes.get(platform)
    if not suffix:
        fail("Unsupported platform {} for official wit-bindgen".format(platform))

    url = "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{}/wit-bindgen-{}-{}".format(
        version,
        version,
        suffix,
    )

    # For simplicity, use known checksums for common platforms
    # In production, this would come from a centralized registry
    checksums = {
        "linux_amd64": "a1b2c3d4e5f6",  # Placeholder - replace with actual checksums
        "darwin_amd64": "f6e5d4c3b2a1",
        "darwin_arm64": "b2a1f6e5d4c3",
    }

    checksum = checksums.get(platform, "")
    if not checksum:
        print("Warning: No checksum available for platform {}, skipping verification".format(platform))

    # Download and extract
    if checksum:
        repository_ctx.download_and_extract(
            url = url,
            sha256 = checksum,
            stripPrefix = "wit-bindgen-{}-{}".format(version, suffix.replace(".tar.gz", "")),
        )
    else:
        # Download without checksum verification (not recommended for production)
        repository_ctx.download_and_extract(
            url = url,
            stripPrefix = "wit-bindgen-{}-{}".format(version, suffix.replace(".tar.gz", "")),
        )

    # Move the extracted binary to expected location
    repository_ctx.symlink("wit-bindgen", "wit-bindgen-official")

def _build_symmetric_wit_bindgen(repository_ctx):
    """Build wit-bindgen from cpetig's symmetric fork"""

    # Clone cpetig's wit-bindgen fork
    result = repository_ctx.execute([
        "git",
        "clone",
        "--depth",
        "1",
        "--branch",
        "experimental",  # Use experimental branch that has symmetric features
        "https://github.com/cpetig/wit-bindgen.git",
        "wit-bindgen-symmetric-src",
    ])

    if result.return_code != 0:
        fail(format_diagnostic_error(
            "E003",
            "Failed to clone symmetric wit-bindgen fork: {}".format(result.stderr),
            "Check network connectivity and git installation",
        ))

    # Build wit-bindgen with symmetric features
    result = repository_ctx.execute([
        "cargo",
        "build",
        "--release",
        "--manifest-path=wit-bindgen-symmetric-src/Cargo.toml",
    ])

    if result.return_code != 0:
        fail(format_diagnostic_error(
            "E005",
            "Failed to build symmetric wit-bindgen: {}".format(result.stderr),
            "Ensure Rust toolchain is installed and try again",
        ))

    # Copy built binary
    repository_ctx.symlink(
        "wit-bindgen-symmetric-src/target/release/wit-bindgen",
        "wit-bindgen-symmetric",
    )

    print("Successfully built symmetric wit-bindgen from cpetig's fork")

def _create_symmetric_build_file(repository_ctx):
    """Create BUILD file for symmetric toolchain"""

    build_content = """
load("@rules_wasm_component//toolchains:symmetric_wit_bindgen_toolchain.bzl", "symmetric_wit_bindgen_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for both wit-bindgen versions
filegroup(
    name = "wit_bindgen_official_binary",
    srcs = ["wit-bindgen-official"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wit_bindgen_symmetric_binary",
    srcs = ["wit-bindgen-symmetric"],
    visibility = ["//visibility:public"],
)

# Symmetric toolchain implementation
symmetric_wit_bindgen_toolchain(
    name = "symmetric_wit_bindgen_impl",
    wit_bindgen_official = ":wit_bindgen_official_binary",
    wit_bindgen_symmetric = ":wit_bindgen_symmetric_binary",
)

# Toolchain registration
toolchain(
    name = "symmetric_wit_bindgen_toolchain",
    toolchain = ":symmetric_wit_bindgen_impl",
    toolchain_type = "@rules_wasm_component//toolchains:symmetric_wit_bindgen_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)
"""

    repository_ctx.file("BUILD.bazel", build_content)

symmetric_wit_bindgen_repository = repository_rule(
    implementation = _symmetric_wit_bindgen_repository_impl,
    attrs = {},
    doc = "Repository rule for symmetric wit-bindgen toolchain setup",
)
