"""Rust WASM component with WIT bindgen macro integration

This file provides an alternative to rust_wasm_component_bindgen that uses
wit-bindgen's generate!() macro directly in source code instead of generating
separate crate files.
"""

load("@rules_rust//rust:defs.bzl", "rust_library")
load(":rust_wasm_component.bzl", "rust_wasm_component")
load(":transitions.bzl", "wasm_transition")

def _wasm_rust_library_macro_impl(ctx):
    """Implementation that forwards a rust_library with WASM transition applied"""
    target_info = ctx.attr.target[0]

    # Forward all providers from the transitioned target
    providers = []

    # Forward DefaultInfo (always needed)
    if DefaultInfo in target_info:
        providers.append(target_info[DefaultInfo])

    # Forward CcInfo if present (Rust libraries often provide this)
    if CcInfo in target_info:
        providers.append(target_info[CcInfo])

    # Forward Rust-specific providers
    rust_common = ctx.toolchains["@rules_rust//rust:toolchain_type"].rust_std
    if hasattr(rust_common, "crate_info") and rust_common.crate_info in target_info:
        providers.append(target_info[rust_common.crate_info])

    if hasattr(rust_common, "dep_info") and rust_common.dep_info in target_info:
        providers.append(target_info[rust_common.dep_info])

    # Forward other common providers
    for provider in [CcInfo, InstrumentedFilesInfo]:
        if provider in target_info:
            providers.append(target_info[provider])

    return providers

_wasm_rust_library_macro = rule(
    implementation = _wasm_rust_library_macro_impl,
    attrs = {
        "target": attr.label(
            cfg = wasm_transition,
            doc = "rust_library target to build for WASM",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    toolchains = ["@rules_rust//rust:toolchain_type"],
)

def rust_wasm_component_macro(
        name,
        srcs,
        wit,
        wit_bindgen_crate = "@crate_index//:wit-bindgen",
        deps = [],
        crate_features = [],
        rustc_flags = [],
        profiles = ["release"],
        visibility = None,
        symmetric = False,
        generation_mode = "guest",
        **kwargs):
    """
    Builds a Rust WebAssembly component using wit-bindgen generate!() macro.

    This macro allows developers to use wit-bindgen's generate!() macro directly
    in their source code instead of generating separate binding crates. The WIT
    files are made available to the macro via compile_data and environment variables.

    Generated targets:
    - {name}_host: Host-platform rust_library for host applications
    - {name}: The final WASM component

    Args:
        name: Target name
        srcs: Rust source files (must contain wit_bindgen::generate!() calls)
        wit: WIT library target for the macro to access
        wit_bindgen_crate: The wit-bindgen crate dependency (default: from crate_index)
        deps: Additional Rust dependencies
        crate_features: Rust crate features to enable
        rustc_flags: Additional rustc flags
        profiles: List of build profiles (e.g. ["debug", "release"])
        visibility: Target visibility
        symmetric: Enable symmetric mode (requires cpetig's wit-bindgen fork)
        generation_mode: Generation mode: "guest" or "native-guest"
        **kwargs: Additional arguments passed to rust_wasm_component

    Example:
        rust_wasm_component_macro(
            name = "my_component",
            srcs = ["src/lib.rs"],
            wit = "//wit:my_interfaces",
            profiles = ["debug", "release"],
        )

        # In src/lib.rs:
        use wit_bindgen::generate;

        generate!({
            world: "my-world",
            path: "../wit",  // Resolved via CARGO_MANIFEST_DIR
        });

        // Use generated bindings...

    Requirements:
        - Source files must use wit_bindgen::generate!() macro
        - WIT files must be accessible relative to CARGO_MANIFEST_DIR
        - The wit_bindgen crate must be available as a dependency
    """

    # Get WIT info to set up paths
    wit_library_target = wit

    # Define wit-bindgen dependency
    if symmetric:
        # For symmetric mode, would need cpetig's fork
        # This would require additional configuration
        fail("Symmetric mode not yet implemented for macro approach")

    wit_bindgen_dep = wit_bindgen_crate

    # Create a rust_library for the host platform
    host_lib = name + "_host"
    rust_library(
        name = host_lib,
        srcs = srcs,
        deps = deps + [wit_bindgen_dep],
        crate_features = crate_features + _get_macro_features(generation_mode),
        rustc_flags = rustc_flags,
        edition = "2021",
        compile_data = [wit_library_target],
        rustc_env = _build_rustc_env(wit_library_target, generation_mode),
        visibility = visibility,
    )

    # Create a WASM-platform version
    wasm_lib_base = name + "_wasm_base"
    rust_library(
        name = wasm_lib_base,
        srcs = srcs,
        deps = deps + [wit_bindgen_dep],
        crate_features = crate_features + _get_macro_features("guest"),
        rustc_flags = rustc_flags,
        edition = "2021",
        compile_data = [wit_library_target],
        rustc_env = _build_rustc_env(wit_library_target, "guest"),
        visibility = ["//visibility:private"],
    )

    # Apply WASM transition
    wasm_lib = name + "_wasm_lib"
    _wasm_rust_library_macro(
        name = wasm_lib,
        target = ":" + wasm_lib_base,
        visibility = ["//visibility:private"],
    )

    # Build the final WASM component
    rust_wasm_component(
        name = name,
        srcs = srcs,
        deps = [":" + wasm_lib],
        wit = wit,
        profiles = profiles,
        visibility = visibility,
        **kwargs
    )

def _get_macro_features(generation_mode):
    """Get additional crate features needed for wit-bindgen macro mode"""
    if generation_mode == "native-guest":
        return ["std"]  # Enable std runtime for native execution
    return []  # Default guest mode

def _build_rustc_env(wit_target, generation_mode):
    """Build rustc_env dictionary for wit-bindgen macro compilation"""

    # Base environment variables that wit-bindgen macros expect
    env = {
        # Standard Cargo environment variables
        "CARGO_MANIFEST_DIR": "$(execpath " + wit_target + ")",
        "CARGO_PKG_NAME": "generated",
        "CARGO_PKG_VERSION": "0.1.0",

        # WIT-specific paths - wit-bindgen macros look for WIT files relative to CARGO_MANIFEST_DIR
        "WIT_ROOT_DIR": "$(execpath " + wit_target + ")",
    }

    # Generation mode specific configuration
    if generation_mode == "native-guest":
        env["WIT_BINDGEN_RT_MODE"] = "native"
    else:
        env["WIT_BINDGEN_RT_MODE"] = "wasm"

    return env
