"""TinyGo WASI Preview 2 toolchain for WebAssembly components

This toolchain provides state-of-the-art Go support for WebAssembly Component Model
using TinyGo v0.34.0+ with native WASI Preview 2 support.

Architecture:
- TinyGo v0.34.0+ compiler with --target=wasip2
- go.bytecodealliance.org/cmd/wit-bindgen-go for WIT bindings
- Full WASI Preview 2 and Component Model support
- wasm-tools for component transformation
"""

load("//toolchains:bundle.bzl", "get_version_for_tool", "log_bundle_usage")
load("//toolchains:tool_registry.bzl", "tool_registry")

_TINYGO_TOOLCHAIN_DOC = """
TinyGo WASI Preview 2 toolchain using unified tool_registry for enterprise air-gap support.

All tools (Go SDK, Binaryen, TinyGo) are downloaded via tool_registry.download() which:
- Verifies SHA256 checksums from checksums/tools/*.json
- Supports BAZEL_WASM_MIRROR for corporate mirrors
- Supports BAZEL_WASM_OFFLINE for fully offline builds
- Supports BAZEL_WASM_VENDOR_DIR for shared network caches
"""

# Version constants - centralized for easy updates
_GO_VERSION = "1.25.3"
_BINARYEN_VERSION = "123"

def _setup_go_wit_bindgen(repository_ctx, go_binary):
    """Install wit-bindgen-go Go tool for WIT binding generation

    Installs go.bytecodealliance.org/wit/bindgen which provides 'go tool wit-bindgen-go'

    Supports configurable Go proxy via environment variable for enterprise/air-gap deployments:
    - BAZEL_GOPROXY: Override Go module proxy (default: https://proxy.golang.org,direct)
    """

    print("Installing Go WIT binding tools...")

    # Create bin directory first
    repository_ctx.file("bin/.gitkeep", "")

    # Get Go proxy configuration from environment (enterprise support)
    goproxy = repository_ctx.os.environ.get("BAZEL_GOPROXY", "https://proxy.golang.org,direct")

    # Set up Go environment for tool installation
    go_env = {
        "GOCACHE": str(repository_ctx.path("go_cache")),
        "GOPATH": str(repository_ctx.path("go_path")),
        "CGO_ENABLED": "0",
        "GO111MODULE": "on",
        "GOPROXY": goproxy,
    }

    # Install wit-bindgen-go using hermetic Go - this provides 'go tool wit-bindgen-go'
    result = repository_ctx.execute(
        [str(go_binary), "install", "go.bytecodealliance.org/cmd/wit-bindgen-go@latest"],
        environment = go_env,
        timeout = 300,  # 5 minute timeout
    )

    if result.return_code != 0:
        print("Warning: Failed to install wit-bindgen-go Go tool")
        print("Error: {}".format(result.stderr))
        print("Stdout: {}".format(result.stdout))

        # Create fallback that explains the issue
        repository_ctx.file("bin/wit-bindgen-go", """#!/bin/bash
echo "Error: wit-bindgen-go installation failed during toolchain setup"
echo "Manual installation: go install go.bytecodealliance.org/cmd/wit-bindgen-go@latest"
exit 1
""", executable = True)
    else:
        print("wit-bindgen-go Go tool installed successfully")

        # Test wit-bindgen-go as a standalone binary (installed via go install)
        # The tool is installed in GOPATH/bin, not as a Go tool
        wit_bindgen_binary = repository_ctx.path("go_path/bin/wit-bindgen-go")

        if wit_bindgen_binary.exists:
            print("wit-bindgen-go found as standalone binary")

            # Create wrapper that uses the installed binary directly
            repository_ctx.file("bin/wit-bindgen-go", """#!/bin/bash
# wit-bindgen-go wrapper - uses installed binary
exec "{wit_bindgen_binary}" "$@"
""".format(wit_bindgen_binary = str(wit_bindgen_binary)), executable = True)
        else:
            print("Warning: wit-bindgen-go binary not found in expected location")

            # Try go tool approach as fallback
            test_result = repository_ctx.execute(
                [str(go_binary), "tool", "wit-bindgen-go", "--help"],
                environment = go_env,
                timeout = 30,
            )

            if test_result.return_code == 0:
                print("wit-bindgen-go found as Go tool")
                repository_ctx.file("bin/wit-bindgen-go", """#!/bin/bash
# wit-bindgen-go wrapper - uses Go tool
exec "{go_binary}" tool wit-bindgen-go "$@"
""".format(go_binary = str(go_binary)), executable = True)
            else:
                print("Warning: wit-bindgen-go not available as Go tool either")

def _tinygo_toolchain_repository_impl(repository_ctx):
    """Implementation of TinyGo toolchain repository rule

    Uses tool_registry.download() for ALL downloads with:
    - SHA256 checksum verification
    - Enterprise mirror support (BAZEL_WASM_MIRROR)
    - Offline mode support (BAZEL_WASM_OFFLINE)
    """

    platform = tool_registry.detect_platform(repository_ctx)
    bundle_name = repository_ctx.attr.bundle

    # Resolve version from bundle if specified, otherwise use explicit version
    if bundle_name:
        tinygo_version = get_version_for_tool(
            repository_ctx,
            "tinygo",
            bundle_name = bundle_name,
            fallback_version = repository_ctx.attr.tinygo_version,
        )
        log_bundle_usage(repository_ctx, "tinygo", tinygo_version, bundle_name)
    else:
        tinygo_version = repository_ctx.attr.tinygo_version

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

    # Set up wit-bindgen-go using hermetic Go binary
    _setup_go_wit_bindgen(repository_ctx, go_binary)

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
    srcs = glob(["bin/*", "go_path/**/*"]),
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

# Toolchain definition
toolchain(
    name = "tinygo_toolchain_def",
    exec_compatible_with = [
        "@platforms//os:{os}",
        "@platforms//cpu:{cpu}",
    ],
    target_compatible_with = [
        "@platforms//cpu:wasm32",
    ],
    toolchain = ":tinygo_toolchain",
    toolchain_type = "@rules_wasm_component//toolchains:tinygo_toolchain_type",
)
""".format(
        tinygo_binary_name = "tinygo/bin/tinygo.exe" if platform == "windows_amd64" else "tinygo/bin/tinygo",
        go_binary_name = "go_sdk/bin/go.exe" if platform == "windows_amd64" else "go_sdk/bin/go",
        wasm_opt_binary_name = "binaryen/bin/wasm-opt.exe" if platform == "windows_amd64" else "binaryen/bin/wasm-opt",
        os = "osx" if "darwin" in platform else ("windows" if "windows" in platform else "linux"),
        cpu = "arm64" if "arm64" in platform else "x86_64",
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
            doc = "TinyGo version to download and use. Ignored if bundle is specified.",
            default = "0.40.1",  # Must match a version in checksums/tools/tinygo.json
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
