"""Meld WebAssembly component fusion integration.

Provides the meld_fuse rule for fusing multiple WebAssembly components into
a single core module, eliminating runtime linking overhead. Meld statically
resolves inter-component imports and generates Canonical ABI adapter trampolines.

This is part of the PulseEngine pipeline:
  Build (rules_wasm_component) → Sign (Sigil) → Fuse (Meld) → Optimize (Loom) → Compile (Synth)
"""

load("//providers:providers.bzl", "MeldFusedInfo", "WasmComponentInfo")

def _get_component_files(dep):
    """Extract .wasm files from a dependency.

    Checks for WasmComponentInfo first (from rules_wasm_component targets),
    then falls back to scanning DefaultInfo for .wasm files.

    Args:
        dep: A target dependency.

    Returns:
        List of .wasm File objects.
    """
    if WasmComponentInfo in dep:
        return [dep[WasmComponentInfo].wasm_file]

    # Fallback: scan default outputs for .wasm files
    wasm_files = []
    for f in dep[DefaultInfo].files.to_list():
        if f.extension == "wasm":
            wasm_files.append(f)
    return wasm_files

def _meld_fuse_impl(ctx):
    """Implementation of meld_fuse rule."""
    output_wasm = ctx.actions.declare_file(ctx.attr.out or (ctx.label.name + ".wasm"))

    # Resolve meld binary via toolchain
    meld_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:meld_toolchain_type"]
    meld = meld_toolchain.meld

    # Collect all component .wasm files
    component_files = []
    for dep in ctx.attr.components:
        files = _get_component_files(dep)
        if not files:
            fail("Target '{}' does not produce any .wasm files".format(dep.label))
        component_files.extend(files)

    if len(component_files) < 1:
        fail("meld_fuse requires at least one component")

    # Build command: meld fuse <components...> -o <output> [flags]
    args = ctx.actions.args()
    args.add("fuse")
    args.add_all(component_files)
    args.add("-o", output_wasm)
    args.add("--memory", ctx.attr.memory_strategy)

    if not ctx.attr.attestation:
        args.add("--no-attestation")

    if ctx.attr.preserve_names:
        args.add("--preserve-names")

    if ctx.attr.stats:
        args.add("--stats")

    if ctx.attr.validate:
        args.add("--validate")

    ctx.actions.run(
        inputs = component_files,
        outputs = [output_wasm],
        executable = meld,
        arguments = [args],
        mnemonic = "MeldFuse",
        progress_message = "Fusing %d components into %s" % (len(component_files), output_wasm.short_path),
        tools = [meld],
    )

    return [
        DefaultInfo(
            files = depset([output_wasm]),
        ),
        OutputGroupInfo(
            wasm = depset([output_wasm]),
        ),
        MeldFusedInfo(
            fused_wasm = output_wasm,
            source_components = depset(component_files),
            memory_strategy = ctx.attr.memory_strategy,
            component_count = len(component_files),
        ),
    ]

meld_fuse = rule(
    implementation = _meld_fuse_impl,
    attrs = {
        "components": attr.label_list(
            doc = "WebAssembly component targets to fuse into a single core module",
            mandatory = True,
            allow_files = [".wasm"],
        ),
        "out": attr.string(
            doc = "Output filename (defaults to {name}.wasm)",
        ),
        "memory_strategy": attr.string(
            doc = """Memory isolation strategy.
- "multi": Each component keeps its own linear memory (default, recommended)
- "shared": Single shared linear memory (required for Synth Cortex-M target)""",
            default = "multi",
            values = ["multi", "shared"],
        ),
        "attestation": attr.bool(
            doc = "Embed transformation attestation recording fusion provenance",
            default = True,
        ),
        "preserve_names": attr.bool(
            doc = "Preserve debug names in the fused output module",
            default = False,
        ),
        "stats": attr.bool(
            doc = "Print fusion statistics (components fused, adapters generated, size reduction)",
            default = False,
        ),
        "validate": attr.bool(
            doc = "Validate the fused output with wasmparser",
            default = False,
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:meld_toolchain_type"],
    doc = """Fuse multiple WebAssembly components into a single core module using Meld.

Static fusion eliminates runtime linking by resolving all inter-component imports
at build time and generating Canonical ABI adapter trampolines. The output is a
core WebAssembly module (not a component) suitable for optimization with Loom and
ahead-of-time compilation with Synth.

Pipeline position:
  rust_wasm_component → wasm_sign → meld_fuse → wasm_optimize → synth_compile

The fused module embeds a transformation attestation (via Sigil's wsc-attestation
format) recording input component hashes, fusion configuration, and tool version.
Downstream tools (Loom) preserve this custom section through the pipeline.

Memory strategies:
- "multi" (default): Each source component retains its own linear memory. Safer
  isolation, but requires multi-memory support in the runtime.
- "shared": All components share a single linear memory with rebased addresses.
  Required when targeting Synth's Cortex-M backend (single address space).

Example:
    load("@rules_wasm_component//wasm:defs.bzl", "meld_fuse")

    meld_fuse(
        name = "fused_system",
        components = [
            ":auth_service",
            ":user_service",
            ":api_gateway",
        ],
        memory_strategy = "multi",
        attestation = True,
    )
""",
)
