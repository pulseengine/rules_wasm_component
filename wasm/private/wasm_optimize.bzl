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

    # Get LOOM WASM component, the wrapper that runs it, and wasmtime.
    loom_wasm = ctx.file._loom_wasm
    loom_wrapper = ctx.executable._loom_wrapper
    wasmtime = ctx.toolchains["@rules_wasm_component//toolchains:wasmtime_toolchain_type"].wasmtime

    # Build command arguments for loom_wrapper, which prepends `wasmtime run`
    # and the resolved `--dir` preopens (issue #490).
    #
    # loom reads input paths via WASI, and a fetched/adopted input is staged
    # as a symlink whose target escapes a plain `--dir=.` preopen, so wasmtime
    # refuses to follow it. The wrapper resolves the symlink on the host and
    # preopens the real directory.
    #
    # The wasmtime binary and loom.wasm are passed as the first two arguments
    # rather than located via the wrapper's runfiles: a hardcoded runfiles
    # Rlocation embeds the canonical repo name, which differs when
    # rules_wasm_component is the root module vs a dependency (the latter gains
    # a `rules_wasm_component+` prefix), so the lookup fails for downstream
    # consumers. wasmtime opens both files natively, so neither needs a WASI
    # mount.
    #
    # Note: loom v0.3.0 does NOT accept the `--` separator between the wasm
    # module path and the subcommand when run under `wasmtime run`.
    args = ctx.actions.args()
    args.add(wasmtime)
    args.add(loom_wasm)
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
        inputs = [input_wasm, loom_wasm, wasmtime],
        outputs = [output_wasm],
        executable = loom_wrapper,
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
        "_loom_wasm": attr.label(
            doc = "LOOM WebAssembly component",
            default = "@loom_wasm//file:file",
            allow_single_file = True,
        ),
        "_loom_wrapper": attr.label(
            doc = "Wrapper that runs loom.wasm under wasmtime with symlink-resolved WASI mounts",
            default = "//tools/loom_wrapper",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasmtime_toolchain_type"],
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
