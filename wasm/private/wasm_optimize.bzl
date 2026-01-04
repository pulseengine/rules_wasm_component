"""LOOM WebAssembly optimizer integration.

Provides the wasm_optimize rule for optimizing WebAssembly components using LOOM.
LOOM performs constant folding, strength reduction, and function inlining with
optional Z3-based formal verification.
"""

def _wasm_optimize_impl(ctx):
    """Implementation of wasm_optimize rule."""
    input_wasm = ctx.file.component
    output_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    # Get wasmtime toolchain for running loom.wasm
    wasmtime_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasmtime_toolchain_type"]
    wasmtime = wasmtime_toolchain.wasmtime

    # Get LOOM WASM component
    loom_wasm = ctx.file._loom_wasm

    # Build command arguments
    args = ctx.actions.args()
    args.add("run")
    args.add("--dir=.")
    args.add(loom_wasm)
    args.add("--")
    args.add("optimize")
    args.add("-i", input_wasm)
    args.add("-o", output_wasm)

    # Add optimization flags
    if ctx.attr.stats:
        args.add("--stats")

    if ctx.attr.verify:
        args.add("--verify")

    if ctx.attr.wat_output:
        args.add("--wat")

    ctx.actions.run(
        inputs = [input_wasm, loom_wasm],
        outputs = [output_wasm],
        executable = wasmtime,
        arguments = [args],
        mnemonic = "LoomOptimize",
        progress_message = "Optimizing WebAssembly component with LOOM: %{label}",
    )

    return [
        DefaultInfo(
            files = depset([output_wasm]),
        ),
        OutputGroupInfo(
            wasm = depset([output_wasm]),
        ),
    ]

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
        "_loom_wasm": attr.label(
            doc = "LOOM WebAssembly component",
            default = "@loom_wasm//file",
            allow_single_file = True,
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasmtime_toolchain_type"],
    doc = """Optimize a WebAssembly component using LOOM.

LOOM performs expression-level optimizations including:
- Constant folding - Compile-time evaluation of expressions
- Strength reduction - Replace expensive ops with cheaper ones (x * 8 → x << 3)
- Function inlining - Inline small functions for cross-function optimization

Typical results:
- 80-95% binary size reduction
- 0-40% instruction count reduction
- 10-30 µs optimization time

Example:
    wasm_optimize(
        name = "my_component_optimized",
        component = ":my_component",
        stats = True,
        verify = False,  # Enable for formal verification
    )
""",
)
