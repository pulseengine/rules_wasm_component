"""WASI SDK toolchain definitions"""

load("//checksums:registry.bzl", "get_tool_info")
load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:tool_registry.bzl", "tool_registry")

def _get_wasi_sdk_platform_info(platform, version):
    """Get platform info and checksum for WASI SDK from centralized registry"""
    from_registry = get_tool_info("wasi-sdk", version, platform)
    if not from_registry:
        fail("Unsupported platform {} for wasi-sdk version {}".format(platform, version))

    return struct(
        sha256 = from_registry["sha256"],
        url_suffix = from_registry["url_suffix"],
    )

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

# Platform detection now uses tool_registry.detect_platform

def _wasi_sdk_repository_impl(repository_ctx):
    """Create WASI SDK repository"""

    strategy = repository_ctx.attr.strategy

    if strategy == "download":
        _setup_downloaded_wasi_sdk(repository_ctx)
    else:
        fail("Unknown strategy: {}. Must be 'download'".format(strategy))

    # Create BUILD file
    _create_wasi_sdk_build_file(repository_ctx)

def _setup_downloaded_wasi_sdk(repository_ctx):
    """Download WASI SDK from GitHub releases"""

    bundle_name = repository_ctx.attr.bundle

    # Resolve version from bundle if specified, otherwise use explicit version
    if bundle_name:
        version = get_version_for_tool(
            repository_ctx,
            "wasi-sdk",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.version,
        )
        log_bundle_usage(repository_ctx, "wasi-sdk", version, bundle_name)
    else:
        version = repository_ctx.attr.version

    platform = tool_registry.detect_platform(repository_ctx)

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
            "windows_amd64": "x86_64-windows",
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

    # Get checksum from centralized registry
    platform_info = _get_wasi_sdk_platform_info(platform, version)

    # The archive contains the full version and platform in the prefix
    strip_prefix = "wasi-sdk-{}-{}".format(full_version, platform_suffix)

    repository_ctx.download_and_extract(
        url = url,
        sha256 = platform_info.sha256,
        stripPrefix = strip_prefix,
    )

    # No need for symlink, use direct paths in BUILD file

def _create_wasi_sdk_build_file(repository_ctx):
    """Create BUILD file for WASI SDK"""

    # Detect platform to determine binary extension
    platform = tool_registry.detect_platform(repository_ctx)
    is_windows = platform.startswith("windows_")
    exe_ext = ".exe" if is_windows else ""

    # Create a tools directory with proper symlinks for Rust builds
    # Note: Directory will be created automatically when symlinks are created

    # Create symlinks in the tools directory that Rust can find
    tools = [
        ("bin/ar" + exe_ext, "tools/ar" + exe_ext),
        ("bin/clang" + exe_ext, "tools/clang" + exe_ext),
        ("bin/clang++" + exe_ext, "tools/clang++" + exe_ext),
        ("bin/wasm-ld" + exe_ext, "tools/wasm-ld" + exe_ext),
        ("bin/llvm-nm" + exe_ext, "tools/llvm-nm" + exe_ext),
        ("bin/llvm-objdump" + exe_ext, "tools/llvm-objdump" + exe_ext),
        ("bin/llvm-strip" + exe_ext, "tools/llvm-strip" + exe_ext),
    ]

    for src, dst in tools:
        if repository_ctx.path(src).exists:
            repository_ctx.symlink(src, dst)

    build_content = '''
load("@rules_wasm_component//toolchains:wasi_sdk_toolchain.bzl", "wasi_sdk_toolchain")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load(":cc_toolchain_config.bzl", "wasm_cc_toolchain_config")

package(default_visibility = ["//visibility:public"])

# File targets for WASI SDK tools
filegroup(
    name = "clang",
    srcs = ["bin/clang{exe_ext}"],
)

filegroup(
    name = "ar",
    srcs = ["bin/ar{exe_ext}"],
)

filegroup(
    name = "wasm_ld",
    srcs = ["bin/wasm-ld{exe_ext}"],
)

filegroup(
    name = "llvm_nm",
    srcs = ["bin/llvm-nm{exe_ext}"],
)

filegroup(
    name = "llvm_objdump",
    srcs = ["bin/llvm-objdump{exe_ext}"],
)

filegroup(
    name = "llvm_strip",
    srcs = ["bin/llvm-strip{exe_ext}"],
)

filegroup(
    name = "sysroot",
    srcs = glob(["share/wasi-sysroot/**"], allow_empty = True),
)

filegroup(
    name = "clang_includes",
    srcs = glob(["lib/clang/*/include/**"], allow_empty = True),
)

# Tools directory for Rust builds
filegroup(
    name = "tools",
    srcs = glob(["tools/*"], allow_empty = True),
)

# All tools filegroup for cc_toolchain
filegroup(
    name = "all_tools",
    srcs = [
        ":clang",
        ":ar",
        ":wasm_ld",
        ":llvm_nm",
        ":llvm_objdump",
        ":llvm_strip",
        ":sysroot",
        ":clang_includes",
        ":tools",
    ],
)

# CC toolchain config
wasm_cc_toolchain_config(
    name = "wasm_cc_toolchain_config",
)

# CC toolchain
cc_toolchain(
    name = "wasm_cc_toolchain",
    all_files = ":all_tools",
    compiler_files = ":all_tools",
    dwp_files = ":all_tools",
    linker_files = ":all_tools",
    objcopy_files = ":all_tools",
    strip_files = ":all_tools",
    supports_param_files = False,
    toolchain_config = ":wasm_cc_toolchain_config",
    toolchain_identifier = "wasm-toolchain",
)

# CC toolchain registration
toolchain(
    name = "cc_toolchain",
    toolchain = ":wasm_cc_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    exec_compatible_with = [],
    target_compatible_with = [
        "@platforms//cpu:wasm32",
        "@platforms//os:wasi",
    ],
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

    # Replace exe_ext placeholder with actual extension using string replacement
    build_content = build_content.replace("{exe_ext}", exe_ext)
    repository_ctx.file("BUILD.bazel", build_content)

    # Create cc_toolchain_config.bzl with proper path resolution
    cc_config_content = '''
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "tool_path",
)

def _wasm_cc_toolchain_config_impl(ctx):
    """C++ toolchain config for WASM using WASI SDK"""

    tool_paths = [
        tool_path(name = "gcc", path = "bin/clang{exe_ext}"),
        tool_path(name = "ld", path = "bin/wasm-ld{exe_ext}"),
        tool_path(name = "ar", path = "bin/ar{exe_ext}"),
        tool_path(name = "cpp", path = "bin/clang{exe_ext}"),
        tool_path(name = "gcov", path = "/usr/bin/false"),
        tool_path(name = "nm", path = "bin/llvm-nm{exe_ext}"),
        tool_path(name = "objdump", path = "bin/llvm-objdump{exe_ext}"),
        tool_path(name = "strip", path = "bin/llvm-strip{exe_ext}"),
    ]

    default_compile_flags_feature = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = ["c_compile", "cpp_compile"],
                flag_groups = [
                    flag_group(
                        flags = [
                            "--target=wasm32-wasi",
                            "-fno-exceptions",
                            "-nostdlib",
                            "--sysroot", "share/wasi-sysroot",
                        ],
                    ),
                ],
            ),
        ],
    )

    default_link_flags_feature = feature(
        name = "default_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = ["cpp_link_dynamic_library", "cpp_link_executable"],
                flag_groups = [
                    flag_group(
                        flags = [
                            "--target=wasm32-wasi",
                            "-nostdlib",
                            "--sysroot", "share/wasi-sysroot",
                        ],
                    ),
                ],
            ),
        ],
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "wasm-toolchain",
        host_system_name = "local",
        target_system_name = "wasm32-wasi",
        target_cpu = "wasm32",
        target_libc = "wasi",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
        cxx_builtin_include_directories = [
            "share/wasi-sysroot/include",
            "share/wasi-sysroot/include/wasm32-wasi",
            "lib/clang/19/include",
        ],
        features = [default_compile_flags_feature, default_link_flags_feature],
    )

wasm_cc_toolchain_config = rule(
    implementation = _wasm_cc_toolchain_config_impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)
'''

    # Replace exe_ext placeholder with actual extension using string replacement
    cc_config_content = cc_config_content.replace("{exe_ext}", exe_ext)
    repository_ctx.file("cc_toolchain_config.bzl", cc_config_content)

wasi_sdk_repository = repository_rule(
    implementation = _wasi_sdk_repository_impl,
    attrs = {
        "bundle": attr.string(
            doc = "Toolchain bundle name. If set, version is read from checksums/toolchain_bundles.json",
            default = "",
        ),
        "strategy": attr.string(
            doc = "Strategy: 'download'",
            default = "download",
            values = ["download"],
        ),
        "version": attr.string(
            doc = "WASI SDK version. Ignored if bundle is specified.",
            default = "27",
        ),
        "url": attr.string(
            doc = "Custom download URL (optional)",
        ),
    },
)
