"""Rule for compiling Rust to WASM modules without component model bindings"""

load("@rules_rust//rust:defs.bzl", "rust_shared_library")
load(":transitions.bzl", "wasm_transition")

def _wasm_rust_module_impl(ctx):
    """Implementation that forwards a rust_shared_library with WASM transition applied"""
    target_info = ctx.attr.target[0]

    # Forward DefaultInfo
    return [target_info[DefaultInfo]]

_wasm_rust_module = rule(
    implementation = _wasm_rust_module_impl,
    attrs = {
        "target": attr.label(
            cfg = wasm_transition,
            doc = "rust_shared_library target to build for WASM",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def rust_wasm_module(name, srcs, deps = [], edition = "2021", **kwargs):
    """
    Compiles Rust to a WASM module using hermetic Bazel toolchain.

    This creates a rust_shared_library and applies the WASM transition to it,
    ensuring proper cross-compilation to WebAssembly.

    Args:
        name: Target name
        srcs: Rust source files
        deps: Rust dependencies
        edition: Rust edition (default: "2021")
        **kwargs: Additional arguments passed to rust_shared_library
    """

    # Create the host-platform rust_shared_library
    host_target = name + "_host"
    rust_shared_library(
        name = host_target,
        srcs = srcs,
        deps = deps,
        edition = edition,
        visibility = ["//visibility:private"],
        **kwargs
    )

    # Apply WASM transition to get actual WASM module
    _wasm_rust_module(
        name = name,
        target = ":" + host_target,
    )
