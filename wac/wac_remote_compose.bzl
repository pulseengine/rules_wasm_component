"""WAC composition rule with remote component support via wkg"""

load("//providers:providers.bzl", "WacCompositionInfo", "WasmComponentInfo")
load("//wkg:defs.bzl", "wkg_fetch")

def _wac_remote_compose_impl(ctx):
    """Implementation of wac_remote_compose rule"""

    # Get toolchains
    wasm_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wkg_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wkg_toolchain_type"]
    wac = wasm_toolchain.wac
    wkg = wkg_toolchain.wkg

    # Output file
    composed_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    # Create a deps directory for WAC to find components
    deps_dir = ctx.actions.declare_directory(ctx.label.name + "_deps")

    # Collect local component files
    local_component_files = []
    local_component_infos = {}

    for comp_target, comp_name in ctx.attr.local_components.items():
        comp_info = comp_target[WasmComponentInfo]
        local_component_files.append(comp_info.wasm_file)
        local_component_infos[comp_name] = comp_info

    # Fetch remote components
    remote_component_files = []
    remote_component_infos = {}

    for comp_name, remote_spec in ctx.attr.remote_components.items():
        # Parse remote component specification
        # Format: "package@version" or "registry/package@version"
        parts = remote_spec.split("@")
        if len(parts) != 2:
            fail("Invalid remote component spec '{}'. Expected format: 'package@version' or 'registry/package@version'".format(remote_spec))

        package = parts[0]
        version = parts[1]

        # Determine registry (default to empty for default registry)
        registry = ""
        if "/" in package and not package.startswith("wasi:"):
            # Handle registry/package format (but not WIT interfaces like wasi:http)
            registry_parts = package.split("/", 1)
            if len(registry_parts) == 2:
                registry = registry_parts[0]
                package = registry_parts[1]

        # Create a unique name for the fetched component
        fetch_name = "{}_remote_{}".format(ctx.label.name, comp_name)

        # Declare the fetched component file
        fetched_component = ctx.actions.declare_file("{}/{}.wasm".format(fetch_name, comp_name))

        # Build wkg fetch command
        args = ctx.actions.args()
        args.add("fetch")
        args.add("--package", package)
        args.add("--version", version)
        if registry:
            args.add("--registry", registry)
        args.add("--output", fetched_component.path)

        # Fetch the remote component
        ctx.actions.run(
            executable = wkg,
            arguments = [args],
            outputs = [fetched_component],
            mnemonic = "WkgFetch",
            progress_message = "Fetching remote component {} from {}".format(comp_name, remote_spec),
        )

        # Create a synthetic WasmComponentInfo for the remote component
        remote_component_infos[comp_name] = struct(
            wasm_file = fetched_component,
            wit_info = None,  # TODO: Extract WIT info from remote component
        )
        remote_component_files.append(fetched_component)

    # Combine local and remote components
    all_components = {}
    all_components.update(local_component_infos)
    all_components.update(remote_component_infos)

    all_component_files = local_component_files + remote_component_files

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
        all_comp_names = {}
        for comp_name in local_component_infos:
            all_comp_names[comp_name] = comp_name
        for comp_name in remote_component_infos:
            all_comp_names[comp_name] = comp_name
        composition_content = _generate_composition(all_comp_names)
        composition_file = ctx.actions.declare_file(ctx.label.name + ".wac")
        ctx.actions.write(
            output = composition_file,
            content = composition_content,
        )

    # Prepare component files for WAC
    selected_components = {}

    # Add local components
    for comp_target, comp_name in ctx.attr.local_components.items():
        comp_info = comp_target[WasmComponentInfo]
        selected_components[comp_name] = {
            "file": comp_info.wasm_file,
            "info": comp_info,
            "profile": ctx.attr.profile,
            "wit_package": _extract_wit_package(comp_info),
        }

    # Add remote components
    for comp_name, comp_info in remote_component_infos.items():
        selected_components[comp_name] = {
            "file": comp_info.wasm_file,
            "info": comp_info,
            "profile": ctx.attr.profile,
            "wit_package": "unknown:package@1.0.0",  # TODO: Extract from remote component
        }

    # Create deps directory structure
    ctx.actions.run(
        executable = ctx.executable._wac_deps_tool,
        arguments = [
            "--output-dir",
            deps_dir.path,
            "--manifest",
            _generate_component_manifest(selected_components),
            "--profile-info",
            _generate_profile_info(selected_components),
            "--use-symlinks",
            str(ctx.attr.use_symlinks).lower(),
        ] + [
            "--component={}={}".format(comp_name, comp_data["file"].path)
            for comp_name, comp_data in selected_components.items()
        ],
        inputs = [comp_data["file"] for comp_data in selected_components.values()],
        outputs = [deps_dir],
        mnemonic = "CreateWacRemoteDeps",
        progress_message = "Creating WAC deps structure with remote components for %s" % ctx.label,
    )

    # Run wac compose
    args = ctx.actions.args()
    args.add("compose")
    args.add("--output", composed_wasm)

    # Use explicit package dependencies
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
        mnemonic = "WacRemoteCompose",
        progress_message = "Composing WASM components with remote dependencies for %s" % ctx.label,
        env = {
            # Disable network access to prevent registry lookups during composition
            "NO_PROXY": "*",
            "no_proxy": "*",
        },
    )

    # Create provider
    composition_info = WacCompositionInfo(
        composed_wasm = composed_wasm,
        components = all_components,
        composition_wit = composition_file,
        instantiations = [],  # TODO: Parse from composition
        connections = [],  # TODO: Parse from composition
    )

    return [
        composition_info,
        DefaultInfo(files = depset([composed_wasm])),
    ]

def _extract_wit_package(comp_info):
    """Extract WIT package name from component info"""
    if hasattr(comp_info, "wit_info") and comp_info.wit_info:
        return comp_info.wit_info.package_name
    return "unknown:package@1.0.0"

def _generate_composition(components):
    """Generate a simple WAC composition from components"""

    lines = []
    lines.append("// Auto-generated WAC composition with remote components")
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
    lines.append("# Component manifest for WAC composition with remote components")
    lines.append("[components]")
    lines.append("")

    for comp_name, comp_data in selected_components.items():
        lines.append("[components.{}]".format(comp_name))
        lines.append("path = \"{}.wasm\"".format(comp_name))
        lines.append("profile = \"{}\"".format(comp_data["profile"]))
        lines.append("wit_package = \"{}\"".format(comp_data["wit_package"]))
        lines.append("")

    return "\n".join(lines)

def _generate_profile_info(selected_components):
    """Generate profile information for debugging"""

    lines = []
    lines.append("# Profile selection information for remote composition")
    lines.append("")

    for comp_name, comp_data in selected_components.items():
        lines.append("{}:".format(comp_name))
        lines.append("  profile: {}".format(comp_data["profile"]))
        lines.append("  file: {}".format(comp_data["file"].path))
        lines.append("")

    return "\n".join(lines)

wac_remote_compose = rule(
    implementation = _wac_remote_compose_impl,
    attrs = {
        "local_components": attr.label_keyed_string_dict(
            providers = [WasmComponentInfo],
            doc = "Local components to compose (name -> target)",
        ),
        "remote_components": attr.string_dict(
            doc = "Remote components to fetch and compose (name -> 'package@version' or 'registry/package@version')",
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
    toolchains = [
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
        "@rules_wasm_component//toolchains:wkg_toolchain_type",
    ],
    doc = """
    Composes WebAssembly components using WAC with support for remote components via wkg.

    This rule extends wac_compose to support fetching remote components from registries
    using wkg before composing them with local components.

    Example:
        wac_remote_compose(
            name = "my_distributed_system",
            local_components = {
                "frontend": ":frontend_component",
            },
            remote_components = {
                "backend": "my-registry/backend@1.2.0",
                "auth": "wasi:auth@0.1.0",
            },
            composition = '''
                let frontend = new frontend:component { ... };
                let backend = new backend:component { ... };
                let auth = new auth:component { ... };

                connect frontend.auth_request -> auth.validate;
                connect frontend.api_request -> backend.handler;

                export frontend as main;
            ''',
        )
    """,
)
