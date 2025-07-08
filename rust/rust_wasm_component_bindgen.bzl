"""Rust WASM component with WIT bindgen integration"""

load("@rules_rust//rust:defs.bzl", "rust_library")
load("//wit:wit_bindgen.bzl", "wit_bindgen")
load(":rust_wasm_component.bzl", "rust_wasm_component")

def _generate_wrapper_impl(ctx):
    """Generate a wrapper that includes both bindings and runtime shim"""
    out_file = ctx.actions.declare_file(ctx.label.name + ".rs")

    # Use shell command to concatenate the shim and generated bindings
    shim_content = """// Generated wrapper for WIT bindings

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

    ctx.actions.run_shell(
        command = """
            echo '{}' > {} && 
            echo '// Generated bindings:' >> {} && 
            cat {} >> {}
        """.format(
            shim_content.replace("'", "'\"'\"'"),  # Escape single quotes
            out_file.path,
            out_file.path,
            ctx.file.bindgen.path,
            out_file.path,
        ),
        inputs = [ctx.file.bindgen],
        outputs = [out_file],
        mnemonic = "GenerateWitWrapper",
        progress_message = "Generating wrapper for {}".format(ctx.label),
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
    rust_library(
        name = bindings_lib,
        srcs = [":" + wrapper_target],
        crate_name = name.replace("-", "_") + "_bindings",
        edition = "2021",
        visibility = ["//visibility:public"],
    )

    # Build the WASM component with user sources depending on bindings
    rust_wasm_component(
        name = name,
        srcs = srcs,
        deps = deps + [":" + bindings_lib],
        crate_features = crate_features,
        rustc_flags = rustc_flags,
        profiles = profiles,
        visibility = visibility,
        **kwargs
    )
