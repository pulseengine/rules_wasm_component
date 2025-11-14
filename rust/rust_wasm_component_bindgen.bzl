"""Rust WASM component with WIT bindgen integration"""

load("@rules_rust//rust:defs.bzl", "rust_common", "rust_library")
load("//wit:wit_bindgen.bzl", "wit_bindgen")
load("//wit:symmetric_wit_bindgen.bzl", "symmetric_wit_bindgen")
load("//toolchains:tool_versions.bzl", "get_tool_version")
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

    # Create wrapper content - embedded runtime compatible with wit-bindgen CLI
    # The wit-bindgen CLI generates code that expects: crate::wit_bindgen::rt
    # The CLI also generates the export! macro with --pub-export-macro flag
    #
    # COMPATIBILITY: This embedded runtime is compatible with wit-bindgen CLI versions:
    # - 0.44.0, 0.45.0, 0.46.0 (tested and verified)
    # - Requires API: Cleanup, CleanupGuard, run_ctors_once(), maybe_link_cabi_realloc()
    # - Uses: --runtime-path crate::wit_bindgen::rt, --pub-export-macro flags
    #
    # IMPORTANT: When updating wit-bindgen CLI version (in wasm_toolchain.bzl),
    # verify this embedded runtime still provides the required API.
    # Check generated bindings for any new runtime requirements.

    # Validate CLI version compatibility
    COMPATIBLE_CLI_VERSIONS = ["0.44.0", "0.45.0", "0.46.0"]
    cli_version = get_tool_version("wit-bindgen")
    if cli_version not in COMPATIBLE_CLI_VERSIONS:
        fail(
            "Embedded runtime incompatible with wit-bindgen CLI {}. " +
            "Compatible versions: {}. " +
            "Update the embedded runtime in rust_wasm_component_bindgen.bzl or downgrade CLI version.".format(
                cli_version,
                ", ".join(COMPATIBLE_CLI_VERSIONS)
            )
        )

    # Different wrapper content based on mode
    if ctx.attr.mode == "native-guest":
        wrapper_content = """// Generated wrapper for WIT bindings (native-guest mode)
//
// COMPATIBILITY: wit-bindgen CLI 0.44.0 - 0.46.0
// This wrapper provides a wit_bindgen::rt module compatible with the CLI-generated code.
// The runtime provides allocation helpers and cleanup guards expected by generated bindings.
//
// For native-guest mode, we also provide a no-op export! macro since native applications
// don't need to export WASM functions.
//
// API provided:
// - Cleanup::new(layout) -> (*mut u8, Option<CleanupGuard>)
// - CleanupGuard (with Drop impl for deallocation)
// - run_ctors_once() - no-op for native applications
// - maybe_link_cabi_realloc() - no-op for native applications
// - export! - no-op macro for native applications (does nothing)

// Suppress clippy warnings for generated code
#![allow(clippy::all)]
#![allow(unused_imports)]
#![allow(dead_code)]

// Minimal wit_bindgen::rt runtime compatible with CLI-generated code
pub mod wit_bindgen {
    pub mod rt {
        use core::alloc::Layout;

        #[inline]
        pub fn run_ctors_once() {
            // No-op - native applications don't need constructor calls
        }

        #[inline]
        pub fn maybe_link_cabi_realloc() {
            // No-op - native applications don't need cabi_realloc
        }

        pub struct Cleanup;

        impl Cleanup {
            #[inline]
            #[allow(clippy::new_ret_no_self)]
            pub fn new(layout: Layout) -> (*mut u8, Option<CleanupGuard>) {
                // Use the global allocator to allocate memory
                // SAFETY: We're allocating with a valid layout
                let ptr = unsafe { std::alloc::alloc(layout) };

                // Return the pointer and a cleanup guard
                // If allocation fails, alloc() will panic (as per std::alloc behavior)
                (ptr, Some(CleanupGuard { ptr, layout }))
            }
        }

        pub struct CleanupGuard {
            ptr: *mut u8,
            layout: Layout,
        }

        impl CleanupGuard {
            #[inline]
            pub fn forget(self) {
                // Prevent the Drop from running
                core::mem::forget(self);
            }
        }

        impl Drop for CleanupGuard {
            fn drop(&mut self) {
                // SAFETY: ptr was allocated with layout in Cleanup::new
                unsafe {
                    std::alloc::dealloc(self.ptr, self.layout);
                }
            }
        }
    }
}

// No-op export macro for native-guest mode
// Native applications don't export WASM functions, so this does nothing
#[allow(unused_macros)]
#[macro_export]
macro_rules! export {
    ($($t:tt)*) => {
        // No-op: native applications don't export WASM functions
    };
}

// Generated bindings follow:
"""
    else:
        wrapper_content = """// Generated wrapper for WIT bindings (guest mode)
//
// COMPATIBILITY: wit-bindgen CLI 0.44.0 - 0.46.0
// This wrapper provides a wit_bindgen::rt module compatible with the CLI-generated code.
// The runtime provides allocation helpers and cleanup guards expected by generated bindings.
//
// The export! macro is generated by wit-bindgen CLI (via --pub-export-macro flag).
//
// API provided:
// - Cleanup::new(layout) -> (*mut u8, Option<CleanupGuard>)
// - CleanupGuard (with Drop impl for deallocation)
// - run_ctors_once() - no-op for WASM components
// - maybe_link_cabi_realloc() - ensures cabi_realloc is linked

// Suppress clippy warnings for generated code
#![allow(clippy::all)]
#![allow(unused_imports)]
#![allow(dead_code)]

// Minimal wit_bindgen::rt runtime compatible with CLI-generated code
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
            pub fn new(layout: Layout) -> (*mut u8, Option<CleanupGuard>) {
                // Use the global allocator to allocate memory
                // SAFETY: We're allocating with a valid layout
                let ptr = unsafe { std::alloc::alloc(layout) };

                // Return the pointer and a cleanup guard
                // If allocation fails, alloc() will panic (as per std::alloc behavior)
                (ptr, Some(CleanupGuard { ptr, layout }))
            }
        }

        pub struct CleanupGuard {
            ptr: *mut u8,
            layout: Layout,
        }

        impl CleanupGuard {
            #[inline]
            pub fn forget(self) {
                // Prevent the Drop from running
                core::mem::forget(self);
            }
        }

        impl Drop for CleanupGuard {
            fn drop(&mut self) {
                // SAFETY: ptr was allocated with layout in Cleanup::new
                unsafe {
                    std::alloc::dealloc(self.ptr, self.layout);
                }
            }
        }
    }
}

// Generated bindings follow (including export! macro):
"""

    # Concatenate wrapper content with generated bindings
    # Simple approach: write wrapper first, then append bindgen content
    temp_wrapper = ctx.actions.declare_file(ctx.label.name + "_wrapper.rs")
    ctx.actions.write(
        output = temp_wrapper,
        content = wrapper_content + "\n",
    )

    # For native-guest mode, filter out the conflicting pub(crate) use export line
    # For guest mode, just concatenate directly
    if ctx.attr.mode == "native-guest":
        # Use Python to filter out conflicting export line
        filter_script = ctx.actions.declare_file(ctx.label.name + "_filter.py")
        filter_content = """#!/usr/bin/env python3
import sys

# Read wrapper content
with open(sys.argv[1], 'r') as f:
    wrapper_content = f.read()

# Read bindgen content
with open(sys.argv[2], 'r') as f:
    bindgen_content = f.read()

# Filter out conflicting pub(crate) use export line
# The wrapper provides a public export! macro, so we don't need the crate-private one
filtered_lines = []
for line in bindgen_content.split('\\n'):
    # Skip lines that re-export as 'export' (conflicts with our macro)
    if not (line.strip().startswith('pub(crate) use') and line.strip().endswith(' as export;')):
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
            progress_message = "Filtering native-guest wrapper for {}".format(ctx.label),
        )
    else:
        # Use file_ops component for cross-platform concatenation
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
                }],
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
    # The native-guest wrapper includes a no-op export! macro that does nothing,
    # since native applications don't export WASM functions
    rust_library(
        name = bindings_lib_host,
        srcs = [":" + wrapper_native_guest_target],
        crate_name = name.replace("-", "_") + "_bindings",
        edition = "2021",
        visibility = visibility,  # Make native bindings publicly available
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
