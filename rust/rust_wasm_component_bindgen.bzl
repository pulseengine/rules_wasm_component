"""Rust WASM component with WIT bindgen integration"""

load("@rules_rust//rust:defs.bzl", "rust_library", "rust_common")
load("//wit:wit_bindgen.bzl", "wit_bindgen")
load(":rust_wasm_component.bzl", "rust_wasm_component")
load(":transitions.bzl", "wasm_transition")

def _generate_wrapper_impl(ctx):
    """Generate a wrapper that includes both bindings and runtime shim"""
    out_file = ctx.actions.declare_file(ctx.label.name + ".rs")

    # Create wrapper content
    wrapper_content = """// Generated wrapper for WIT bindings

// Suppress clippy warnings for generated code
#![allow(clippy::all)]
#![allow(unused_imports)]
#![allow(dead_code)]

// Minimal wit_bindgen::rt implementation
pub mod wit_bindgen {
    pub mod rt {
        use core::alloc::Layout;
        
        #[inline]
        pub fn run_ctors_once() {
            // No-op - WASM components don't need explicit constructor calls
        }
        
        #[inline]
        pub fn maybe_link_cabi_realloc() {
            // This ensures cabi_realloc is referenced and thus linked
        }
        
        pub struct Cleanup;
        
        impl Cleanup {
            #[inline]
            #[allow(clippy::new_ret_no_self)]
            pub fn new(_layout: Layout) -> (*mut u8, Option<CleanupGuard>) {
                // Return a dummy pointer - in real implementation this would use the allocator
                #[allow(clippy::manual_dangling_ptr)]
                let ptr = 1 as *mut u8; // Non-null dummy pointer
                (ptr, None)
            }
        }
        
        pub struct CleanupGuard;
        
        impl CleanupGuard {
            #[inline]
            pub fn forget(self) {
                // No-op
            }
        }
    }
}

// Generated bindings follow:
"""
    
    # Concatenate wrapper content with generated bindings
    ctx.actions.run_shell(
        command = 'echo \'{}\' > {} && echo "" >> {} && cat {} >> {}'.format(
            wrapper_content.replace("'", "'\"'\"'"),
            out_file.path,
            out_file.path,
            ctx.file.bindgen.path,
            out_file.path,
        ),
        inputs = [ctx.file.bindgen],
        outputs = [out_file],
        mnemonic = "ConcatWitWrapper",
        progress_message = "Concatenating wrapper for {}".format(ctx.label),
    )

    return [DefaultInfo(files = depset([out_file]))]

_generate_wrapper = rule(
    implementation = _generate_wrapper_impl,
    attrs = {
        "bindgen": attr.label(
            allow_single_file = [".rs"],
            doc = "Generated WIT bindings file",
        ),
    },
)

def _wasm_rust_library_impl(ctx):
    """Implementation of wasm_rust_library rule"""
    # This rule just passes through to the rust_library target
    # The transition is handled by the cfg attribute
    target_info = ctx.attr.target[0]
    
    # Collect providers to forward
    providers = []
    
    # Forward DefaultInfo (always needed)
    if DefaultInfo in target_info:
        providers.append(target_info[DefaultInfo])
    
    # Forward CcInfo if present (Rust libraries often provide this)
    if CcInfo in target_info:
        providers.append(target_info[CcInfo])
    
    # Forward Rust-specific providers using the correct rust_common API
    if rust_common.crate_info in target_info:
        providers.append(target_info[rust_common.crate_info])
    
    if rust_common.dep_info in target_info:
        providers.append(target_info[rust_common.dep_info])
    
    # Handle test crate case
    if rust_common.test_crate_info in target_info:
        providers.append(target_info[rust_common.test_crate_info])
    
    # Forward other common providers
    if hasattr(target_info, 'instrumented_files'):
        providers.append(target_info.instrumented_files)
        
    return providers

_wasm_rust_library = rule(
    implementation = _wasm_rust_library_impl,
    attrs = {
        "target": attr.label(
            cfg = wasm_transition,
            doc = "rust_library target to build for WASM",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def rust_wasm_component_bindgen(
        name,
        srcs,
        wit,
        deps = [],
        crate_features = [],
        rustc_flags = [],
        profiles = ["release"],
        visibility = None,
        **kwargs):
    """
    Builds a Rust WebAssembly component with automatic WIT binding generation.

    This macro generates WIT bindings as a separate library and builds a WASM component
    that depends on them. This provides clean separation between generated bindings
    and user implementation code.

    Generated targets:
    - {name}_bindings: A rust_library containing WIT bindings with minimal runtime
    - {name}: The final WASM component that depends on the bindings

    Args:
        name: Target name
        srcs: Rust source files
        wit: WIT library target for binding generation
        deps: Additional Rust dependencies
        crate_features: Rust crate features to enable
        rustc_flags: Additional rustc flags
        profiles: List of build profiles (e.g. ["debug", "release"])
        visibility: Target visibility
        **kwargs: Additional arguments passed to rust_wasm_component

    Example:
        rust_wasm_component_bindgen(
            name = "my_component",
            srcs = ["src/lib.rs"],
            wit = "//wit:my_interfaces",
            profiles = ["debug", "release"],
        )

        # In src/lib.rs:
        use my_component_bindings::exports::my_interface::{Guest};
        struct MyComponent;
        impl Guest for MyComponent { ... }
    """

    # Generate WIT bindings
    bindgen_target = name + "_wit_bindgen_gen"
    wit_bindgen(
        name = bindgen_target,
        wit = wit,
        language = "rust",
        visibility = ["//visibility:private"],
    )

    # Create a wrapper that includes both the generated bindings and the shim
    wrapper_target = name + "_wrapper"
    _generate_wrapper(
        name = wrapper_target,
        bindgen = ":" + bindgen_target,
        visibility = ["//visibility:private"],
    )

    # Create a rust_library from the generated bindings
    bindings_lib = name + "_bindings"
    bindings_lib_host = bindings_lib + "_host"
    
    # Create the bindings library for host platform first
    rust_library(
        name = bindings_lib_host,
        srcs = [":" + wrapper_target],
        crate_name = name.replace("-", "_") + "_bindings",
        edition = "2021",
        visibility = ["//visibility:private"],
    )
    
    # Create a WASM-transitioned version of the bindings library
    _wasm_rust_library(
        name = bindings_lib,
        target = ":" + bindings_lib_host,
        visibility = ["//visibility:private"],
    )

    # Build the WASM component with user sources depending on bindings
    rust_wasm_component(
        name = name,
        srcs = srcs,
        deps = deps + [":" + bindings_lib],
        wit_bindgen = wit,  # Pass the WIT library for component detection
        crate_features = crate_features,
        rustc_flags = rustc_flags,
        profiles = profiles,
        visibility = visibility,
        **kwargs
    )
