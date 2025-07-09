"""WASI SDK toolchain definitions"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

WASI_SDK_PLATFORMS = {
    "darwin_amd64": struct(
        sha256 = "1234567890abcdef",  # TODO: Add real checksums
        url_suffix = "darwin.tar.gz",
    ),
    "darwin_arm64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "darwin.tar.gz",
    ),
    "linux_amd64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "linux.tar.gz",
    ),
    "linux_arm64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "linux-arm64.tar.gz",
    ),
}

def _wasi_sdk_toolchain_impl(ctx):
    """Implementation of wasi_sdk_toolchain rule"""
    
    toolchain_info = platform_common.ToolchainInfo(
        wasi_sdk_root = ctx.attr.wasi_sdk_root,
        clang = ctx.file.clang,
        ar = ctx.file.ar,
        ld = ctx.file.ld,
        nm = ctx.file.nm,
        objdump = ctx.file.objdump,
        strip = ctx.file.strip,
        sysroot = ctx.attr.sysroot,
        clang_version = ctx.attr.clang_version,
    )
    
    return [toolchain_info]

wasi_sdk_toolchain = rule(
    implementation = _wasi_sdk_toolchain_impl,
    attrs = {
        "wasi_sdk_root": attr.label(
            doc = "Root directory of WASI SDK",
        ),
        "clang": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "clang compiler",
        ),
        "ar": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "ar archiver",
        ),
        "ld": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-ld linker",
        ),
        "nm": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "llvm-nm",
        ),
        "objdump": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "llvm-objdump",
        ),
        "strip": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "llvm-strip",
        ),
        "sysroot": attr.string(
            doc = "Path to WASI sysroot",
        ),
        "clang_version": attr.string(
            doc = "Clang version number",
            default = "19",
        ),
    },
    doc = "Declares a WASI SDK toolchain",
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

def _wasi_sdk_repository_impl(repository_ctx):
    """Create WASI SDK repository"""
    
    strategy = repository_ctx.attr.strategy
    
    if strategy == "system":
        _setup_system_wasi_sdk(repository_ctx)
    elif strategy == "download":
        _setup_downloaded_wasi_sdk(repository_ctx)
    else:
        fail("Unknown strategy: {}. Must be 'system' or 'download'".format(strategy))
    
    # Create BUILD file
    _create_wasi_sdk_build_file(repository_ctx)

def _setup_system_wasi_sdk(repository_ctx):
    """Use system-installed WASI SDK"""
    
    # Default to /usr/local/wasi-sdk
    wasi_sdk_root = repository_ctx.attr.wasi_sdk_root or "/usr/local/wasi-sdk"
    
    # Create symlinks to system tools
    repository_ctx.symlink(wasi_sdk_root, "wasi-sdk")

def _setup_downloaded_wasi_sdk(repository_ctx):
    """Download WASI SDK from GitHub releases"""
    
    version = repository_ctx.attr.version
    platform = _detect_host_platform(repository_ctx)
    
    # Download WASI SDK
    url = repository_ctx.attr.url
    if not url:
        # WASI SDK URL format: wasi-sdk-{VERSION.0}-{ARCH}-{OS}.tar.gz
        # Convert platform format from "darwin_arm64" to "arm64-macos"
        platform_mapping = {
            "darwin_amd64": "x86_64-macos",
            "darwin_arm64": "arm64-macos", 
            "linux_amd64": "x86_64-linux",
            "linux_arm64": "arm64-linux",
            "windows_amd64": "x86_64-mingw",
        }
        
        if platform not in platform_mapping:
            fail("Unsupported platform: {}. Supported: {}".format(platform, platform_mapping.keys()))
        
        platform_suffix = platform_mapping[platform]
        full_version = version + ".0" if "." not in version else version
        
        url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-{}/wasi-sdk-{}-{}.tar.gz".format(
            version,
            full_version,
            platform_suffix,
        )
    
    # The archive contains the full version and platform in the prefix
    strip_prefix = "wasi-sdk-{}-{}".format(full_version, platform_suffix)
    
    repository_ctx.download_and_extract(
        url = url,
        stripPrefix = strip_prefix,
    )
    
    # No need for symlink, use direct paths in BUILD file

def _create_wasi_sdk_build_file(repository_ctx):
    """Create BUILD file for WASI SDK"""
    
    build_content = '''
load("@rules_wasm_component//toolchains:wasi_sdk_toolchain.bzl", "wasi_sdk_toolchain")

package(default_visibility = ["//visibility:public"])

# File targets for WASI SDK tools
filegroup(
    name = "clang",
    srcs = ["bin/clang"],
)

filegroup(
    name = "ar",
    srcs = ["bin/ar"],
)

filegroup(
    name = "wasm_ld",
    srcs = ["bin/wasm-ld"],
)

filegroup(
    name = "llvm_nm",
    srcs = ["bin/llvm-nm"],
)

filegroup(
    name = "llvm_objdump",
    srcs = ["bin/llvm-objdump"],
)

filegroup(
    name = "llvm_strip",
    srcs = ["bin/llvm-strip"],
)

filegroup(
    name = "sysroot",
    srcs = glob(["share/wasi-sysroot/**"], allow_empty = True),
)

filegroup(
    name = "clang_includes",
    srcs = glob(["lib/clang/*/include/**"], allow_empty = True),
)

# WASI SDK toolchain
wasi_sdk_toolchain(
    name = "wasi_sdk_impl",
    wasi_sdk_root = ":sysroot",
    clang = ":clang",
    ar = ":ar", 
    ld = ":wasm_ld",
    nm = ":llvm_nm",
    objdump = ":llvm_objdump",
    strip = ":llvm_strip",
    sysroot = "share/wasi-sysroot",
    clang_version = "19",
)

# Toolchain registration
toolchain(
    name = "wasi_sdk_toolchain",
    toolchain = ":wasi_sdk_impl",
    toolchain_type = "@rules_wasm_component//toolchains:wasi_sdk_toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [
        "@platforms//cpu:wasm32",
        "@platforms//os:wasi",
    ],
)

# Alias for registration
alias(
    name = "all",
    actual = ":wasi_sdk_toolchain",
)
'''
    
    repository_ctx.file("BUILD.bazel", build_content)

wasi_sdk_repository = repository_rule(
    implementation = _wasi_sdk_repository_impl,
    attrs = {
        "strategy": attr.string(
            doc = "Strategy: 'system' or 'download'",
            default = "system",
            values = ["system", "download"],
        ),
        "version": attr.string(
            doc = "WASI SDK version",
            default = "22",
        ),
        "url": attr.string(
            doc = "Custom download URL (optional)",
        ),
        "wasi_sdk_root": attr.string(
            doc = "Path to system WASI SDK (for 'system' strategy)",
        ),
    },
)