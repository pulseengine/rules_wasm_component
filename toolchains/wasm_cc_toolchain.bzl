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
    
    # Use the label paths - let Bazel resolve them via the filegroup dependencies
    clang_file = ctx.attr._clang_file.files.to_list()[0]
    ar_file = ctx.attr._ar_file.files.to_list()[0]
    ld_file = ctx.attr._ld_file.files.to_list()[0]
    nm_file = ctx.attr._nm_file.files.to_list()[0]
    objdump_file = ctx.attr._objdump_file.files.to_list()[0]
    strip_file = ctx.attr._strip_file.files.to_list()[0]
    
    # Debug: clang_file.path = external/+wasi_sdk+wasi_sdk/bin/clang
    # Debug: clang_file.short_path = ../+wasi_sdk+wasi_sdk/bin/clang
    
    clang_path = clang_file.short_path.replace("../", "")
    ar_path = ar_file.short_path.replace("../", "")
    ld_path = ld_file.short_path.replace("../", "")
    nm_path = nm_file.short_path.replace("../", "")
    objdump_path = objdump_file.short_path.replace("../", "")
    strip_path = strip_file.short_path.replace("../", "")
    sysroot_path = "external/+wasi_sdk+wasi_sdk/share/wasi-sysroot"
    
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
    attrs = {
        "_clang_file": attr.label(
            default = "@wasi_sdk//:clang",
            allow_single_file = True,
        ),
        "_ar_file": attr.label(
            default = "@wasi_sdk//:ar",
            allow_single_file = True,
        ),
        "_ld_file": attr.label(
            default = "@wasi_sdk//:wasm_ld",
            allow_single_file = True,
        ),
        "_nm_file": attr.label(
            default = "@wasi_sdk//:llvm_nm",
            allow_single_file = True,
        ),
        "_objdump_file": attr.label(
            default = "@wasi_sdk//:llvm_objdump",
            allow_single_file = True,
        ),
        "_strip_file": attr.label(
            default = "@wasi_sdk//:llvm_strip",
            allow_single_file = True,
        ),
    },
    provides = [CcToolchainConfigInfo],
    toolchains = [
        config_common.toolchain_type("@rules_wasm_component//toolchains:wasi_sdk_toolchain_type", mandatory = False),
    ],
)
