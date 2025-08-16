"""Rust WASM component rule implementation"""

load("@rules_rust//rust:defs.bzl", "rust_shared_library")
load("//providers:providers.bzl", "WasmComponentInfo", "WitInfo")
load("//common:common.bzl", "WASM_TARGET_TRIPLE")
load(":transitions.bzl", "wasm_transition")
load("//tools/bazel_helpers:wasm_tools_actions.bzl", "check_is_component_action", "create_component_action")

def _rust_wasm_component_impl(ctx):
    """Implementation of rust_wasm_component rule"""

    # Get the compiled WASM module
    wasm_module = ctx.file.wasm_module

    # Convert to component if needed
    if ctx.attr.component_type == "module":
        # Already a module, no conversion needed
        component_wasm = wasm_module
    else:
        # Detect if the WASM module is already a component using WASM Tools Integration Component
        component_check_result = check_is_component_action(ctx, wasm_module)

        # For wasm32-wasip2 targets, the output is already a component
        # We can skip conversion by directly using the input
        component_wasm = wasm_module

    # Extract metadata if wit was used
    wit_info = None
    imports = []
    exports = []

    if ctx.attr.wit:
        wit_info = ctx.attr.wit[WitInfo]
        # TODO: Parse WIT to extract imports/exports
        # Future: Use wit-parser or wasm-tools to extract interface definitions
        # imports = parse_wit_imports(wit_info.wit_files)
        # exports = parse_wit_exports(wit_info.wit_files)

    # Create provider
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = wit_info,
        component_type = "component",
        imports = imports,
        exports = exports,
        metadata = {
            "name": ctx.label.name,
            "language": "rust",
            "target": WASM_TARGET_TRIPLE,
        },
        profile = "release",  # Default Rust profile
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(files = depset([component_wasm])),
    ]

_rust_wasm_component_rule = rule(
    implementation = _rust_wasm_component_impl,
    attrs = {
        "wasm_module": attr.label(
            allow_single_file = [".wasm", ".dylib", ".so", ".dll"],
            mandatory = True,
            cfg = wasm_transition,
            doc = "Compiled WASM module from rust_library",
        ),
        "wit": attr.label(
            providers = [WitInfo],
            doc = "WIT library for binding generation",
        ),
        "adapter": attr.label(
            allow_single_file = [".wasm"],
            doc = "WASI adapter module",
        ),
        "component_type": attr.string(
            values = ["module", "component"],
            default = "component",
            doc = "Output type (module or component)",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_component_toolchain_type"],
)

def rust_wasm_component(
        name,
        srcs,
        deps = [],
        wit = None,
        adapter = None,
        crate_features = [],
        rustc_flags = [],
        profiles = ["release"],
        visibility = None,
        crate_root = None,
        edition = "2021",
        **kwargs):
    """
    Builds a Rust WebAssembly component.

    This macro combines rust_library with WASM component conversion.

    Args:
        name: Target name
        srcs: Rust source files
        deps: Rust dependencies
        wit: WIT library for binding generation
        adapter: Optional WASI adapter
        crate_features: Rust crate features to enable
        rustc_flags: Additional rustc flags
        profiles: List of build profiles to create ["debug", "release", "custom"]
        visibility: Target visibility
        edition: Rust edition (default: "2021")
        **kwargs: Additional arguments passed to rust_library

    Example:
        rust_wasm_component(
            name = "my_component",
            srcs = ["src/lib.rs"],
            wit = "//wit:my_interfaces",
            profiles = ["debug", "release"],  # Build both variants
            deps = [
                "@crates//:serde",
            ],
        )
    """

    # Profile configurations
    profile_configs = {
        "debug": {
            "opt_level": "1",
            "debug": True,
            "strip": False,
            "rustc_flags": [],
        },
        "release": {
            "opt_level": "s",  # Optimize for size
            "debug": False,
            "strip": True,
            "rustc_flags": [],  # LTO conflicts with embed-bitcode=no
        },
        "custom": {
            "opt_level": "2",
            "debug": True,
            "strip": False,
            "rustc_flags": [],
        },
    }

    # Build components for each profile
    profile_variants = {}
    for profile in profiles:
        config = profile_configs.get(profile, profile_configs["release"])

        # Build the Rust library as cdylib for this profile
        rust_library_name = "{}_wasm_lib_{}".format(name, profile)

        profile_rustc_flags = rustc_flags + config["rustc_flags"]

        # Add wit-bindgen generated code if specified
        all_srcs = list(srcs)
        all_deps = list(deps)

        # Generate WIT bindings before building the rust library
        if wit:
            # Import wit_bindgen rule at the top of the file
            # This is done via load() at the file level
            pass

        # Use rust_shared_library to produce cdylib .wasm files
        # Add WASI SDK tools as data dependencies to ensure they're available

        # Filter out conflicting kwargs to avoid multiple values for parameters
        filtered_kwargs = {k: v for k, v in kwargs.items() if k not in ["tags", "visibility"]}

        rust_shared_library(
            name = rust_library_name,
            srcs = all_srcs,
            crate_root = crate_root,
            deps = all_deps,
            edition = edition,
            crate_features = crate_features,
            rustc_flags = profile_rustc_flags,
            visibility = ["//visibility:private"],
            tags = ["wasm_component"],  # Tag to identify WASM components
            **filtered_kwargs
        )

        # Convert to component for this profile
        component_name = "{}_{}".format(name, profile)
        _rust_wasm_component_rule(
            name = component_name,
            wasm_module = ":" + rust_library_name,
            wit = wit,
            adapter = adapter,
            component_type = "component",
            visibility = ["//visibility:private"],
        )

        profile_variants[profile] = ":" + component_name

    # Create the main component (default to release profile) that provides WasmComponentInfo
    main_profile = "release" if "release" in profiles else profiles[0]
    native.alias(
        name = name,
        actual = profile_variants[main_profile],
        visibility = visibility,
    )

    # Create a filegroup that includes all profiles for those who need it
    native.filegroup(
        name = name + "_all_profiles",
        srcs = [profile_variants[p] for p in profiles],
        visibility = visibility,
    )
