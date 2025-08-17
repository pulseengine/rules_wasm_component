"""Wasmtime toolchain definitions for WebAssembly component runtime"""

load("//checksums:registry.bzl", "get_tool_info")

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

def _wasmtime_repository_impl(repository_ctx):
    """Create wasmtime repository with downloadable binary"""

    strategy = repository_ctx.attr.strategy
    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.version

    print("Setting up wasmtime {} for platform {} using strategy {}".format(
        version,
        platform,
        strategy,
    ))

    if strategy == "download":
        _setup_downloaded_wasmtime(repository_ctx, platform, version)
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

def _setup_downloaded_wasmtime(repository_ctx, platform, version):
    """Download prebuilt wasmtime binary"""

    # Get tool info from centralized registry
    tool_info = get_tool_info("wasmtime", version, platform)
    if not tool_info:
        fail("Unsupported platform {} for wasmtime version {}. Supported platforms can be found in //checksums/tools/wasmtime.json".format(platform, version))

    # Construct download URL
    url = "https://github.com/bytecodealliance/wasmtime/releases/download/v{}/wasmtime-v{}-{}".format(
        version,
        version,
        tool_info["url_suffix"],
    )

    print("Downloading wasmtime from: {}".format(url))

    # Download and extract
    if tool_info["url_suffix"].endswith(".tar.xz"):
        repository_ctx.download_and_extract(
            url = url,
            sha256 = tool_info["sha256"],
            stripPrefix = "wasmtime-v{}-{}".format(version, tool_info["url_suffix"].replace(".tar.xz", "")),
        )

        # Move binary to expected location (wasmtime archives contain the binary in root)
        if repository_ctx.path("wasmtime").exists:
            # Binary is already in the right place
            pass
        elif repository_ctx.path("wasmtime-{}".format(version)).exists:
            repository_ctx.symlink("wasmtime-{}".format(version), "wasmtime")
        else:
            # Look for the binary in common locations
            possible_paths = ["bin/wasmtime", "wasmtime/wasmtime"]
            found = False
            for path in possible_paths:
                if repository_ctx.path(path).exists:
                    repository_ctx.symlink(path, "wasmtime")
                    found = True
                    break
            if not found:
                fail("Could not find wasmtime binary after extraction")

    elif tool_info["url_suffix"].endswith(".zip"):
        repository_ctx.download_and_extract(
            url = url,
            sha256 = tool_info["sha256"],
            stripPrefix = "wasmtime-v{}-{}".format(version, tool_info["url_suffix"].replace(".zip", "")),
        )

        # For Windows, the binary might have .exe extension
        if repository_ctx.path("wasmtime.exe").exists:
            repository_ctx.symlink("wasmtime.exe", "wasmtime")
        elif repository_ctx.path("wasmtime").exists:
            # Already in the right place
            pass
        else:
            fail("Could not find wasmtime binary after extraction")

    # Validate the downloaded binary
    result = repository_ctx.execute(["./wasmtime", "--version"])
    if result.return_code != 0:
        fail("Downloaded wasmtime binary failed validation: {}".format(result.stderr))

    print("Successfully downloaded and validated wasmtime {}".format(version))

wasmtime_repository = repository_rule(
    implementation = _wasmtime_repository_impl,
    attrs = {
        "strategy": attr.string(
            doc = "Installation strategy: 'download'",
            default = "download",
        ),
        "version": attr.string(
            doc = "Wasmtime version to install",
            default = "35.0.0",  # Latest version from our registry
        ),
    },
    doc = "Repository rule for setting up Wasmtime WebAssembly runtime",
)
