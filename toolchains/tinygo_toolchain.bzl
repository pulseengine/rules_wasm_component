"""TinyGo WASI Preview 2 toolchain for WebAssembly components

This toolchain provides state-of-the-art Go support for WebAssembly Component Model
using TinyGo v0.34.0+ with native WASI Preview 2 support.

Architecture:
- TinyGo v0.34.0+ compiler with --target=wasip2
- go.bytecodealliance.org/cmd/wit-bindgen-go for WIT bindings
- Full WASI Preview 2 and Component Model support
- wasm-tools for component transformation
"""

load("//checksums:registry.bzl", "get_latest_version")
load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:tool_registry.bzl", "tool_registry")

_TINYGO_TOOLCHAIN_DOC = """
TinyGo WASI Preview 2 toolchain using unified tool_registry for enterprise air-gap support.

All tools (Go SDK, Binaryen, TinyGo, wit-bindgen-go) are downloaded via
tool_registry.download() which:
- Verifies SHA256 checksums from checksums/tools/*.json
- Supports BAZEL_WASM_MIRROR for corporate mirrors
- Supports BAZEL_WASM_OFFLINE for fully offline builds
- Supports BAZEL_WASM_VENDOR_DIR for shared network caches

The Go SDK download (go.dev) is only reachable when something actually
needs tinygo_toolchain_type — Bazel's lazy repository fetching means a
build that never touches a TinyGo/Go target never triggers it. If it's
unexpectedly required, check what in the requested build graph needs this
toolchain type before assuming it's eager.
"""

# Version constants - centralized for easy updates
_GO_VERSION = "1.25.3"
_BINARYEN_VERSION = "129"
_WIT_BINDGEN_GO_VERSION = "0.7.0"

def _setup_go_wit_bindgen(repository_ctx, platform):
    """Install wit-bindgen-go for WIT binding generation.

    Downloaded as a pinned, checksummed binary from its own GitHub releases
    (checksums/tools/wit-bindgen-go.json) via tool_registry — the same
    hermetic path as every other tool here. Previously this ran `go install
    go.bytecodealliance.org/cmd/wit-bindgen-go@latest` using the Go SDK
    downloaded above: an unpinned floating dependency (resolves to whatever
    "latest" is at build time, not reproducible) that also required network
    access to proxy.golang.org — a second, separate host from the GitHub
    releases every other tool in this file already uses, and one more thing
    to allowlist on a restrictive corporate network. Pinning it here removes
    both problems; it does not remove the Go SDK download above, which
    TinyGo compilation itself genuinely needs.
    """
    result = tool_registry.download(
        repository_ctx,
        "wit-bindgen-go",
        _WIT_BINDGEN_GO_VERSION,
        platform,
        output_name = "wit-bindgen-go",
        output_dir = "bin",
    )
    repository_ctx.execute(["chmod", "+x", result["binary_path"]])

def _tinygo_toolchain_repository_impl(repository_ctx):
    """Implementation of TinyGo toolchain repository rule

    Uses tool_registry.download() for ALL downloads with:
    - SHA256 checksum verification
    - Enterprise mirror support (BAZEL_WASM_MIRROR)
    - Offline mode support (BAZEL_WASM_OFFLINE)
    """

    platform = tool_registry.detect_platform(repository_ctx)
    bundle_name = repository_ctx.attr.bundle

    # Resolve version from bundle, explicit attribute, or latest from registry
    if bundle_name:
        tinygo_version = get_version_for_tool(
            repository_ctx,
            "tinygo",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.tinygo_version or get_latest_version(repository_ctx, "tinygo"),
        )
        log_bundle_usage(repository_ctx, "tinygo", tinygo_version, bundle_name)
    elif repository_ctx.attr.tinygo_version:
        tinygo_version = repository_ctx.attr.tinygo_version
    else:
        # Use latest version from checksums registry (single source of truth)
        tinygo_version = get_latest_version(repository_ctx, "tinygo")
        if not tinygo_version:
            fail("Could not determine tinygo version. No version specified and latest_version not found in checksums.")

    print("Setting up TinyGo toolchain v{} for {}".format(tinygo_version, platform))

    # Download hermetic Go SDK via unified registry (with checksums!)
    go_result = tool_registry.download(
        repository_ctx,
        "go",
        _GO_VERSION,
        platform,
        output_dir = "go_sdk",
    )
    go_binary = repository_ctx.path(go_result["binary_path"])

    # Download Binaryen (wasm-opt) via unified registry (with checksums!)
    binaryen_result = tool_registry.download(
        repository_ctx,
        "binaryen",
        _BINARYEN_VERSION,
        platform,
        output_dir = "binaryen",
    )
    wasm_opt_binary = repository_ctx.path(binaryen_result["binary_path"])

    # Download TinyGo via unified registry (with checksums!)
    tinygo_result = tool_registry.download(
        repository_ctx,
        "tinygo",
        tinygo_version,
        platform,
        output_dir = "tinygo",
    )
    tinygo_binary = repository_ctx.path(tinygo_result["binary_path"])

    # Set up wit-bindgen-go — pinned download, not a `go install`
    _setup_go_wit_bindgen(repository_ctx, platform)

    # wasm-tools will be provided by the wasm toolchain dependency

    # Create toolchain BUILD file
    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:tinygo_toolchain.bzl", "tinygo_toolchain")

package(default_visibility = ["//visibility:public"])

# TinyGo installation files
filegroup(
    name = "tinygo_files",
    srcs = glob(["tinygo/**/*"]),
    visibility = ["//visibility:public"],
)

# wit-bindgen-go tool files
filegroup(
    name = "wit_bindgen_go_files",
    srcs = glob(["bin/*"]),
    visibility = ["//visibility:public"],
)

# Hermetic Go SDK files
filegroup(
    name = "go_sdk_files",
    srcs = glob(["go_sdk/**/*"]),
    visibility = ["//visibility:public"],
)

# Binaryen files
filegroup(
    name = "binaryen_files",
    srcs = glob(["binaryen/**/*"]),
    visibility = ["//visibility:public"],
)

# Go binary for TinyGo
alias(
    name = "go_binary",
    actual = "{go_binary_name}",
    visibility = ["//visibility:public"],
)

# wasm-opt binary from Binaryen
alias(
    name = "wasm_opt_binary",
    actual = "{wasm_opt_binary_name}",
    visibility = ["//visibility:public"],
)

# TinyGo binary
alias(
    name = "tinygo_binary",
    actual = "{tinygo_binary_name}",
    visibility = ["//visibility:public"],
)

# wit-bindgen-go binary
alias(
    name = "wit_bindgen_go_binary",
    actual = "bin/wit-bindgen-go",
    visibility = ["//visibility:public"],
)

# TinyGo WASI Preview 2 toolchain
tinygo_toolchain(
    name = "tinygo_toolchain",
    tinygo = ":tinygo_binary",
    tinygo_files = ":tinygo_files",
    wit_bindgen_go = ":wit_bindgen_go_binary",
    wit_bindgen_go_files = ":wit_bindgen_go_files",
    go = ":go_binary",
    go_sdk_files = ":go_sdk_files",
    wasm_opt = ":wasm_opt_binary",
    binaryen_files = ":binaryen_files",
)

""".format(
        tinygo_binary_name = "tinygo/bin/tinygo.exe" if platform == "windows_amd64" else "tinygo/bin/tinygo",
        go_binary_name = "go_sdk/bin/go.exe" if platform == "windows_amd64" else "go_sdk/bin/go",
        wasm_opt_binary_name = "binaryen/bin/wasm-opt.exe" if platform == "windows_amd64" else "binaryen/bin/wasm-opt",
    ))

    print("TinyGo toolchain setup complete!")

# Repository rule for TinyGo toolchain
tinygo_toolchain_repository = repository_rule(
    implementation = _tinygo_toolchain_repository_impl,
    attrs = {
        "bundle": attr.string(
            doc = "Toolchain bundle name. If set, version is read from checksums/toolchain_bundles.json",
            default = "",
        ),
        "tinygo_version": attr.string(
            doc = "TinyGo version to download and use. If empty, uses latest from checksums registry. Ignored if bundle is specified.",
            default = "",
        ),
    },
    # Remove environ to prevent system PATH inheritance
)

def _tinygo_toolchain_impl(ctx):
    """Implementation of TinyGo toolchain rule"""

    return [
        platform_common.ToolchainInfo(
            tinygo = ctx.executable.tinygo,
            tinygo_files = ctx.attr.tinygo_files,
            wit_bindgen_go = ctx.executable.wit_bindgen_go,
            wit_bindgen_go_files = ctx.attr.wit_bindgen_go_files if hasattr(ctx.attr, "wit_bindgen_go_files") else None,
            go = ctx.executable.go if hasattr(ctx.executable, "go") else None,
            go_sdk_files = ctx.attr.go_sdk_files if hasattr(ctx.attr, "go_sdk_files") else None,
            wasm_opt = ctx.executable.wasm_opt if hasattr(ctx.executable, "wasm_opt") else None,
            binaryen_files = ctx.attr.binaryen_files if hasattr(ctx.attr, "binaryen_files") else None,
            # WASI Preview 2 configuration
            wasip2_target = "wasip2",
            component_model_support = True,
        ),
    ]

# TinyGo toolchain rule
tinygo_toolchain = rule(
    implementation = _tinygo_toolchain_impl,
    attrs = {
        "tinygo": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "TinyGo binary",
            mandatory = True,
        ),
        "tinygo_files": attr.label(
            allow_files = True,
            doc = "TinyGo installation files",
            mandatory = True,
        ),
        "wit_bindgen_go": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wit-bindgen-go tool",
            mandatory = True,
        ),
        "wit_bindgen_go_files": attr.label(
            allow_files = True,
            doc = "wit-bindgen-go tool files",
            mandatory = False,
        ),
        "go": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Hermetic Go binary for TinyGo",
            mandatory = False,
        ),
        "go_sdk_files": attr.label(
            allow_files = True,
            doc = "Hermetic Go SDK files for TinyGo",
            mandatory = False,
        ),
        "wasm_opt": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-opt binary from Binaryen",
            mandatory = False,
        ),
        "binaryen_files": attr.label(
            allow_files = True,
            doc = "Binaryen installation files",
            mandatory = False,
        ),
    },
)
