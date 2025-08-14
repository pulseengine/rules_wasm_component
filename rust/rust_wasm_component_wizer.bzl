"""Rust WebAssembly component with Wizer pre-initialization"""

load("@rules_rust//rust:defs.bzl", "rust_shared_library")
load("//rust:rust_wasm_component.bzl", "rust_wasm_component")
load("//wasm:wasm_component_wizer.bzl", "wizer_chain")

def rust_wasm_component_wizer(
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
        edition = "2021",
        init_function_name = "wizer.initialize",
        **kwargs):
    """
    Builds a Rust WebAssembly component with Wizer pre-initialization.

    This macro combines rust_library with Wizer pre-initialization and WASM component conversion.
    The workflow is: Rust → WASM module → Wizer → WASM component

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
        crate_root: Rust crate root file
        edition: Rust edition (default: "2021")
        init_function_name: Wizer initialization function name (default: "wizer.initialize")
        **kwargs: Additional arguments passed to rust_library

    Example:
        rust_wasm_component_wizer(
            name = "my_optimized_component",
            srcs = ["src/lib.rs"],
            wit_bindgen = "//wit:my_interfaces",
            init_function_name = "wizer.initialize",
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
            "opt_level": "3",
            "debug": False,
            "strip": True,
            "rustc_flags": [],
        },
        "custom": {
            "opt_level": "2",
            "debug": False,
            "strip": False,
            "rustc_flags": [],  # LTO conflicts with embed-bitcode=no
        },
    }

    # Create targets for each profile
    for profile in profiles:
        if profile not in profile_configs:
            fail("Unknown profile: {}. Supported profiles: {}".format(
                profile,
                list(profile_configs.keys()),
            ))

        config = profile_configs[profile]
        profile_rustc_flags = rustc_flags + config["rustc_flags"]

        # Add WIT bindgen generated code if specified
        all_srcs = list(srcs)
        all_deps = list(deps)

        # Generate WIT bindings before building the rust library
        if wit_bindgen:
            # Import wit_bindgen rule at the top of the file
            # This is done via load() at the file level
            pass

        # Step 1: Create the regular WASM component
        component_name = "{}_component_{}".format(name, profile)
        
        # Filter out conflicting kwargs
        filtered_kwargs = {k: v for k, v in kwargs.items() if k != "tags"}
        
        rust_wasm_component(
            name = component_name,
            srcs = all_srcs,
            crate_root = crate_root,
            deps = all_deps,
            edition = edition,
            crate_features = crate_features,
            rustc_flags = profile_rustc_flags,
            wit_bindgen = wit_bindgen,
            adapter = adapter,
            visibility = ["//visibility:private"],
            tags = ["wasm_component"],
            **filtered_kwargs
        )

        # Step 2: Apply Wizer pre-initialization to the component
        wizer_component_name = "{}_{}".format(name, profile)
        wizer_chain(
            name = wizer_component_name,
            component = ":" + component_name,
            init_function_name = init_function_name,
            visibility = ["//visibility:private"],
        )

    # Create aliases for the default profile
    default_profile = profiles[0] if profiles else "release"

    # Main component alias (points to default profile)
    native.alias(
        name = name,
        actual = ":{}_{}".format(name, default_profile),
        visibility = visibility,
    )

    # Profile-specific aliases for easy access
    if len(profiles) > 1:
        native.alias(
            name = "{}_all_profiles".format(name),
            actual = ":{}_{}".format(name, profiles[0]),  # Points to first profile
            visibility = visibility,
        )
