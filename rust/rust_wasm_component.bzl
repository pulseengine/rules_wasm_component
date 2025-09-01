"""Rust WASM component rule implementation"""

load("@rules_rust//rust:defs.bzl", "rust_shared_library")
load("//common:common.bzl", "WASM_TARGET_TRIPLE")
load("//providers:providers.bzl", "WasmComponentInfo", "WitInfo")
load("//tools/bazel_helpers:wasm_tools_actions.bzl", "check_is_component_action")
load(":transitions.bzl", "wasm_transition")

def _wasm_rust_shared_library_impl(ctx):
    """Implementation that forwards a rust_shared_library with WASM transition applied"""
    target_info = ctx.attr.target[0]

    # Forward DefaultInfo and RustInfo
    providers = [target_info[DefaultInfo]]

    # Forward RustInfo if available
    if hasattr(target_info, "rust_info"):
        providers.append(target_info.rust_info)

    return providers

_wasm_rust_shared_library = rule(
    implementation = _wasm_rust_shared_library_impl,
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

    # Optional WIT validation
    validation_outputs = []
    if ctx.attr.validate_wit and ctx.attr.wit:
        wasm_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
        wasm_tools = wasm_toolchain.wasm_tools
        
        validation_log = ctx.actions.declare_file(ctx.attr.name + "_wit_validation.log")
        validation_outputs.append(validation_log)

        # Get WIT file from the wit library target
        wit_files = ctx.attr.wit[WitInfo].wit_files
        wit_file = wit_files.to_list()[0] if wit_files else None
        
        if wit_file:
            # Validate component with proper wasm-tools validate command
            ctx.actions.run_shell(
                command = '''
                # Validate component with component model features  
                "$1" validate --features component-model "$2" 2>&1
                if [ $? -ne 0 ]; then
                    echo "ERROR: Component validation failed for $2" > "$3"
                    "$1" validate --features component-model "$2" >> "$3" 2>&1
                    exit 1
                fi
                
                # Extract component WIT interface
                "$1" component wit "$2" > "$3.component" 2>&1
                if [ $? -ne 0 ]; then
                    echo "ERROR: Failed to extract component WIT interface" >> "$3"
                    cat "$3.component" >> "$3"
                    exit 1
                fi
                
                # Create validation report with comparison
                echo "=== COMPONENT VALIDATION PASSED ===" > "$3"
                echo "Component is valid WebAssembly with component model" >> "$3"
                echo "" >> "$3"
                echo "=== COMPONENT WIT INTERFACE ===" >> "$3"
                cat "$3.component" >> "$3"
                echo "" >> "$3"
                echo "=== EXPECTED WIT SPECIFICATION ===" >> "$3"
                cat "$4" >> "$3"
                echo "" >> "$3"
                echo "WIT validation completed - manual comparison required" >> "$3"
                echo "Future enhancement: automated interface compliance checking" >> "$3"
                ''',
                arguments = [wasm_tools.path, component_wasm.path, validation_log.path, wit_file.path],
                inputs = [component_wasm, wit_file],
                outputs = [validation_log],
                tools = [wasm_tools],
                mnemonic = "ValidateWasmComponent", 
                progress_message = "Validating WebAssembly component for %s" % ctx.label,
            )
        else:
            # No WIT file available - just validate component
            ctx.actions.run_shell(
                command = '''
                # Validate component with component model features
                "$1" validate --features component-model "$2" 2>&1
                if [ $? -ne 0 ]; then
                    echo "ERROR: Component validation failed for $2" > "$3"
                    "$1" validate --features component-model "$2" >> "$3" 2>&1
                    exit 1
                fi
                
                echo "=== COMPONENT VALIDATION PASSED ===" > "$3"
                echo "Component is valid WebAssembly with component model" >> "$3"
                echo "" >> "$3"
                echo "=== EXPORTED WIT INTERFACE ===" >> "$3"
                "$1" component wit "$2" >> "$3" 2>&1 || echo "Failed to extract WIT interface" >> "$3"
                ''',
                arguments = [wasm_tools.path, component_wasm.path, validation_log.path],
                inputs = [component_wasm],
                outputs = [validation_log],
                tools = [wasm_tools],
                mnemonic = "ValidateWasmComponent",
                progress_message = "Validating WebAssembly component for %s" % ctx.label,
            )

    return [
        component_info,
        DefaultInfo(files = depset([component_wasm] + validation_outputs)),
        OutputGroupInfo(
            validation = depset(validation_outputs),
        ) if validation_outputs else OutputGroupInfo(),
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
        "validate_wit": attr.bool(
            default = False,
            doc = "Validate that the component exports match the WIT specification",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:wasm_tools_component_toolchain_type",
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
    ],
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
        validate_wit = False,
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

        # Create separate dependency lists for host and WASM targets
        # Host targets need _bindings_host, WASM targets need _bindings
        host_deps = []
        wasm_deps = []

        for dep in deps:
            if dep.endswith("_bindings"):
                # This is a WIT bindings dependency, use appropriate version
                host_deps.append(dep + "_host")
                wasm_deps.append(dep)
            else:
                # Regular dependency, use for both
                host_deps.append(dep)
                wasm_deps.append(dep)

        # Generate WIT bindings before building the rust library
        if wit:
            # Import wit_bindgen rule at the top of the file
            # This is done via load() at the file level
            pass

        # Use rust_shared_library to produce cdylib .wasm files
        # Add WASI SDK tools as data dependencies to ensure they're available

        # Filter out conflicting kwargs to avoid multiple values for parameters
        filtered_kwargs = {k: v for k, v in kwargs.items() if k not in ["tags", "visibility"]}

        # Create the host-platform rust_shared_library first
        host_library_name = rust_library_name + "_host"
        rust_shared_library(
            name = host_library_name,
            srcs = all_srcs,
            crate_root = crate_root,
            deps = host_deps,
            edition = edition,
            crate_features = crate_features,
            rustc_flags = profile_rustc_flags,
            visibility = ["//visibility:private"],
            tags = ["wasm_component"],  # Tag to identify WASM components
            **filtered_kwargs
        )

        # Create a separate WASM library that uses base dependencies (not transitioned yet)
        # The transition will be applied to both this target and its dependencies together
        wasm_library_base_name = rust_library_name + "_wasm_base"

        # For the base target, use dependencies that haven't been transitioned yet
        wasm_base_deps = []
        for dep in deps:
            if dep.endswith("_bindings"):
                # Use the base bindings library (not transitioned) that will be transitioned together
                wasm_base_deps.append(dep + "_wasm_base")
            else:
                # Regular dependency, use as-is
                wasm_base_deps.append(dep)

        rust_shared_library(
            name = wasm_library_base_name,
            srcs = all_srcs,
            crate_root = crate_root,
            deps = wasm_base_deps,
            edition = edition,
            crate_features = crate_features,
            rustc_flags = profile_rustc_flags,
            visibility = ["//visibility:private"],
            tags = ["manual"],  # Manual tag prevents inclusion in wildcard builds
            **filtered_kwargs
        )

        # Apply WASM transition to get actual WASM module
        _wasm_rust_shared_library(
            name = rust_library_name,
            target = ":" + wasm_library_base_name,
        )

        # Convert to component for this profile
        component_name = "{}_{}".format(name, profile)
        _rust_wasm_component_rule(
            name = component_name,
            wasm_module = ":" + rust_library_name,
            wit = wit,
            adapter = adapter,
            component_type = "component",
            validate_wit = validate_wit,
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
