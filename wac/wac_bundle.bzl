"""WAC bundle rule for collecting WASI components without composition"""

load("//providers:providers.bzl", "WacCompositionInfo")

def _wac_bundle_impl(ctx):
    """Bundle components without composition, suitable for WASI components"""

    # Output directory containing all components
    bundle_dir = ctx.actions.declare_directory(ctx.attr.name + "_bundle")

    # Collect component files
    component_files = []
    component_infos = {}

    for comp_target, comp_name in ctx.attr.components.items():
        files = comp_target[DefaultInfo].files.to_list()
        wasm_files = [f for f in files if f.path.endswith(".wasm")]
        if not wasm_files:
            fail("Component target %s must provide .wasm files" % comp_target.label)

        component_file = wasm_files[0]  # Use first .wasm file
        component_files.append(component_file)
        component_infos[comp_name] = comp_target

    # Create bundle directory with all components
    args = ctx.actions.args()
    args.add("--output-dir", bundle_dir.path)
    args.add("--bundle-mode", "true")  # Just copy files, don't create manifest
    args.add_all([
        "--component={}={}".format(comp_name, comp_file.path)
        for (comp_target, comp_name), comp_file in zip(ctx.attr.components.items(), component_files)
    ])

    ctx.actions.run(
        executable = ctx.executable._wac_deps_tool,
        arguments = [args],
        inputs = component_files,
        outputs = [bundle_dir],
        mnemonic = "WacBundle",
        progress_message = "Bundling WASM components for %s" % ctx.label,
    )

    # Return provider without composed component
    bundle_info = WacCompositionInfo(
        composed_wasm = None,  # No single composed file
        components = component_infos,
        composition_wit = None,
        instantiations = [],
        connections = [],
    )

    return [
        bundle_info,
        DefaultInfo(files = depset([bundle_dir])),
    ]

wac_bundle = rule(
    implementation = _wac_bundle_impl,
    attrs = {
        "components": attr.label_keyed_string_dict(
            doc = "Map of component targets to their names in the bundle",
            mandatory = True,
        ),
        "_wac_deps_tool": attr.label(
            default = "//tools/wac_deps",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Bundle WASM components without composition, suitable for WASI components",
)
