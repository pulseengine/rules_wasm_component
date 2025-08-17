"""WASI WIT interface dependencies for WebAssembly components

This file provides Bazel-native http_archive rules for WASI WIT definitions,
following the Bazel-first approach instead of using shell scripts or wit-deps tool.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def wasi_wit_dependencies():
    """Load WASI WIT interface definitions as Bazel external dependencies.

    This follows the Bazel-native approach by using http_archive rules
    instead of shell scripts or external dependency management tools.
    """

    # WASI IO interfaces (includes streams, error, poll)
    http_archive(
        name = "wasi_io",
        urls = ["https://github.com/WebAssembly/wasi-io/archive/refs/tags/v0.2.6.tar.gz"],
        sha256 = "e3cb3c21d7c49219e885b4564f2dd34beec7403062749c35d73c016043ad6c95",
        strip_prefix = "wasi-io-0.2.6",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "streams",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:io@0.2.6",
    interfaces = ["error", "poll", "streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # Example: Add your own external WIT dependency
    # Replace with your actual repository URL, version, and package info
    # http_archive(
    #     name = "my_external_wit",
    #     urls = ["https://github.com/myorg/my-wit-interfaces/archive/refs/tags/v1.0.0.tar.gz"],
    #     sha256 = "your-sha256-checksum-here",
    #     strip_prefix = "my-wit-interfaces-1.0.0",
    #     build_file_content = """
    # load("@rules_wasm_component//wit:defs.bzl", "wit_library")
    #
    # wit_library(
    #     name = "my_interfaces",
    #     srcs = glob(["wit/*.wit"]),
    #     package_name = "myorg:interfaces@1.0.0",
    #     interfaces = ["api", "types"],
    #     deps = ["@wasi_io//:streams"],  # Add any dependencies
    #     visibility = ["//visibility:public"],
    # )
    # """,
    # )

    # WASI Filesystem interfaces (real example)
    http_archive(
        name = "wasi_filesystem",
        urls = ["https://github.com/WebAssembly/wasi-filesystem/archive/refs/tags/v0.2.1.tar.gz"],
        sha256 = "a1b2c3d4e5f6...",  # You need to calculate this
        strip_prefix = "wasi-filesystem-0.2.1",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "filesystem",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:filesystem@0.2.1",
    interfaces = ["types", "preopens"],
    deps = ["@wasi_io//:streams"],
    visibility = ["//visibility:public"],
)
""",
    )

def wasi_wit_library(name, wasi_version = "0.2.0"):
    """Helper macro to create a wit_library that includes WASI dependencies.

    Args:
        name: Name of the wit_library target
        wasi_version: Version of WASI to use (default: "0.2.0")
    """

    # This is a placeholder for a macro that could automatically include
    # common WASI dependencies based on version
    pass
