"""Synth WebAssembly-to-ARM ahead-of-time compiler integration.

Provides the synth_compile rule for compiling WebAssembly modules to ARM Cortex-M
ELF binaries. Synth performs instruction selection, register allocation, and
generates bare-metal firmware suitable for safety-critical embedded systems.

This is the final compilation stage in the PulseEngine pipeline:
  Build (rules_wasm_component) → Sign (Sigil) → Fuse (Meld) → Optimize (Loom) → Compile (Synth)
"""

load("//providers:providers.bzl", "MeldFusedInfo", "SynthCompiledInfo")

def _synth_compile_impl(ctx):
    """Implementation of synth_compile rule."""
    output_elf = ctx.actions.declare_file(ctx.attr.out or (ctx.label.name + ".elf"))

    # Get the synth binary
    synth = ctx.executable._synth

    # Determine input file
    if ctx.attr.wasm_module:
        if MeldFusedInfo in ctx.attr.wasm_module:
            input_wasm = ctx.attr.wasm_module[MeldFusedInfo].fused_wasm
        else:
            input_files = ctx.attr.wasm_module[DefaultInfo].files.to_list()
            input_wasm = None
            for f in input_files:
                if f.extension in ("wasm", "wat", "wast"):
                    input_wasm = f
                    break
            if not input_wasm:
                fail("Target '{}' does not produce a .wasm, .wat, or .wast file".format(
                    ctx.attr.wasm_module.label,
                ))
    elif ctx.file.src:
        input_wasm = ctx.file.src
    else:
        fail("Either wasm_module or src must be specified")

    # Build command: synth compile <input> -o <output> [flags]
    args = ctx.actions.args()
    args.add("compile")
    args.add(input_wasm)
    args.add("-o", output_elf)

    # Target selection
    if ctx.attr.target:
        args.add("-t", ctx.attr.target)
    elif ctx.attr.cortex_m:
        args.add("--cortex-m")

    # Function selection
    if ctx.attr.func_name:
        args.add("-n", ctx.attr.func_name)
    elif ctx.attr.all_exports:
        args.add("--all-exports")

    # Optimization flags
    if ctx.attr.no_optimize:
        args.add("--no-optimize")

    if ctx.attr.loom_compat:
        args.add("--loom-compat")

    if ctx.attr.bounds_check:
        args.add("--bounds-check")

    # Backend selection
    if ctx.attr.backend:
        args.add("-b", ctx.attr.backend)

    # Verification
    if ctx.attr.verify:
        args.add("--verify")

    # Linking
    inputs = [input_wasm]
    if ctx.attr.link:
        args.add("--link")
        if ctx.file.builtins:
            args.add("--builtins", ctx.file.builtins)
            inputs.append(ctx.file.builtins)

    ctx.actions.run(
        inputs = inputs,
        outputs = [output_elf],
        executable = synth,
        arguments = [args],
        mnemonic = "SynthCompile",
        progress_message = "Compiling WebAssembly to ARM ELF: %{label}",
    )

    return [
        DefaultInfo(
            files = depset([output_elf]),
        ),
        OutputGroupInfo(
            elf = depset([output_elf]),
        ),
        SynthCompiledInfo(
            elf_file = output_elf,
            source_wasm = input_wasm,
            target = ctx.attr.target or ("cortex-m3" if ctx.attr.cortex_m else ""),
            backend = ctx.attr.backend or "arm",
        ),
    ]

synth_compile = rule(
    implementation = _synth_compile_impl,
    attrs = {
        "wasm_module": attr.label(
            doc = "WebAssembly module target (from meld_fuse, wasm_optimize, or component build)",
        ),
        "src": attr.label(
            doc = "Direct .wasm/.wat/.wast source file (alternative to wasm_module)",
            allow_single_file = [".wasm", ".wat", ".wast"],
        ),
        "out": attr.string(
            doc = "Output ELF filename (defaults to {name}.elf)",
        ),
        "target": attr.string(
            doc = """Target profile: cortex-m3, cortex-m4, cortex-m4f, cortex-m7,
cortex-m7dp, cortex-m55, cortex-r5, cortex-a53, riscv32imac""",
        ),
        "cortex_m": attr.bool(
            doc = "Generate Cortex-M binary with vector table (defaults to cortex-m3)",
            default = False,
        ),
        "func_name": attr.string(
            doc = "Compile a single function by export name",
        ),
        "all_exports": attr.bool(
            doc = "Compile all exported functions (default when no func specified)",
            default = True,
        ),
        "no_optimize": attr.bool(
            doc = "Disable peephole optimizer",
            default = False,
        ),
        "loom_compat": attr.bool(
            doc = "Skip optimization passes that Loom already handles",
            default = False,
        ),
        "bounds_check": attr.bool(
            doc = "Enable software bounds checking (~25% overhead)",
            default = False,
        ),
        "backend": attr.string(
            doc = "Compilation backend: arm (default), w2c2, awsm, wasker",
            values = ["arm", "w2c2", "awsm", "wasker"],
        ),
        "verify": attr.bool(
            doc = "Run Z3 translation validation after compilation",
            default = False,
        ),
        "link": attr.bool(
            doc = "Link with arm-none-eabi-gcc into final firmware",
            default = False,
        ),
        "builtins": attr.label(
            doc = "Path to kiln-builtins .o/.a for linking (required when link=True with Meld output)",
            allow_single_file = [".o", ".a"],
        ),
        "_synth": attr.label(
            doc = "The synth CLI binary",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """Compile a WebAssembly module to an ARM Cortex-M ELF binary using Synth.

Synth performs ahead-of-time compilation from WebAssembly to bare-metal ARM
machine code. The output is an ELF binary suitable for flashing to embedded
microcontrollers or testing via Renode emulation.

Pipeline position (final stage):
  rust_wasm_component → wasm_sign → meld_fuse → wasm_optimize → synth_compile

For Meld-fused modules, Synth generates `BL __meld_dispatch_import` calls for
inter-component imports. The resulting relocatable ELF must be linked with
kiln-builtins to resolve these symbols.

Memory layout (Cortex-M):
- Flash at 0x00000000: vector table + handlers + compiled functions
- RAM at 0x20000000: linear memory (R11=base) + stack (grows down)
- R10 = memory size, R11 = memory base, R9 = globals base

Note: Synth does not yet have published releases. The _synth attribute must
point to a locally-built synth binary. See pulseengine/synth for build instructions.

Example:
    load("@rules_wasm_component//wasm:defs.bzl", "synth_compile")

    synth_compile(
        name = "firmware",
        wasm_module = ":fused_optimized",
        target = "cortex-m4f",
        loom_compat = True,
        link = True,
        builtins = "@kiln//builtins:kiln_builtins",
    )
""",
)
