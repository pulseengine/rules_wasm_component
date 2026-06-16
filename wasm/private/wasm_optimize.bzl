"""LOOM WebAssembly optimizer integration.

Provides the wasm_optimize rule for optimizing WebAssembly components using LOOM.
LOOM performs constant folding, strength reduction, and function inlining with
optional Z3-based formal verification.
"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _wasm_optimize_impl(ctx):
    """Implementation of wasm_optimize rule."""
    input_wasm = ctx.file.component
    output_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    # Native loom binary (v1.x is native per-OS, not the loom.wasm component).
    # Running loom natively reads the input file directly through the OS, so the
    # wasmtime/WASI-preopen/symlink workaround the old loom.wasm path needed
    # (issue #490, loom_wrapper) no longer applies.
    loom = ctx.toolchains["@rules_wasm_component//toolchains:loom_toolchain_type"].loom

    args = ctx.actions.args()
    args.add("optimize")
    args.add(input_wasm)
    args.add("-o", output_wasm)

    # Add optimization flags
    if ctx.attr.stats:
        args.add("--stats")

    if ctx.attr.verify:
        args.add("--verify")

    if ctx.attr.wat_output:
        args.add("--wat")

    # Attestation control (loom 0.3.0+)
    if not ctx.attr.attestation:
        args.add("--attestation", "false")

    # Selective pass control
    if ctx.attr.passes:
        args.add("--passes", ",".join(ctx.attr.passes))

    ctx.actions.run(
        inputs = [input_wasm],
        outputs = [output_wasm],
        executable = loom,
        arguments = [args],
        mnemonic = "LoomOptimize",
        progress_message = "Optimizing WebAssembly component with LOOM: %{label}",
    )

    providers = [
        DefaultInfo(
            files = depset([output_wasm]),
        ),
        OutputGroupInfo(
            wasm = depset([output_wasm]),
        ),
    ]

    # Propagate WasmComponentInfo if the input had one
    if WasmComponentInfo in ctx.attr.component:
        src_info = ctx.attr.component[WasmComponentInfo]
        providers.append(WasmComponentInfo(
            wasm_file = output_wasm,
            wit_info = src_info.wit_info,
            component_type = src_info.component_type,
            imports = src_info.imports,
            exports = src_info.exports,
            metadata = dict(src_info.metadata, optimized = True),
            profile = src_info.profile,
            profile_variants = src_info.profile_variants,
        ))

    return providers

wasm_optimize = rule(
    implementation = _wasm_optimize_impl,
    attrs = {
        "component": attr.label(
            doc = "The WebAssembly component to optimize",
            mandatory = True,
            allow_single_file = [".wasm"],
        ),
        "stats": attr.bool(
            doc = "Show optimization statistics",
            default = True,
        ),
        "verify": attr.bool(
            doc = "Run Z3-based formal verification (slower but proves correctness)",
            default = False,
        ),
        "wat_output": attr.bool(
            doc = "Also output WAT text format",
            default = False,
        ),
        "attestation": attr.bool(
            doc = "Embed transformation attestation in output (records optimization provenance)",
            default = True,
        ),
        "passes": attr.string_list(
            doc = """Selective optimization passes. Empty = all passes.
Available passes: precompute, constant-folding, cse, inline,
advanced, branches, dce, merge-blocks, vacuum, simplify-locals""",
            default = [],
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:loom_toolchain_type"],
    doc = """Optimize a WebAssembly component using LOOM.

LOOM performs expression-level optimizations including:
- Constant folding - Compile-time evaluation of expressions
- Strength reduction - Replace expensive ops with cheaper ones (x * 8 → x << 3)
- Function inlining - Inline small functions for cross-function optimization
- Common subexpression elimination (CSE)
- Dead code elimination (DCE)
- Branch simplification and block merging

For Meld-fused components, LOOM automatically applies 7 additional fused-component
passes (adapter devirtualization, import deduplication, etc.).

Typical results:
- 80-95% binary size reduction
- 0-40% instruction count reduction

Example:
    wasm_optimize(
        name = "my_component_optimized",
        component = ":my_component",
        stats = True,
        verify = False,         # Enable for Z3 formal verification
        attestation = True,     # Embed transformation provenance
        passes = [],            # Empty = all passes
    )
""",
)
