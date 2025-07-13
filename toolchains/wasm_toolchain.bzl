"""WebAssembly toolchain definitions"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

WASM_TOOLS_PLATFORMS = {
    "darwin_amd64": struct(
        sha256 = "1234567890abcdef",  # TODO: Add real checksums
        url_suffix = "x86_64-macos.tar.gz",
    ),
    "darwin_arm64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "aarch64-macos.tar.gz",
    ),
    "linux_amd64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "x86_64-linux.tar.gz",
    ),
    "linux_arm64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "aarch64-linux.tar.gz",
    ),
    "windows_amd64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "x86_64-windows.tar.gz",
    ),
}

def _wasm_tools_toolchain_impl(ctx):
    """Implementation of wasm_tools_toolchain rule"""

    # Create toolchain info
    toolchain_info = platform_common.ToolchainInfo(
        wasm_tools = ctx.file.wasm_tools,
        wac = ctx.file.wac,
        wit_bindgen = ctx.file.wit_bindgen,
    )

    return [toolchain_info]

wasm_tools_toolchain = rule(
    implementation = _wasm_tools_toolchain_impl,
    attrs = {
        "wasm_tools": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-tools binary",
        ),
        "wac": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wac (WebAssembly Composition) binary",
        ),
        "wit_bindgen": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wit-bindgen binary",
        ),
    },
    doc = "Declares a WebAssembly toolchain",
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

def _wasm_toolchain_repository_impl(repository_ctx):
    """Create toolchain repository with configurable tool acquisition"""

    strategy = repository_ctx.attr.strategy

    if strategy == "system":
        _setup_system_tools(repository_ctx)
    elif strategy == "download":
        _setup_downloaded_tools(repository_ctx)
    elif strategy == "build":
        _setup_built_tools(repository_ctx)
    elif strategy == "hybrid":
        _setup_hybrid_tools(repository_ctx)
    else:
        fail("Unknown strategy: {}. Must be 'system', 'download', 'build', or 'hybrid'".format(strategy))

    # Create BUILD files for all strategies
    _create_build_files(repository_ctx)

def _setup_system_tools(repository_ctx):
    """Set up system-installed tools from PATH"""

    # Create wrapper executables that use system PATH
    repository_ctx.file("wasm-tools", """#!/bin/bash
exec wasm-tools "$@"
""", executable = True)

    repository_ctx.file("wac", """#!/bin/bash
exec wac "$@"
""", executable = True)

    repository_ctx.file("wit-bindgen", """#!/bin/bash
exec wit-bindgen "$@"
""", executable = True)

def _setup_downloaded_tools(repository_ctx):
    """Download prebuilt tools from GitHub releases"""

    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.version

    # Download wasm-tools
    wasm_tools_url = repository_ctx.attr.wasm_tools_url
    platform_suffix = _get_platform_suffix(platform)
    if not wasm_tools_url:
        wasm_tools_url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v{}/wasm-tools-{}-{}.tar.gz".format(
            version,
            version,
            platform_suffix,
        )

    repository_ctx.download_and_extract(
        url = wasm_tools_url,
        stripPrefix = "wasm-tools-{}-{}".format(version, platform_suffix),
    )

    # Download wac (binary release, not tarball)
    wac_url = repository_ctx.attr.wac_url
    if not wac_url:
        # wac has different version numbering and release format
        wac_version = "0.7.0"  # Latest stable version

        # Map platform suffixes to wac naming convention
        wac_platform_map = {
            "aarch64-macos": "aarch64-apple-darwin",
            "x86_64-macos": "x86_64-apple-darwin",
            "x86_64-linux": "x86_64-unknown-linux-musl",
            "aarch64-linux": "aarch64-unknown-linux-musl",
            "x86_64-windows": "x86_64-pc-windows-gnu",
        }
        wac_platform = wac_platform_map.get(platform_suffix, "x86_64-unknown-linux-musl")
        wac_url = "https://github.com/bytecodealliance/wac/releases/download/v{}/wac-cli-{}".format(
            wac_version,
            wac_platform,
        )

    # Download wac binary directly (not a tarball)
    repository_ctx.download(
        url = wac_url,
        output = "wac",
        executable = True,
    )

    # Download wit-bindgen (has different versioning)
    wit_bindgen_url = repository_ctx.attr.wit_bindgen_url
    if not wit_bindgen_url:
        # wit-bindgen has different version numbering than wasm-tools
        wit_bindgen_version = "0.43.0"  # Latest stable version
        wit_bindgen_url = "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{}/wit-bindgen-{}-{}.tar.gz".format(
            wit_bindgen_version,
            wit_bindgen_version,
            platform_suffix,
        )

    # Extract wit-bindgen version from URL for stripPrefix
    wit_bindgen_version_match = repository_ctx.execute(["bash", "-c", "echo '{}' | sed -n 's/.*wit-bindgen-\\([0-9\\.]*\\)-.*/\\1/p'".format(wit_bindgen_url)])
    wit_bindgen_version = wit_bindgen_version_match.stdout.strip() or "0.43.0"

    repository_ctx.download_and_extract(
        url = wit_bindgen_url,
        stripPrefix = "wit-bindgen-{}-{}".format(wit_bindgen_version, platform_suffix),
    )

def _setup_built_tools(repository_ctx):
    """Build tools from source code"""

    git_commit = repository_ctx.attr.git_commit

    # Get per-tool commits or use fallback
    wasm_tools_commit = repository_ctx.attr.wasm_tools_commit or git_commit
    wac_commit = repository_ctx.attr.wac_commit or git_commit
    wit_bindgen_commit = repository_ctx.attr.wit_bindgen_commit or git_commit

    # Get custom URLs or use defaults
    wasm_tools_url = repository_ctx.attr.wasm_tools_url or "https://github.com/bytecodealliance/wasm-tools.git"
    wac_url = repository_ctx.attr.wac_url or "https://github.com/bytecodealliance/wac.git"  
    wit_bindgen_url = repository_ctx.attr.wit_bindgen_url or "https://github.com/bytecodealliance/wit-bindgen.git"

    # Clone and build wasm-tools
    result = repository_ctx.execute([
        "git",
        "clone",
        wasm_tools_url,
        "wasm-tools-src",
    ])
    if result.return_code == 0:
        result = repository_ctx.execute([
            "git",
            "-C",
            "wasm-tools-src",
            "checkout",
            wasm_tools_commit,
        ])
    if result.return_code != 0:
        fail("Failed to clone wasm-tools from {}: {}".format(wasm_tools_url, result.stderr))

    result = repository_ctx.execute([
        "cargo",
        "build",
        "--release",
        "--manifest-path=wasm-tools-src/Cargo.toml",
    ])
    if result.return_code != 0:
        fail("Failed to build wasm-tools: {}".format(result.stderr))

    repository_ctx.execute([
        "cp",
        "wasm-tools-src/target/release/wasm-tools",
        "wasm-tools",
    ])

    # Clone and build wac
    result = repository_ctx.execute([
        "git",
        "clone",
        wac_url,
        "wac-src",
    ])
    if result.return_code == 0:
        result = repository_ctx.execute([
            "git",
            "-C",
            "wac-src",
            "checkout",
            wac_commit,
        ])
    if result.return_code != 0:
        fail("Failed to clone wac from {}: {}".format(wac_url, result.stderr))

    result = repository_ctx.execute([
        "cargo",
        "build",
        "--release",
        "--manifest-path=wac-src/Cargo.toml",
    ])
    if result.return_code != 0:
        fail("Failed to build wac: {}".format(result.stderr))

    repository_ctx.execute([
        "cp",
        "wac-src/target/release/wac",
        "wac",
    ])

    # Clone and build wit-bindgen
    result = repository_ctx.execute([
        "git",
        "clone",
        wit_bindgen_url,
        "wit-bindgen-src",
    ])
    if result.return_code == 0:
        result = repository_ctx.execute([
            "git",
            "-C",
            "wit-bindgen-src",
            "checkout",
            wit_bindgen_commit,
        ])
    if result.return_code != 0:
        fail("Failed to clone wit-bindgen from {}: {}".format(wit_bindgen_url, result.stderr))

    result = repository_ctx.execute([
        "cargo",
        "build",
        "--release",
        "--manifest-path=wit-bindgen-src/Cargo.toml",
    ])
    if result.return_code != 0:
        fail("Failed to build wit-bindgen: {}".format(result.stderr))

    repository_ctx.execute([
        "cp",
        "wit-bindgen-src/target/release/wit-bindgen",
        "wit-bindgen",
    ])

def _setup_hybrid_tools(repository_ctx):
    """Setup tools using hybrid build/download strategy"""
    
    # Determine which tools to build vs download based on custom URLs/commits
    build_wasm_tools = repository_ctx.attr.wasm_tools_url != "" or repository_ctx.attr.wasm_tools_commit != ""
    build_wac = repository_ctx.attr.wac_url != "" or repository_ctx.attr.wac_commit != ""
    build_wit_bindgen = repository_ctx.attr.wit_bindgen_url != "" or repository_ctx.attr.wit_bindgen_commit != ""
    
    # Get commits and URLs for tools we're building
    git_commit = repository_ctx.attr.git_commit
    wasm_tools_commit = repository_ctx.attr.wasm_tools_commit or git_commit
    wac_commit = repository_ctx.attr.wac_commit or git_commit
    wit_bindgen_commit = repository_ctx.attr.wit_bindgen_commit or git_commit
    
    wasm_tools_url = repository_ctx.attr.wasm_tools_url or "https://github.com/bytecodealliance/wasm-tools.git"
    wac_url = repository_ctx.attr.wac_url or "https://github.com/bytecodealliance/wac.git"
    wit_bindgen_url = repository_ctx.attr.wit_bindgen_url or "https://github.com/bytecodealliance/wit-bindgen.git"
    
    # Build or download wasm-tools
    if build_wasm_tools:
        result = repository_ctx.execute([
            "git", "clone", wasm_tools_url, "wasm-tools-src",
        ])
        if result.return_code == 0:
            result = repository_ctx.execute([
                "git", "-C", "wasm-tools-src", "checkout", wasm_tools_commit,
            ])
        if result.return_code != 0:
            fail("Failed to clone wasm-tools from {}: {}".format(wasm_tools_url, result.stderr))
        
        result = repository_ctx.execute([
            "cargo", "build", "--release", "--manifest-path=wasm-tools-src/Cargo.toml",
        ])
        if result.return_code != 0:
            fail("Failed to build wasm-tools: {}".format(result.stderr))
        
        repository_ctx.execute(["cp", "wasm-tools-src/target/release/wasm-tools", "wasm-tools"])
    else:
        _download_wasm_tools(repository_ctx)
    
    # Build or download wac
    if build_wac:
        result = repository_ctx.execute([
            "git", "clone", wac_url, "wac-src",
        ])
        if result.return_code == 0:
            result = repository_ctx.execute([
                "git", "-C", "wac-src", "checkout", wac_commit,
            ])
        if result.return_code != 0:
            fail("Failed to clone wac from {}: {}".format(wac_url, result.stderr))
        
        result = repository_ctx.execute([
            "cargo", "build", "--release", "--manifest-path=wac-src/Cargo.toml",
        ])
        if result.return_code != 0:
            fail("Failed to build wac: {}".format(result.stderr))
        
        repository_ctx.execute(["cp", "wac-src/target/release/wac", "wac"])
    else:
        _download_wac(repository_ctx)
    
    # Build or download wit-bindgen
    if build_wit_bindgen:
        result = repository_ctx.execute([
            "git", "clone", wit_bindgen_url, "wit-bindgen-src",
        ])
        if result.return_code == 0:
            result = repository_ctx.execute([
                "git", "-C", "wit-bindgen-src", "checkout", wit_bindgen_commit,
            ])
        if result.return_code != 0:
            fail("Failed to clone wit-bindgen from {}: {}".format(wit_bindgen_url, result.stderr))
        
        result = repository_ctx.execute([
            "cargo", "build", "--release", "--manifest-path=wit-bindgen-src/Cargo.toml",
        ])
        if result.return_code != 0:
            fail("Failed to build wit-bindgen: {}".format(result.stderr))
        
        repository_ctx.execute(["cp", "wit-bindgen-src/target/release/wit-bindgen", "wit-bindgen"])
    else:
        _download_wit_bindgen(repository_ctx)

def _download_wasm_tools(repository_ctx):
    """Download wasm-tools only"""
    platform = _detect_host_platform(repository_ctx)
    version = repository_ctx.attr.version
    platform_suffix = _get_platform_suffix(platform)
    
    wasm_tools_url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v{}/wasm-tools-{}-{}.tar.gz".format(
        version, version, platform_suffix,
    )
    
    repository_ctx.download_and_extract(
        url = wasm_tools_url,
        stripPrefix = "wasm-tools-{}-{}".format(version, platform_suffix),
    )

def _download_wac(repository_ctx):
    """Download wac only"""
    platform = _detect_host_platform(repository_ctx)
    platform_suffix = _get_platform_suffix(platform)
    
    wac_version = "0.7.0"
    wac_platform_map = {
        "aarch64-macos": "aarch64-apple-darwin",
        "x86_64-macos": "x86_64-apple-darwin", 
        "x86_64-linux": "x86_64-unknown-linux-musl",
        "aarch64-linux": "aarch64-unknown-linux-musl",
        "x86_64-windows": "x86_64-pc-windows-gnu",
    }
    wac_platform = wac_platform_map.get(platform_suffix, "x86_64-unknown-linux-musl")
    wac_url = "https://github.com/bytecodealliance/wac/releases/download/v{}/wac-cli-{}".format(
        wac_version, wac_platform,
    )
    
    repository_ctx.download(url = wac_url, output = "wac", executable = True)

def _download_wit_bindgen(repository_ctx):
    """Download wit-bindgen only"""
    platform = _detect_host_platform(repository_ctx)
    platform_suffix = _get_platform_suffix(platform)
    
    wit_bindgen_version = "0.43.0"
    wit_bindgen_url = "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{}/wit-bindgen-{}-{}.tar.gz".format(
        wit_bindgen_version, wit_bindgen_version, platform_suffix,
    )
    
    repository_ctx.download_and_extract(
        url = wit_bindgen_url,
        stripPrefix = "wit-bindgen-{}-{}".format(wit_bindgen_version, platform_suffix),
    )

def _get_platform_suffix(platform):
    """Get platform suffix for download URLs"""
    platform_suffixes = {
        "linux_amd64": "x86_64-linux",
        "linux_arm64": "aarch64-linux",
        "darwin_amd64": "x86_64-macos",
        "darwin_arm64": "aarch64-macos",
        "windows_amd64": "x86_64-windows",
    }
    return platform_suffixes.get(platform, "x86_64-linux")

def _create_build_files(repository_ctx):
    """Create BUILD files for the toolchain"""

    # Create main BUILD file
    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:wasm_toolchain.bzl", "wasm_tools_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for executables
filegroup(
    name = "wasm_tools_binary", 
    srcs = ["wasm-tools"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wac_binary",
    srcs = ["wac"], 
    visibility = ["//visibility:public"],
)

filegroup(
    name = "wit_bindgen_binary",
    srcs = ["wit-bindgen"],
    visibility = ["//visibility:public"],
)

# Toolchain implementation
wasm_tools_toolchain(
    name = "wasm_tools_impl",
    wasm_tools = ":wasm_tools_binary",
    wac = ":wac_binary", 
    wit_bindgen = ":wit_bindgen_binary",
)

# Toolchain registration
toolchain(
    name = "wasm_tools_toolchain",
    toolchain = ":wasm_tools_impl",
    toolchain_type = "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [],
)

# Alias for toolchain registration
alias(
    name = "all",
    actual = ":wasm_tools_toolchain",
    visibility = ["//visibility:public"],
)

# Note: Aliases removed to prevent dependency cycles
# Use the _binary targets directly: wasm_tools_binary, wac_binary, wit_bindgen_binary
""")

wasm_toolchain_repository = repository_rule(
    implementation = _wasm_toolchain_repository_impl,
    attrs = {
        "strategy": attr.string(
            doc = "Tool acquisition strategy: 'system', 'download', 'build', or 'hybrid'",
            default = "system",
            values = ["system", "download", "build", "hybrid"],
        ),
        "version": attr.string(
            doc = "Version to use (for download/build strategies)",
            default = "1.235.0",
        ),
        "git_commit": attr.string(
            doc = "Git commit/tag to build from (for build strategy) - fallback for all tools",
            default = "main",
        ),
        "wasm_tools_commit": attr.string(
            doc = "Git commit/tag for wasm-tools (overrides git_commit)",
            default = "",
        ),
        "wac_commit": attr.string(
            doc = "Git commit/tag for wac (overrides git_commit)",
            default = "",
        ),
        "wit_bindgen_commit": attr.string(
            doc = "Git commit/tag for wit-bindgen (overrides git_commit)",
            default = "",
        ),
        "wasm_tools_url": attr.string(
            doc = "Custom download URL for wasm-tools (optional)",
            default = "",
        ),
        "wac_url": attr.string(
            doc = "Custom download URL for wac (optional)",
            default = "",
        ),
        "wit_bindgen_url": attr.string(
            doc = "Custom download URL for wit-bindgen (optional)",
            default = "",
        ),
    },
)
