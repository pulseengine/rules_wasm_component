"""Rust WASM binary rule for CLI components

This rule builds Rust binaries as WebAssembly CLI components that export
wasi:cli/command interface, suitable for execution with wasmtime.
"""

load("@rules_rust//rust:defs.bzl", "rust_binary")
load(":transitions.bzl", "wasm_transition")

def _wasm_rust_binary_impl(ctx):
    """Implementation that forwards a rust_binary with WASM transition applied"""
    target_info = ctx.attr.target[0]
    default_info = target_info[DefaultInfo]

    # Get the executable from the target
    source_executable = default_info.files_to_run.executable

    # Create our own executable output by symlinking to the source
    # This is required because executable rules must create their own outputs
    output = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = output,
        target_file = source_executable,
        is_executable = True,
    )

    # Forward the default info with our own executable
    providers = [DefaultInfo(
        files = depset([output]),
        runfiles = default_info.default_runfiles,
        executable = output,
    )]

    # Forward RustInfo if available
    if hasattr(target_info, "rust_info"):
        providers.append(target_info.rust_info)

    return providers

_wasm_rust_binary_rule = rule(
    implementation = _wasm_rust_binary_impl,
    attrs = {
        "target": attr.label(
            cfg = wasm_transition,
            doc = "rust_binary target to build for WASM",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,  # WASM binaries are executable via wasmtime
)

def rust_wasm_binary(
        name,
        srcs,
        deps = [],
        crate_features = [],
        rustc_flags = [],
        visibility = None,
        edition = "2021",
        **kwargs):
    """
    Builds a Rust WebAssembly CLI binary component.

    This macro creates a Rust binary compiled to wasm32-wasip2 that automatically
    exports the wasi:cli/command interface, making it executable via wasmtime.

    Args:
        name: Target name
        srcs: Rust source files (must include main.rs)
        deps: Rust dependencies
        crate_features: Rust crate features to enable
        rustc_flags: Additional rustc flags
        visibility: Target visibility
        edition: Rust edition (default: "2021")
        **kwargs: Additional arguments passed to rust_binary

    Example:
        rust_wasm_binary(
            name = "my_cli_tool",
            srcs = ["src/main.rs"],
            deps = [
                "@crates//:clap",
                "@crates//:anyhow",
            ],
        )
    """

    # Build the host-platform rust_binary first
    host_binary_name = name + "_host"
    rust_binary(
        name = host_binary_name,
        srcs = srcs,
        deps = deps,
        edition = edition,
        crate_features = crate_features,
        rustc_flags = rustc_flags,
        visibility = ["//visibility:private"],
        **kwargs
    )

    # Apply WASM transition to get actual WASM binary
    _wasm_rust_binary_rule(
        name = name,
        target = ":" + host_binary_name,
        visibility = visibility,
    )
