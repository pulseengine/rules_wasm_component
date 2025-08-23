"""File Operations Toolchain for universal file handling

This toolchain provides the File Operations Component for cross-platform
file operations in Bazel rules, replacing shell scripts.
"""

def _file_ops_toolchain_impl(ctx):
    """Implementation of file_ops_toolchain rule"""

    return [platform_common.ToolchainInfo(
        file_ops_component = ctx.executable.file_ops_component,
        file_ops_info = struct(
            component = ctx.executable.file_ops_component,
            wit_files = ctx.files.wit_files,
        ),
    )]

file_ops_toolchain = rule(
    implementation = _file_ops_toolchain_impl,
    attrs = {
        "file_ops_component": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            doc = "File Operations Component executable",
        ),
        "wit_files": attr.label_list(
            allow_files = [".wit"],
            doc = "WIT interface files for the component",
        ),
    },
    doc = "Defines a file operations toolchain for universal file handling",
)

def _file_ops_toolchain_repository_impl(repository_ctx):
    """Implementation of file_ops_toolchain_repository rule"""

    # Create BUILD file for the toolchain
    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:file_ops_toolchain.bzl", "file_ops_toolchain")

# File Operations Toolchain using built component
file_ops_toolchain(
    name = "file_ops_toolchain_impl",
    file_ops_component = "@rules_wasm_component//tools/file_ops:file_ops",
    wit_files = ["@rules_wasm_component//tools/file_operations_component:wit_files"],
    visibility = ["//visibility:public"],
)

# Toolchain target
toolchain(
    name = "file_ops_toolchain",
    exec_compatible_with = [
        "@platforms//os:linux",
        "@platforms//os:macos",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:wasm32",
    ],
    toolchain = ":file_ops_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    visibility = ["//visibility:public"],
)

# Universal toolchain (works on all platforms)
toolchain(
    name = "file_ops_toolchain_universal",
    toolchain = ":file_ops_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:file_ops_toolchain_type",
    visibility = ["//visibility:public"],
)
""")

file_ops_toolchain_repository = repository_rule(
    implementation = _file_ops_toolchain_repository_impl,
    doc = "Creates a repository with file operations toolchain configuration",
)
