"""witness MC/DC coverage integration.

Provides the wasm_module_coverage rule, which measures MC/DC-style branch
coverage of a WebAssembly **core module** using witness. This is the
verification stage of the PulseEngine pipeline:

  ... -> meld (fuse to core module) -> wasm_module_coverage -> coverage evidence

witness operates on core modules, not components. The natural input is the
core module produced by meld_fuse (a MeldFusedInfo provider); a plain .wasm
core module is also accepted.

The rule runs witness as a three-stage pipeline, each stage a distinct action:
  1. instrument  — rewrite the module with branch counters (+ sidecar manifest)
  2. run         — execute the instrumented module, capturing counter data
  3. lcov        — emit a standard LCOV report from the counter data
"""

load("//providers:providers.bzl", "MeldFusedInfo")

def _resolve_module(dep):
    """Resolve the input core module .wasm file from a dependency."""
    if MeldFusedInfo in dep:
        return dep[MeldFusedInfo].fused_wasm

    wasm_files = [f for f in dep[DefaultInfo].files.to_list() if f.extension == "wasm"]
    if len(wasm_files) != 1:
        fail("wasm_module_coverage: target '{}' must produce exactly one .wasm core module (found {})".format(
            dep.label,
            len(wasm_files),
        ))
    return wasm_files[0]

def _wasm_module_coverage_impl(ctx):
    """Implementation of the wasm_module_coverage rule."""
    witness = ctx.toolchains["@rules_wasm_component//toolchains:witness_toolchain_type"].witness

    module = _resolve_module(ctx.attr.module)

    if not (ctx.attr.invoke or ctx.attr.invoke_with_args or ctx.attr.call_start or ctx.attr.invoke_all):
        fail("wasm_module_coverage: specify at least one of invoke, invoke_with_args, " +
             "call_start, or invoke_all so witness has an entry point to execute.")

    name = ctx.label.name
    instrumented = ctx.actions.declare_file(name + "_instrumented.wasm")
    # witness writes the branch manifest as a sidecar: <instrumented>.witness.json
    manifest = ctx.actions.declare_file(name + "_instrumented.wasm.witness.json")
    run_data = ctx.actions.declare_file(name + "_witness-run.json")
    lcov = ctx.actions.declare_file(name + ".lcov.info")

    # Stage 1: instrument
    instrument_args = ctx.actions.args()
    instrument_args.add("instrument")
    instrument_args.add(module)
    instrument_args.add("-o", instrumented)
    ctx.actions.run(
        inputs = [module],
        outputs = [instrumented, manifest],
        executable = witness,
        arguments = [instrument_args],
        mnemonic = "WitnessInstrument",
        progress_message = "Instrumenting %s for coverage" % module.short_path,
        tools = [witness],
    )

    # Stage 2: run (executes the instrumented module via witness's embedded runtime)
    run_args = ctx.actions.args()
    run_args.add("run")
    run_args.add(instrumented)
    run_args.add("--manifest", manifest)
    run_args.add("-o", run_data)
    for export in ctx.attr.invoke:
        run_args.add("--invoke", export)
    for spec in ctx.attr.invoke_with_args:
        run_args.add("--invoke-with-args", spec)
    if ctx.attr.invoke_all:
        run_args.add("--invoke-all")
    if ctx.attr.call_start:
        run_args.add("--call-start")
    ctx.actions.run(
        inputs = [instrumented, manifest],
        outputs = [run_data],
        executable = witness,
        arguments = [run_args],
        mnemonic = "WitnessRun",
        progress_message = "Running coverage for %s" % ctx.label,
        tools = [witness],
    )

    # Stage 3: lcov report
    lcov_args = ctx.actions.args()
    lcov_args.add("lcov")
    lcov_args.add("--run", run_data)
    lcov_args.add("--manifest", manifest)
    lcov_args.add("-o", lcov)
    ctx.actions.run(
        inputs = [run_data, manifest],
        outputs = [lcov],
        executable = witness,
        arguments = [lcov_args],
        mnemonic = "WitnessLcov",
        progress_message = "Generating LCOV coverage report for %s" % ctx.label,
        tools = [witness],
    )

    return [
        DefaultInfo(
            files = depset([lcov]),
        ),
        OutputGroupInfo(
            coverage = depset([lcov]),
            instrumented = depset([instrumented]),
            run_data = depset([run_data]),
        ),
    ]

wasm_module_coverage = rule(
    implementation = _wasm_module_coverage_impl,
    attrs = {
        "module": attr.label(
            doc = "The WebAssembly core module to measure. Accepts a meld_fuse " +
                  "target (MeldFusedInfo) or any target producing a single .wasm.",
            mandatory = True,
            allow_files = [".wasm"],
        ),
        "invoke": attr.string_list(
            doc = "Names of no-argument exports for witness to invoke.",
        ),
        "invoke_with_args": attr.string_list(
            doc = "Exports to invoke with typed arguments, as 'func:args' " +
                  "(e.g. 'classify:2024').",
        ),
        "call_start": attr.bool(
            doc = "Invoke the WASI `_start` entry point.",
            default = False,
        ),
        "invoke_all": attr.bool(
            doc = "Auto-discover and invoke every no-argument export.",
            default = False,
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:witness_toolchain_type"],
    doc = """Measure MC/DC-style branch coverage of a WASM core module with witness.

witness instruments the module with branch counters, executes it via its
embedded runtime (invoking the exports named by `invoke` / `invoke_with_args`
/ `call_start` / `invoke_all`), and emits a standard LCOV report as the
default output.

witness operates on core modules, not components — pair it with `meld_fuse`,
which fuses a composed component down to a core module:

  rust_wasm_component -> wasm_sign -> meld_fuse -> wasm_module_coverage

Example:
    load("@rules_wasm_component//wasm:defs.bzl", "wasm_module_coverage")

    wasm_module_coverage(
        name = "service_coverage",
        module = ":fused_service",   # a meld_fuse target
        invoke = ["run"],
    )
""",
)
