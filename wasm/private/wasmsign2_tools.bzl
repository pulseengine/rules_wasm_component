"""Shared helper for invoking the wasmsign2 Go wrapper.

The wrapper (`//tools/wasmsign2_wrapper`) runs the wasmsign2 WASM component under
wasmtime. Both the wasmtime binary and the component are passed to it as
`--bazel-*` arguments (and staged as action inputs) rather than located via the
wrapper's runfiles: a hardcoded runfiles Rlocation embeds the canonical repo
name, which differs when rules_wasm_component is consumed as a dependency (it
gains a `rules_wasm_component+` prefix), breaking downstream signing/attestation
(issue #501, same fix as #490/#497).
"""

# wasmtime toolchain that runs the wasmsign2 component.
WASMTIME_TOOLCHAIN = "@rules_wasm_component//toolchains:wasmtime_toolchain_type"

# The wasmsign2 WASM component, passed to the wrapper as an action input.
# Merge into a rule's attrs; the rule must also set
# `toolchains = [WASMTIME_TOOLCHAIN]`.
WASMSIGN2_WASM_ATTR = {
    "_wasmsign2_wasm": attr.label(
        default = "@wasmsign2_cli_wasm//file:file",
        allow_single_file = True,
        doc = "wasmsign2 WASM component, passed to the wrapper as an action input",
    ),
}

def add_wrapper_tools(ctx, args):
    """Add `--bazel-wasmtime=`/`--bazel-wasm-component=` to a wrapper invocation.

    Returns the extra action inputs (the wasmtime binary and the component) to
    include in `ctx.actions.run(inputs = ...)`.
    """
    wasmtime = ctx.toolchains[WASMTIME_TOOLCHAIN].wasmtime
    wasm = ctx.file._wasmsign2_wasm
    args.add(wasmtime, format = "--bazel-wasmtime=%s")
    args.add(wasm, format = "--bazel-wasm-component=%s")
    return [wasmtime, wasm]
