"""WASI P3 (Preview 3) WIT interface dependencies — experimental

Provides WASI 0.3.0-rc WIT definitions for async WebAssembly components.

Key P3 changes from P2:
- async func keyword in WIT
- stream<T> and future<T> as Component Model built-in types
- wasi:io eliminated (streams/poll absorbed into Component Model)
- All core interfaces redesigned around async primitives

Source: WebAssembly/WASI monorepo tag v0.3.0-rc-2026-03-15
WIT files live in proposals/<name>/wit-0.3.0-draft/ directories.

NOTE: This is experimental. The P3 spec is in RC phase, not finalized.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# The RC snapshot we track — update this when new RCs ship
WASI_P3_RC = "0.3.0-rc-2026-03-15"
WASI_P3_TAG = "v" + WASI_P3_RC

# Build file content for the monorepo — exposes per-proposal wit_library targets
_WASI_P3_BUILD_FILE = """
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

# WASI CLI P3 — run is async, stdio uses stream<u8>
wit_library(
    name = "cli",
    srcs = glob(["proposals/cli/wit-0.3.0-draft/*.wit"]),
    package_name = "wasi:cli@0.3.0",
    deps = [":clocks", ":filesystem", ":sockets", ":random"],
    visibility = ["//visibility:public"],
)

# WASI HTTP P3 — handle/send are async, bodies are stream<u8>
wit_library(
    name = "http",
    srcs = glob(["proposals/http/wit-0.3.0-draft/*.wit"]),
    package_name = "wasi:http@0.3.0",
    deps = [":cli", ":clocks"],
    visibility = ["//visibility:public"],
)

# WASI Clocks P3 — wait-until/wait-for are async (replaces subscribe+pollable)
wit_library(
    name = "clocks",
    srcs = glob(["proposals/clocks/wit-0.3.0-draft/*.wit"]),
    package_name = "wasi:clocks@0.3.0",
    visibility = ["//visibility:public"],
)

# WASI Filesystem P3 — all ops async, read/write use stream<u8>+future
wit_library(
    name = "filesystem",
    srcs = glob(["proposals/filesystem/wit-0.3.0-draft/*.wit"]),
    package_name = "wasi:filesystem@0.3.0",
    deps = [":clocks"],
    visibility = ["//visibility:public"],
)

# WASI Sockets P3 — TCP connect/send/receive async with stream<u8>
wit_library(
    name = "sockets",
    srcs = glob(["proposals/sockets/wit-0.3.0-draft/*.wit"]),
    package_name = "wasi:sockets@0.3.0",
    deps = [":clocks"],
    visibility = ["//visibility:public"],
)

# WASI Random P3 — minimal changes from P2
wit_library(
    name = "random",
    srcs = glob(["proposals/random/wit-0.3.0-draft/*.wit"]),
    package_name = "wasi:random@0.3.0",
    visibility = ["//visibility:public"],
)
"""

def wasi_wit_p3_dependencies():
    """Load WASI P3 WIT interface definitions from the WASI monorepo.

    Downloads the entire WASI monorepo at the P3 RC tag and exposes
    per-proposal wit_library targets:
    - @wasi_p3//:cli
    - @wasi_p3//:http
    - @wasi_p3//:clocks
    - @wasi_p3//:filesystem
    - @wasi_p3//:sockets
    - @wasi_p3//:random

    Note: No wasi:io target — streams and futures are Component Model
    built-in types in P3, not WASI-level interfaces.
    """

    http_archive(
        name = "wasi_p3",
        urls = ["https://github.com/WebAssembly/WASI/archive/refs/tags/{}.tar.gz".format(WASI_P3_TAG)],
        sha256 = "29db1f783ae7624d1c453cebcd1e53eabd16723fc57c56556778fc11c0a9471d",
        strip_prefix = "WASI-{}".format(WASI_P3_RC),
        build_file_content = _WASI_P3_BUILD_FILE,
    )
