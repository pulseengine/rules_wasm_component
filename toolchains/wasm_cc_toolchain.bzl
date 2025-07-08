"""Minimal C++ toolchain for WASM builds"""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
    "tool_path",
    "with_feature_set",
)

def _wasm_cc_toolchain_config_impl(ctx):
    """Minimal C++ toolchain config for WASM that doesn't actually link"""

    # Define tool paths - these are dummy tools that won't actually be used
    tool_paths = [
        tool_path(
            name = "gcc",
            path = "/bin/true",  # Dummy path
        ),
        tool_path(
            name = "ld",
            path = "/bin/true",  # Dummy path
        ),
        tool_path(
            name = "ar",
            path = "/bin/true",  # Dummy path
        ),
        tool_path(
            name = "cpp",
            path = "/bin/true",  # Dummy path
        ),
        tool_path(
            name = "gcov",
            path = "/bin/true",  # Dummy path
        ),
        tool_path(
            name = "nm",
            path = "/bin/true",  # Dummy path
        ),
        tool_path(
            name = "objdump",
            path = "/bin/true",  # Dummy path
        ),
        tool_path(
            name = "strip",
            path = "/bin/true",  # Dummy path
        ),
    ]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        cxx_builtin_include_directories = [],
        toolchain_identifier = "wasm-toolchain",
        host_system_name = "local",
        target_system_name = "wasm",
        target_cpu = "wasm32",
        target_libc = "unknown",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
    )

wasm_cc_toolchain_config = rule(
    implementation = _wasm_cc_toolchain_config_impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)
