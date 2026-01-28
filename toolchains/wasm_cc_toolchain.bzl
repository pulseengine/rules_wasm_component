"""Minimal C++ toolchain for WASM builds"""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "env_entry",
    "env_set",
    "feature",
    "flag_group",
    "flag_set",
    "tool_path",
)
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")

def _wasm_cc_toolchain_config_impl(ctx):
    """C++ toolchain config for WASM using WASI SDK"""

    # The tools are in the same repository as the cc_toolchain
    # When the cc_toolchain is in @wasi_sdk, these paths will be relative to that
    clang_path = "bin/clang"
    ar_path = "bin/ar"
    ld_path = "bin/wasm-ld"
    nm_path = "bin/llvm-nm"
    objdump_path = "bin/llvm-objdump"
    strip_path = "bin/llvm-strip"
    sysroot_path = "share/wasi-sysroot"

    tool_paths = [
        tool_path(
            name = "gcc",
            path = clang_path,
        ),
        tool_path(
            name = "ld",
            path = ld_path,
        ),
        tool_path(
            name = "ar",
            path = ar_path,
        ),
        tool_path(
            name = "cpp",
            path = clang_path,  # Use clang for C++ preprocessing
        ),
        tool_path(
            name = "gcov",
            path = "/usr/bin/true",  # Not needed for WASM
        ),
        tool_path(
            name = "nm",
            path = nm_path,
        ),
        tool_path(
            name = "objdump",
            path = objdump_path,
        ),
        tool_path(
            name = "strip",
            path = strip_path,
        ),
    ]

    # Define features with proper WASM flags
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
                            "-fno-rtti",
                            "-nostdlib",
                            "--sysroot=external/+wasi_sdk+wasi_sdk/share/wasi-sysroot",
                            # Use -isystem for WASI SDK includes to allow absolute paths
                            "-isystem",
                            "external/+wasi_sdk+wasi_sdk/share/wasi-sysroot/include",
                            "-isystem",
                            "external/+wasi_sdk+wasi_sdk/share/wasi-sysroot/include/wasm32-wasi",
                            "-isystem",
                            "external/+wasi_sdk+wasi_sdk/share/wasi-sysroot/include/wasm32-wasi/c++/v1",
                            "-isystem",
                            "external/+wasi_sdk+wasi_sdk/lib/clang/19/include",
                        ],
                    ),
                ],
            ),
        ],
    )

    # Add environment variables for Rust builds
    env_feature = feature(
        name = "env",
        enabled = True,
        env_sets = [
            env_set(
                actions = ["c_compile", "cpp_compile", "cpp_link_dynamic_library", "cpp_link_executable"],
                env_entries = [
                    env_entry(
                        key = "AR",
                        value = "external/+wasi_sdk+wasi_sdk/bin/ar",
                    ),
                    env_entry(
                        key = "CC",
                        value = "external/+wasi_sdk+wasi_sdk/bin/clang",
                    ),
                    env_entry(
                        key = "LD",
                        value = "external/+wasi_sdk+wasi_sdk/bin/wasm-ld",
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
                            "--sysroot=external/+wasi_sdk+wasi_sdk/share/wasi-sysroot",
                        ],
                    ),
                ],
            ),
        ],
    )

    # Disable layering check to allow absolute paths in system headers
    no_layering_check_feature = feature(
        name = "no_layering_check",
        enabled = True,
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        cxx_builtin_include_directories = [
            "external/+wasi_sdk+wasi_sdk/share/wasi-sysroot/include",
            "external/+wasi_sdk+wasi_sdk/share/wasi-sysroot/include/wasm32-wasi",
            "external/+wasi_sdk+wasi_sdk/share/wasi-sysroot/include/wasm32-wasi/c++/v1",
            "external/+wasi_sdk+wasi_sdk/lib/clang/19/include",
        ],
        builtin_sysroot = None,
        toolchain_identifier = "wasm-toolchain",
        host_system_name = "local",
        target_system_name = "wasm32-wasi",
        target_cpu = "wasm32",
        target_libc = "wasi",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
        features = [default_compile_flags_feature, default_link_flags_feature, env_feature, no_layering_check_feature],
    )

wasm_cc_toolchain_config = rule(
    implementation = _wasm_cc_toolchain_config_impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)
