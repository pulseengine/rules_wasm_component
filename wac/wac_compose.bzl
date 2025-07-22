"""WAC composition rule implementation"""

load("//providers:providers.bzl", "WacCompositionInfo", "WasmComponentInfo")

def _wac_compose_impl(ctx):
    """Implementation of wac_compose rule"""

    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wac = toolchain.wac

    # Output file
    composed_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    # Create a deps directory for WAC to find components
    deps_dir = ctx.actions.declare_directory(ctx.label.name + "_deps")

    # Collect component files
    component_files = []
    component_infos = {}

    for comp_target, comp_name in ctx.attr.components.items():
        comp_info = comp_target[WasmComponentInfo]
        component_files.append(comp_info.wasm_file)
        component_infos[comp_name] = comp_info

    # Create composition file
    if ctx.attr.composition:
        # Inline composition
        composition_content = ctx.attr.composition
        composition_file = ctx.actions.declare_file(ctx.label.name + ".wac")
        ctx.actions.write(
            output = composition_file,
            content = composition_content,
        )
    elif ctx.file.composition_file:
        # External composition file - use it directly
        composition_file = ctx.file.composition_file
    else:
        # Auto-generate simple composition
        composition_content = _generate_composition(ctx.attr.components)
        composition_file = ctx.actions.declare_file(ctx.label.name + ".wac")
        ctx.actions.write(
            output = composition_file,
            content = composition_content,
        )

    # Prepare component files with profile selection
    selected_components = {}
    for comp_target, comp_name in ctx.attr.components.items():
        # Determine which profile to use for this component
        profile = ctx.attr.component_profiles.get(comp_name, ctx.attr.profile)

        # Get the component info
        comp_info = comp_target[WasmComponentInfo]

        # Select the appropriate profile variant if available
        if hasattr(comp_info, "profile_variants") and comp_info.profile_variants:
            if profile in comp_info.profile_variants:
                # Use specific profile variant
                selected_file = comp_info.profile_variants[profile]
            else:
                # Fallback to main component file
                selected_file = comp_info.wasm_file
        else:
            # Single profile component
            selected_file = comp_info.wasm_file

        # Extract WIT package name from component
        wit_package = "unknown:package@1.0.0"
        if hasattr(comp_info, "wit_info") and comp_info.wit_info:
            wit_package = comp_info.wit_info.package_name

        selected_components[comp_name] = {
            "file": selected_file,
            "info": comp_info,
            "profile": profile,
            "wit_package": wit_package,
        }

    # Use a Go tool to create the deps directory structure properly
    ctx.actions.run(
        executable = ctx.executable._wac_deps_tool,
        arguments = [
            "--output-dir", deps_dir.path,
            "--manifest", _generate_component_manifest(selected_components),
            "--profile-info", _generate_profile_info(selected_components),
            "--use-symlinks", str(ctx.attr.use_symlinks).lower(),
        ] + [
            "--component={}={}".format(comp_name, comp_data["file"].path)
            for comp_name, comp_data in selected_components.items()
        ],
        inputs = [comp_data["file"] for comp_data in selected_components.values()],
        outputs = [deps_dir],
        mnemonic = "CreateWacDeps",
        progress_message = "Creating WAC deps structure for %s" % ctx.label,
    )

    # Run wac compose  
    args = ctx.actions.args()
    args.add("compose")
    args.add("--output", composed_wasm)
    
    # Use ONLY explicit package dependencies to avoid any registry lookups
    # Don't use --deps-dir to avoid triggering registry resolver
    # IMPORTANT: Use package names WITHOUT version for --dep overrides
    # because WAC filesystem resolver only uses overrides when key.version.is_none()
    for comp_name, comp_data in selected_components.items():
        wit_package = comp_data.get("wit_package", "unknown:package@1.0.0")
        # Remove version from package name for --dep override
        package_name_no_version = wit_package.split("@")[0] if "@" in wit_package else wit_package
        args.add("--dep", "{}={}".format(package_name_no_version, comp_data["file"].path))
    
    # Essential flags for local-only composition
    args.add("--no-validate")  # Skip validation that might trigger registry
    args.add("--import-dependencies")  # Allow WASI imports instead of requiring them as args
    args.add(composition_file)

    ctx.actions.run(
        executable = wac,
        arguments = [args],
        inputs = [composition_file] + [comp_data["file"] for comp_data in selected_components.values()],
        outputs = [composed_wasm],
        mnemonic = "WacCompose",
        progress_message = "Composing WASM components for %s" % ctx.label,
        env = {
            # Disable network access to prevent registry lookups
            "NO_PROXY": "*",
            "no_proxy": "*",
        },
    )

    # Create provider
    composition_info = WacCompositionInfo(
        composed_wasm = composed_wasm,
        components = component_infos,
        composition_wit = composition_file,
        instantiations = [],  # TODO: Parse from composition
        connections = [],  # TODO: Parse from composition
    )

    return [
        composition_info,
        DefaultInfo(files = depset([composed_wasm])),
    ]

def _generate_composition(components):
    """Generate a simple WAC composition from components"""

    lines = []
    lines.append("// Auto-generated WAC composition")
    lines.append("// Uses ... syntax to allow WASI import pass-through")
    lines.append("")

    # Instantiate components with ... to allow missing WASI imports
    for comp_name in components:
        lines.append("let {} = new {}:component {{ ... }};".format(comp_name, comp_name))

    lines.append("")

    # Export first component as main
    if components:
        # Get first key from dict (Starlark doesn't have next/iter)
        first_comp = None
        for key in components:
            first_comp = key
            break
        if first_comp:
            lines.append("export {} as main;".format(first_comp))

    return "\n".join(lines)

def _generate_component_manifest(selected_components):
    """Generate component manifest for WAC"""

    lines = []
    lines.append("# Component manifest for WAC composition")
    lines.append("[components]")
    lines.append("")

    for comp_name, comp_data in selected_components.items():
        lines.append("[components.{}]".format(comp_name))
        lines.append("path = \"{}.wasm\"".format(comp_name))
        lines.append("profile = \"{}\"".format(comp_data["profile"]))
        if comp_data["info"].wit_info:
            lines.append("wit_package = \"{}\"".format(comp_data["info"].wit_info.package_name))
        lines.append("")

    return "\n".join(lines)

def _generate_profile_info(selected_components):
    """Generate profile information for debugging"""

    lines = []
    lines.append("# Profile selection information")
    lines.append("")

    for comp_name, comp_data in selected_components.items():
        lines.append("{}:".format(comp_name))
        lines.append("  profile: {}".format(comp_data["profile"]))
        lines.append("  file: {}".format(comp_data["file"].path))
        lines.append("")

    return "\n".join(lines)

wac_compose = rule(
    implementation = _wac_compose_impl,
    attrs = {
        "components": attr.label_keyed_string_dict(
            providers = [WasmComponentInfo],
            mandatory = True,
            doc = "Components to compose (name -> target)",
        ),
        "composition": attr.string(
            doc = "Inline WAC composition code",
        ),
        "composition_file": attr.label(
            allow_single_file = [".wac"],
            doc = "External WAC composition file",
        ),
        "profile": attr.string(
            default = "release",
            doc = "Build profile to use for composition (debug, release, custom)",
        ),
        "component_profiles": attr.string_dict(
            doc = "Per-component profile overrides (component_name -> profile)",
        ),
        "use_symlinks": attr.bool(
            default = True,
            doc = "Use symlinks instead of copying files to save space",
        ),
        "_wac_deps_tool": attr.label(
            default = "//tools/wac_deps",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
    Composes multiple WebAssembly components using WAC with profile support.
    
    This rule uses the WebAssembly Composition (WAC) tool to combine
    multiple WASM components into a single composed component, with support
    for different build profiles and memory-efficient symlinks.
    
    Example:
        wac_compose(
            name = "my_system",
            components = {
                "frontend": ":frontend_component",
                "backend": ":backend_component",
            },
            profile = "release",                    # Default profile
            component_profiles = {                  # Per-component overrides
                "frontend": "debug",                # Use debug build for frontend
            },
            composition = '''
                let frontend = new frontend:component { ... };
                let backend = new backend:component { ... };
                
                connect frontend.request -> backend.handler;
                
                export frontend as main;
            ''',
        )
    """,
)
