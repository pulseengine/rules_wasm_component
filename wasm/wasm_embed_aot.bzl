"""Embed AOT-compiled WebAssembly components as custom sections using hermetic Rust component"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmPrecompiledInfo")

def _wasm_embed_aot_impl(ctx):
    """Implementation of wasm_embed_aot rule"""

    # Get input component
    if ctx.attr.component:
        component_info = ctx.attr.component[WasmComponentInfo]
        input_wasm = component_info.wasm_file
        source_info = component_info
    else:
        fail("component must be specified")

    # Collect all precompiled artifacts
    precompiled_files = {}
    for target_name, precompiled_target in ctx.attr.aot_artifacts.items():
        precompiled_info = precompiled_target[WasmPrecompiledInfo]
        precompiled_files[target_name] = precompiled_info.cwasm_file

    # Output enhanced WASM file
    output_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    # Get the hermetic Rust CLI tool
    embed_tool = ctx.executable._embed_tool

    # Build arguments for the embedding tool
    args = ctx.actions.args()
    args.add("embed")
    args.add("--input")
    args.add(input_wasm)
    args.add("--output")
    args.add(output_wasm)

    inputs = [input_wasm]
    for target_name, cwasm_file in precompiled_files.items():
        args.add("{}:{}".format(target_name, cwasm_file.path))
        inputs.append(cwasm_file)

    # Run the embedding process
    ctx.actions.run(
        executable = embed_tool,
        arguments = [args],
        inputs = inputs,
        outputs = [output_wasm],
        mnemonic = "WasmEmbedAOT",
        progress_message = "Embedding AOT artifacts into WASM component {}".format(ctx.label),
        use_default_shell_env = False,
    )

    # Create enhanced component info
    enhanced_component_info = WasmComponentInfo(
        wasm_file = output_wasm,
        wit_info = component_info.wit_info,
        component_type = component_info.component_type,
        imports = component_info.imports,
        exports = component_info.exports,
        metadata = dict(
            component_info.metadata,
            aot_embedded = True,
            aot_targets = list(precompiled_files.keys()),
        ),
        profile = component_info.profile,
        profile_variants = component_info.profile_variants,
    )

    return [
        enhanced_component_info,
        DefaultInfo(files = depset([output_wasm])),
    ]

wasm_embed_aot = rule(
    implementation = _wasm_embed_aot_impl,
    attrs = {
        "component": attr.label(
            providers = [WasmComponentInfo],
            mandatory = True,
            doc = "Base WebAssembly component to embed AOT artifacts into",
        ),
        "aot_artifacts": attr.string_keyed_label_dict(
            providers = [WasmPrecompiledInfo],
            mandatory = True,
            doc = "Dictionary mapping target names to precompiled AOT artifacts",
        ),
        "_embed_tool": attr.label(
            default = "//tools/wasm_embed_aot:wasm_embed_aot",
            executable = True,
            cfg = "exec",
            doc = "Hermetic Rust CLI tool for AOT embedding operations",
        ),
    },
    toolchains = [],
    doc = """
    Embed AOT-compiled WebAssembly artifacts as custom sections in a component.

    This rule takes a WebAssembly component and embeds multiple AOT-compiled
    versions (.cwasm files) as custom sections. The resulting component can
    be signed normally with wasmsign2, and runtime code can extract the
    appropriate AOT artifact for the current architecture.

    Example:
        wasm_embed_aot(
            name = "component_with_aot",
            component = ":my_component",
            aot_artifacts = {
                "linux-x64": ":my_component_x64",
                "linux-arm64": ":my_component_arm64",
                "portable": ":my_component_pulley",
            },
        )

    The embedded custom sections will be named:
        - "aot-linux-x64"
        - "aot-linux-arm64"
        - "aot-portable"
    """,
)

def _wasm_extract_aot_impl(ctx):
    """Implementation of wasm_extract_aot rule for runtime extraction"""

    # Get input component with embedded AOT
    input_wasm = ctx.file.component
    section_name = "aot-{}".format(ctx.attr.target_name)

    # Output extracted .cwasm file
    output_cwasm = ctx.actions.declare_file(ctx.label.name + ".cwasm")

    # Get the hermetic Rust CLI tool
    extract_tool = ctx.executable._extract_tool

    # Build arguments for the extraction tool
    args = ctx.actions.args()
    args.add("extract")
    args.add("--input")
    args.add(input_wasm)
    args.add("--output")
    args.add(output_cwasm)
    args.add("--section")
    args.add(section_name)

    # Run the extraction process
    ctx.actions.run(
        executable = extract_tool,
        arguments = [args],
        inputs = [input_wasm],
        outputs = [output_cwasm],
        mnemonic = "WasmExtractAOT",
        progress_message = "Extracting AOT artifact {} from WASM component".format(ctx.attr.target_name),
        use_default_shell_env = False,
    )

    return [
        DefaultInfo(files = depset([output_cwasm])),
    ]

wasm_extract_aot = rule(
    implementation = _wasm_extract_aot_impl,
    attrs = {
        "component": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "WebAssembly component with embedded AOT artifacts",
        ),
        "target_name": attr.string(
            mandatory = True,
            doc = "Target architecture name to extract (e.g., 'linux-x64')",
        ),
        "_extract_tool": attr.label(
            default = "//tools/wasm_embed_aot:wasm_embed_aot",
            executable = True,
            cfg = "exec",
            doc = "Hermetic Rust CLI tool for AOT extraction operations",
        ),
    },
    toolchains = [],
    doc = """
    Extract an AOT-compiled artifact from a WebAssembly component.

    This rule extracts a specific AOT artifact that was previously embedded
    as a custom section, allowing runtime code to access the appropriate
    compiled version for the current architecture.

    Example:
        wasm_extract_aot(
            name = "extracted_aot",
            component = ":component_with_aot.wasm",
            target_name = "linux-x64",
        )
    """,
)
