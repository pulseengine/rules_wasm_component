"""Rust WASM component rule implementation"""

load("@rules_rust//rust:defs.bzl", "rust_shared_library")
load("//providers:providers.bzl", "WasmComponentInfo", "WitInfo")
load("//common:common.bzl", "WASM_TARGET_TRIPLE")
load(":transitions.bzl", "wasm_transition")

def _rust_wasm_component_impl(ctx):
    """Implementation of rust_wasm_component rule"""
    
    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = toolchain.wasm_tools
    
    # First compile as cdylib using rules_rust
    # This is handled by the macro below
    
    # Get the compiled WASM module
    wasm_module = ctx.file.wasm_module
    
    # Convert to component if needed
    if ctx.attr.component_type == "module":
        # Already a module, no conversion needed
        component_wasm = wasm_module
    else:
        # Convert module to component
        component_wasm = ctx.actions.declare_file(ctx.label.name + ".component.wasm")
        
        args = ctx.actions.args()
        args.add("component", "new")
        args.add(wasm_module)
        args.add("-o", component_wasm)
        
        # Add adapter if specified
        if ctx.file.adapter:
            args.add("--adapt", ctx.file.adapter)
        
        ctx.actions.run(
            executable = wasm_tools,
            arguments = [args],
            inputs = [wasm_module] + ([ctx.file.adapter] if ctx.file.adapter else []),
            outputs = [component_wasm],
            mnemonic = "WasmComponent",
            progress_message = "Creating WASM component %s" % ctx.label,
        )
    
    # Extract metadata if wit_bindgen was used
    wit_info = None
    imports = []
    exports = []
    
    if ctx.attr.wit_bindgen:
        wit_info = ctx.attr.wit_bindgen[WitInfo]
        # TODO: Parse WIT to extract imports/exports
    
    # Create provider
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = wit_info,
        component_type = "component",
        imports = imports,
        exports = exports,
        metadata = {
            "name": ctx.label.name,
            "target": WASM_TARGET_TRIPLE,
        },
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
        "wit_bindgen": attr.label(
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
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
)

def rust_wasm_component(
        name,
        srcs,
        deps = [],
        wit_bindgen = None,
        adapter = None,
        crate_features = [],
        rustc_flags = [],
        profiles = ["release"],
        visibility = None,
        crate_root = None,
        **kwargs):
    """
    Builds a Rust WebAssembly component.
    
    This macro combines rust_library with WASM component conversion.
    
    Args:
        name: Target name
        srcs: Rust source files
        deps: Rust dependencies
        wit_bindgen: WIT library for binding generation
        adapter: Optional WASI adapter
        crate_features: Rust crate features to enable
        rustc_flags: Additional rustc flags
        profiles: List of build profiles to create ["debug", "release", "custom"]
        visibility: Target visibility
        **kwargs: Additional arguments passed to rust_library
    
    Example:
        rust_wasm_component(
            name = "my_component",
            srcs = ["src/lib.rs"],
            wit_bindgen = "//wit:my_interfaces",
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
        if wit_bindgen:
            # Import wit_bindgen rule at the top of the file
            # This is done via load() at the file level
            pass
        
        # Use rust_shared_library to produce cdylib .wasm files
        rust_shared_library(
            name = rust_library_name,
            srcs = all_srcs,
            crate_root = crate_root,
            deps = all_deps,
            edition = "2021",
            crate_features = crate_features,
            rustc_flags = profile_rustc_flags,
            visibility = ["//visibility:private"],
            tags = ["wasm_component"],  # Tag to identify WASM components
            **kwargs
        )
        
        # Convert to component for this profile
        component_name = "{}_{}".format(name, profile)
        _rust_wasm_component_rule(
            name = component_name,
            wasm_module = ":" + rust_library_name,
            wit_bindgen = wit_bindgen,
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