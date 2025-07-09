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
    """C++ toolchain config for WASM using WASI SDK"""

    # Get WASI SDK from toolchain if available
    wasi_sdk_toolchain_type = "@rules_wasm_component//toolchains:wasi_sdk_toolchain_type"
    wasi_sdk = ctx.toolchains[wasi_sdk_toolchain_type] if wasi_sdk_toolchain_type in ctx.toolchains else None
    
    # Use WASI SDK toolchain to get tool paths
    if wasi_sdk:
        # Use the actual downloaded WASI SDK tools
        # For C++ toolchains, we need to use the executable path
        # The toolchain resolution provides the actual executable files
        clang_path = wasi_sdk.clang.path
        ar_path = wasi_sdk.ar.path
        ld_path = wasi_sdk.ld.path
        nm_path = wasi_sdk.nm.path
        objdump_path = wasi_sdk.objdump.path
        strip_path = wasi_sdk.strip.path
        sysroot_path = wasi_sdk.sysroot
    else:
        # Fallback to hardcoded paths for development
        wasi_sdk_path = "/usr/local/wasi-sdk/bin"
        clang_path = wasi_sdk_path + "/clang"
        ar_path = wasi_sdk_path + "/ar"
        ld_path = wasi_sdk_path + "/wasm-ld"
        nm_path = wasi_sdk_path + "/llvm-nm"
        objdump_path = wasi_sdk_path + "/llvm-objdump"
        strip_path = wasi_sdk_path + "/llvm-strip"
        sysroot_path = "/usr/local/wasi-sdk/share/wasi-sysroot"
    
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
                        ],
                    ),
                ],
            ),
        ],
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        cxx_builtin_include_directories = [
            sysroot_path + "/include",
            sysroot_path + "/../lib/clang/19/include",
        ],
        toolchain_identifier = "wasm-toolchain",
        host_system_name = "local",
        target_system_name = "wasm32-wasi",
        target_cpu = "wasm32",
        target_libc = "wasi",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        tool_paths = tool_paths,
        features = [default_compile_flags_feature, default_link_flags_feature],
    )

wasm_cc_toolchain_config = rule(
    implementation = _wasm_cc_toolchain_config_impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
    toolchains = [
        config_common.toolchain_type("@rules_wasm_component//toolchains:wasi_sdk_toolchain_type", mandatory = False),
    ],
)
