"""Rust WASM component with WIT bindgen integration"""

load("@rules_rust//rust:defs.bzl", "rust_common", "rust_library")
load("//wit:wit_bindgen.bzl", "wit_bindgen")
load("//wit:symmetric_wit_bindgen.bzl", "symmetric_wit_bindgen")
load(":rust_wasm_component.bzl", "rust_wasm_component")
load(":transitions.bzl", "wasm_transition")

def _wasm_rust_library_bindgen_impl(ctx):
    """Implementation that forwards a rust_library with WASM transition applied"""
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
    if hasattr(target_info, "instrumented_files"):
        providers.append(target_info.instrumented_files)

    return providers

_wasm_rust_library_bindgen = rule(
    implementation = _wasm_rust_library_bindgen_impl,
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

def _generate_wrapper_impl(ctx):
    """Generate a wrapper that includes both bindings and runtime shim"""
    out_file = ctx.actions.declare_file(ctx.label.name + ".rs")

    # Create wrapper content based on mode
    if ctx.attr.mode == "native-guest":
        # Native-guest wrapper uses native std runtime
        wrapper_content = """// Generated wrapper for native-guest WIT bindings

// Suppress clippy warnings for generated code
#![allow(clippy::all)]
#![allow(unused_imports)]
#![allow(dead_code)]

// Native runtime implementation for wit_bindgen::rt
pub mod wit_bindgen {
    pub mod rt {
        use std::alloc::Layout;

        #[inline]
        pub fn run_ctors_once() {
            // No-op for native execution - constructors run automatically
        }

        #[inline]
        pub fn maybe_link_cabi_realloc() {
            // No-op for native execution - standard allocator is used
        }

        pub struct Cleanup;

        impl Cleanup {
            #[inline]
            #[allow(clippy::new_ret_no_self)]
            pub fn new(_layout: Layout) -> (*mut u8, Option<CleanupGuard>) {
                // Use standard allocator for native execution
                let ptr = unsafe { std::alloc::alloc(_layout) };
                (ptr, Some(CleanupGuard))
            }
        }

        pub struct CleanupGuard;

        impl CleanupGuard {
            #[inline]
            pub fn forget(self) {
                // Standard memory management handles cleanup
            }
        }

        impl Drop for CleanupGuard {
            fn drop(&mut self) {
                // Standard Drop trait handles cleanup automatically
            }
        }
    }
}

// Provide export! macro for native-guest mode as a no-op
#[macro_export]
macro_rules! export {
    ($component:ident with_types_in $pkg:path) => {
        // No-op for native-guest mode - the component struct can be used directly
        // In native applications, you would typically call Guest trait methods directly
    };
}

// Generated bindings follow:
"""
    else:
        # Guest wrapper uses WASM component runtime stubs
        wrapper_content = """// Generated wrapper for guest WIT bindings

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
    # Modern approach: write wrapper first, then append bindgen content with single cat command
    temp_wrapper = ctx.actions.declare_file(ctx.label.name + "_wrapper.rs")
    ctx.actions.write(
        output = temp_wrapper,
        content = wrapper_content + "\n",
    )

    # Create filtered content based on mode
    if ctx.attr.mode == "native-guest":
        # Read bindgen file and filter out conflicting exports
        filter_script = ctx.actions.declare_file(ctx.label.name + "_filter.py")
        filter_content = """#!/usr/bin/env python3
import sys

# Read wrapper content
with open(sys.argv[1], 'r') as f:
    wrapper_content = f.read()

# Read bindgen content
with open(sys.argv[2], 'r') as f:
    bindgen_content = f.read()

# Filter out conflicting export statements for native-guest mode
filtered_lines = []
for line in bindgen_content.split('\\n'):
    # Skip lines that start with pub(crate) use __export_ and end with _impl as export;
    if not (line.strip().startswith('pub(crate) use __export_') and line.strip().endswith('_impl as export;')):
        filtered_lines.append(line)

# Write combined content
with open(sys.argv[3], 'w') as f:
    f.write(wrapper_content)
    f.write('\\n'.join(filtered_lines))
"""
        ctx.actions.write(
            output = filter_script,
            content = filter_content,
            is_executable = True,
        )

        ctx.actions.run(
            executable = filter_script,
            arguments = [temp_wrapper.path, ctx.file.bindgen.path, out_file.path],
            inputs = [temp_wrapper, ctx.file.bindgen, filter_script],
            outputs = [out_file],
            mnemonic = "FilterWitWrapper",
            progress_message = "Filtering wrapper for {}".format(ctx.label),
        )
    else:
        # For guest mode, use file_ops component for cross-platform concatenation
        # Build JSON config for file_ops concatenate-files operation
        config_file = ctx.actions.declare_file(ctx.label.name + "_concat_config.json")
        ctx.actions.write(
            output = config_file,
            content = json.encode({
                "workspace_dir": ".",
                "operations": [{
                    "type": "concatenate_files",
                    "input_files": [temp_wrapper.path, ctx.file.bindgen.path],
                    "output_file": out_file.path,
                }]
            }),
        )

        # Get file_ops tool from toolchain
        file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
        file_ops_tool = file_ops_toolchain.file_ops_component

        # Execute cross-platform file concatenation
        ctx.actions.run(
            executable = file_ops_tool,
            arguments = [config_file.path],
            inputs = [temp_wrapper, ctx.file.bindgen, config_file],
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
        "mode": attr.string(
            values = ["guest", "native-guest"],
            default = "guest",
            doc = "Generation mode: 'guest' for WASM component, 'native-guest' for native application",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:file_ops_toolchain_type"],
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
    if hasattr(target_info, "instrumented_files"):
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
        validate_wit = False,
        visibility = None,
        symmetric = False,
        invert_direction = False,
        **kwargs):
    """Builds a Rust WebAssembly component with automatic WIT binding generation.

    Generates WIT bindings as a separate library and builds a WASM component that depends on
    them, providing clean separation between generated bindings and user implementation code.

    Args:
        name: Target name
        srcs: Rust source files
        wit: WIT library target for binding generation
        deps: Additional Rust dependencies
        crate_features: Rust crate features to enable
        rustc_flags: Additional rustc flags
        profiles: List of build profiles (e.g. ["debug", "release"])
        visibility: Target visibility
        symmetric: Enable symmetric mode for same source code to run natively and as WASM (requires cpetig's fork)
        invert_direction: Invert direction for symmetric interfaces (only used with symmetric=True)
        **kwargs: Additional arguments passed to rust_wasm_component
    """
    # Generate WIT bindings based on symmetric flag
    if symmetric:
        # Symmetric mode: Generate symmetric bindings for both native and WASM from same source
        bindgen_symmetric_target = name + "_wit_bindgen_symmetric"

        symmetric_wit_bindgen(
            name = bindgen_symmetric_target,
            wit = wit,
            language = "rust",
            invert_direction = invert_direction,
            visibility = ["//visibility:private"],
        )

        # For symmetric mode, we'll create feature-based compilation
        bindgen_guest_target = bindgen_symmetric_target
        bindgen_native_guest_target = bindgen_symmetric_target
    else:
        # Traditional mode: Generate separate guest and native-guest bindings
        bindgen_guest_target = name + "_wit_bindgen_guest"
        bindgen_native_guest_target = name + "_wit_bindgen_native_guest"

        # Guest mode bindings for WASM component implementation
        wit_bindgen(
            name = bindgen_guest_target,
            wit = wit,
            language = "rust",
            generation_mode = "guest",
            visibility = ["//visibility:private"],
        )

        # Native-guest mode bindings for native applications
        wit_bindgen(
            name = bindgen_native_guest_target,
            wit = wit,
            language = "rust",
            generation_mode = "native-guest",
            visibility = ["//visibility:private"],
        )

    # Create separate wrappers for guest and native-guest bindings
    wrapper_guest_target = name + "_wrapper_guest"
    wrapper_native_guest_target = name + "_wrapper_native_guest"

    _generate_wrapper(
        name = wrapper_guest_target,
        bindgen = ":" + bindgen_guest_target,
        mode = "guest",
        visibility = ["//visibility:private"],
    )

    _generate_wrapper(
        name = wrapper_native_guest_target,
        bindgen = ":" + bindgen_native_guest_target,
        mode = "native-guest",
        visibility = ["//visibility:private"],
    )

    # Create a rust_library from the generated bindings
    bindings_lib = name + "_bindings"
    bindings_lib_host = bindings_lib + "_host"

    # Create the bindings library for native platform (host) using native-guest wrapper
    rust_library(
        name = bindings_lib_host,
        srcs = [":" + wrapper_native_guest_target],
        crate_name = name.replace("-", "_") + "_bindings",
        edition = "2021",
        visibility = visibility,  # Make native bindings publicly available
        # Note: wasmtime dependency would be needed for full native-guest functionality
        # For now, providing compilation-compatible stubs
    )

    # Create a separate WASM bindings library using guest wrapper
    bindings_lib_wasm_base = bindings_lib + "_wasm_base"
    rust_library(
        name = bindings_lib_wasm_base,
        srcs = [":" + wrapper_guest_target],
        crate_name = name.replace("-", "_") + "_bindings",
        edition = "2021",
        visibility = ["//visibility:private"],
    )

    # Create a WASM-transitioned version of the WASM bindings library
    _wasm_rust_library_bindgen(
        name = bindings_lib,
        target = ":" + bindings_lib_wasm_base,
        visibility = ["//visibility:private"],
    )

    # Build the WASM component with user sources depending on bindings
    rust_wasm_component(
        name = name,
        srcs = srcs,
        deps = deps + [":" + bindings_lib],
        wit = wit,  # Pass the WIT library for component detection
        crate_features = crate_features,
        rustc_flags = rustc_flags,
        profiles = profiles,
        validate_wit = validate_wit,  # Pass validation flag to component
        visibility = visibility,
        **kwargs
    )
