"""WASI WIT interface dependencies for WebAssembly components

This file provides Bazel-native http_archive rules for WASI WIT definitions,
following the Bazel-first approach instead of using shell scripts or wit-deps tool.

Provides both WASI 0.2.0 (maximum compatibility) and 0.2.3 (latest features).
See docs-site/src/content/docs/guides/external-wit-dependencies.mdx for usage guide.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def wasi_wit_dependencies():
    """Load WASI WIT interface definitions as Bazel external dependencies.

    This follows the Bazel-native approach by using http_archive rules
    instead of shell scripts or external dependency management tools.

    Provides both WASI 0.2.0 and 0.2.3 versions for maximum compatibility.
    """

    # ========================================================================
    # WASI 0.2.0 (Original stable release - better toolchain compatibility)
    # ========================================================================

    # WASI IO interfaces v0.2.0 (includes streams, error, poll)
    http_archive(
        name = "wasi_io_v020",
        urls = ["https://github.com/WebAssembly/wasi-io/archive/refs/tags/v0.2.0.tar.gz"],
        sha256 = "0e98868cfa86f2927c045b13a0c71f70609c5eeddd477abf011e5fb62549ea6a",
        strip_prefix = "wasi-io-0.2.0",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "streams",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:io@0.2.0",
    interfaces = ["error", "poll", "streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI CLI interfaces v0.2.0 (includes environment, exit, stdin, stdout, stderr)
    http_archive(
        name = "wasi_cli_v020",
        urls = ["https://github.com/WebAssembly/wasi-cli/archive/refs/tags/v0.2.0.tar.gz"],
        sha256 = "c35931d345381ffaf051329235083f8cec63b9421f120d49fc82d30d8870cb0e",
        strip_prefix = "wasi-cli-0.2.0",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "cli",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:cli@0.2.0",
    interfaces = ["environment", "exit", "stdin", "stdout", "stderr", "terminal-input", "terminal-output", "terminal-stdin", "terminal-stdout", "terminal-stderr"],
    deps = ["@wasi_io_v020//:streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI Clocks interfaces v0.2.0
    http_archive(
        name = "wasi_clocks_v020",
        urls = ["https://github.com/WebAssembly/wasi-clocks/archive/refs/tags/v0.2.0.tar.gz"],
        sha256 = "b6131b9ef2968fc6add2e42081770d0f0e22af9c8e5c367716febb7913a5c2a8",
        strip_prefix = "wasi-clocks-0.2.0",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "clocks",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:clocks@0.2.0",
    interfaces = ["wall-clock", "monotonic-clock"],
    visibility = ["//visibility:public"],
)
""",
    )

    # ========================================================================
    # WASI 0.2.3 (Latest release - full feature set)
    # ========================================================================

    # WASI IO interfaces (includes streams, error, poll)
    http_archive(
        name = "wasi_io",
        urls = ["https://github.com/WebAssembly/wasi-io/archive/refs/tags/v0.2.3.tar.gz"],
        sha256 = "d34f61c21b3739a88821e57ac1ebc3bd80b79a45ccb2de168453050355cf68d9",
        strip_prefix = "wasi-io-0.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "streams",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:io@0.2.3",
    interfaces = ["error", "poll", "streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI CLI interfaces (includes environment, exit, stdin, stdout, stderr)
    http_archive(
        name = "wasi_cli",
        urls = ["https://github.com/WebAssembly/wasi-cli/archive/refs/tags/v0.2.3.tar.gz"],
        sha256 = "7d717274ebf872b996a031a55e619b9ecee0e5a02e5ae9fdaef84f541958cdf8",
        strip_prefix = "wasi-cli-0.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "cli",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:cli@0.2.3",
    interfaces = ["environment", "exit", "stdin", "stdout", "stderr", "terminal-input", "terminal-output", "terminal-stdin", "terminal-stdout", "terminal-stderr"],
    deps = ["@wasi_io//:streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI Clocks interfaces
    http_archive(
        name = "wasi_clocks",
        urls = ["https://github.com/WebAssembly/wasi-clocks/archive/refs/tags/v0.2.3.tar.gz"],
        sha256 = "8d56927a581bda2b00774fc5a9ad93fc4d84d88c5e14e7e3f3738f420ae75052",
        strip_prefix = "wasi-clocks-0.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "clocks",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:clocks@0.2.3",
    interfaces = ["wall-clock", "monotonic-clock"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI Filesystem interfaces
    http_archive(
        name = "wasi_filesystem",
        urls = ["https://github.com/WebAssembly/wasi-filesystem/archive/refs/tags/v0.2.3.tar.gz"],
        sha256 = "e31161ee490a1a9b1eb850ad65c53efa004fcb8a5d3ed43f1a296ccb6c2f24bd",
        strip_prefix = "wasi-filesystem-0.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "filesystem",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:filesystem@0.2.3",
    interfaces = ["types", "preopens"],  # Explicitly specify available interfaces
    deps = ["@wasi_io//:streams", "@wasi_clocks//:clocks"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI Sockets interfaces
    http_archive(
        name = "wasi_sockets",
        urls = ["https://github.com/WebAssembly/wasi-sockets/archive/refs/tags/v0.2.3.tar.gz"],
        sha256 = "45398e514b21c0003a67295fac6d711f4a2b730b338f6fd5842c433f4db00490",
        strip_prefix = "wasi-sockets-0.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "sockets",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:sockets@0.2.3",
    interfaces = ["network", "udp", "tcp", "udp-create-socket", "tcp-create-socket", "instance-network", "ip-name-lookup"],
    deps = ["@wasi_io//:streams"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI Random interfaces
    http_archive(
        name = "wasi_random",
        urls = ["https://github.com/WebAssembly/wasi-random/archive/refs/tags/v0.2.3.tar.gz"],
        sha256 = "173bf2e11d94bbc6a819afb7a76b39720b46b5a68f0265e76c69794de6e0fc2d",
        strip_prefix = "wasi-random-0.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "random",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:random@0.2.3",
    interfaces = ["random", "insecure", "insecure-seed"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI HTTP interfaces
    http_archive(
        name = "wasi_http",
        urls = ["https://github.com/WebAssembly/wasi-http/archive/refs/tags/v0.2.3.tar.gz"],
        sha256 = "9f5f34a720180eff513ad9e7166b005ebcae2414669b84e5ee33c7c7b29560a4",
        strip_prefix = "wasi-http-0.2.3",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "http",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:http@0.2.3",
    interfaces = ["types", "handler", "outgoing-handler", "proxy"],
    deps = ["@wasi_io//:streams", "@wasi_clocks//:clocks"],
    visibility = ["//visibility:public"],
)
""",
    )

    # ========================================================================
    # WASI Neural Network (WASI-NN) interfaces - All versions
    # ========================================================================

    # WASI-NN v0.2.0-rc-2024-06-25 (Initial release)
    http_archive(
        name = "wasi_nn_v0_2_0_rc_2024_06_25",
        urls = ["https://github.com/WebAssembly/wasi-nn/archive/refs/tags/0.2.0-rc-2024-06-25.tar.gz"],
        sha256 = "f95b982ea5d7475ff3825e65a6319d6ca1e7aa0a5f92c175ee27db1cd0b2ab06",
        strip_prefix = "wasi-nn-0.2.0-rc-2024-06-25",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "nn",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:nn@0.2.0-rc-2024-06-25",
    interfaces = ["tensor", "graph", "inference", "errors"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI-NN v0.2.0-rc-2024-08-19 (Mid release)
    http_archive(
        name = "wasi_nn_v0_2_0_rc_2024_08_19",
        urls = ["https://github.com/WebAssembly/wasi-nn/archive/refs/tags/0.2.0-rc-2024-08-19.tar.gz"],
        sha256 = "f512a77274cfda4f0afc47c417071a718ea379221987446b19e5060bba6594bc",
        strip_prefix = "wasi-nn-0.2.0-rc-2024-08-19",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "nn",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:nn@0.2.0-rc-2024-08-19",
    interfaces = ["tensor", "graph", "inference", "errors"],
    visibility = ["//visibility:public"],
)
""",
    )

    # WASI-NN v0.2.0-rc-2024-10-28 (Latest release)
    http_archive(
        name = "wasi_nn",
        urls = ["https://github.com/WebAssembly/wasi-nn/archive/refs/tags/0.2.0-rc-2024-10-28.tar.gz"],
        sha256 = "2cefa3ff992bd064562547f92e20789a88770f0a6898c569b76125bc4f219ab5",
        strip_prefix = "wasi-nn-0.2.0-rc-2024-10-28",
        build_file_content = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "nn",
    srcs = glob(["wit/*.wit"]),
    package_name = "wasi:nn@0.2.0-rc-2024-10-28",
    interfaces = ["tensor", "graph", "inference", "errors"],
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

def wasi_wit_library(name, wasi_version = "0.2.0"):
    """Helper macro to create a wit_library that includes WASI dependencies.

    Args:
        name: Name of the wit_library target
        wasi_version: Version of WASI to use (default: "0.2.0")
    """

    # This is a placeholder for a macro that could automatically include
    # common WASI dependencies based on version
    pass
