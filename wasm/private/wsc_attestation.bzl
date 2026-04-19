"""Sigil attestation rules: wasm_attest, wasm_verify_chain, wasm_show_chain.

Wraps the wsc CLI's transformation-attestation commands so Bazel pipelines can
build SLSA-style provenance chains alongside the existing signing flow.

Pipeline position:
  (build) -> wasm_sign -> meld_fuse -> wasm_optimize -> synth_compile
                                 |
                                 +-- wasm_attest      (for custom transforms)
                                 +-- wasm_verify_chain (gate before ship)
                                 +-- wasm_show_chain   (debug / CI artifact)

meld_fuse and wasm_optimize already embed their own attestations when their
`attestation` attribute is True; wasm_attest is the escape hatch for any
external transformation that should be recorded in the chain. wasm_verify_chain
is the policy-enforcement gate, and wasm_show_chain produces a JSON artifact
useful for CI diagnostics.
"""

load("//providers:providers.bzl", "WasmComponentInfo")

_TRANSFORMATION_TYPES = [
    "optimization",
    "composition",
    "instrumentation",
    "stripping",
    "custom",
]

def _resolve_input_wasm(ctx, attr_component, attr_wasm_file):
    """Pull the .wasm out of a component target or an explicit file label."""
    if attr_component:
        if WasmComponentInfo in attr_component:
            return attr_component[WasmComponentInfo].wasm_file, attr_component[WasmComponentInfo]
        for f in attr_component[DefaultInfo].files.to_list():
            if f.extension == "wasm":
                return f, None
        fail("Target '{}' does not produce any .wasm files".format(attr_component.label))
    if attr_wasm_file:
        return attr_wasm_file, None
    fail("Either component or wasm_file must be specified")

def _wasm_attest_impl(ctx):
    """Record a transformation attestation: input -> output with tool metadata."""
    input_wasm, component_info = _resolve_input_wasm(
        ctx,
        ctx.attr.input_component,
        ctx.file.input_wasm_file,
    )
    output_input, _ = _resolve_input_wasm(
        ctx,
        ctx.attr.output_component,
        ctx.file.output_wasm_file,
    )

    attested_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    wrapper = ctx.executable._wasmsign2_wrapper

    # wsc attest reads and rewrites --output-file in place. The wrapper's
    # --bazel-stage-source flag stages the post-transformation WASM into the
    # declared Bazel output before invoking wsc, keeping the whole rule
    # Bazel-native (no shell action needed for the copy).
    args = ctx.actions.args()
    args.add("--bazel-stage-source=" + output_input.path)
    args.add("attest")
    args.add("--input-file", input_wasm)
    args.add("--output-file", attested_wasm)
    args.add("--tool-name", ctx.attr.tool_name)
    args.add("--tool-version", ctx.attr.tool_version)
    args.add("--type", ctx.attr.transformation_type)

    ctx.actions.run(
        executable = wrapper,
        arguments = [args],
        inputs = [input_wasm, output_input],
        outputs = [attested_wasm],
        mnemonic = "WasmAttest",
        progress_message = "Recording transformation attestation %s on %s" % (
            ctx.attr.transformation_type,
            attested_wasm.short_path,
        ),
    )

    providers = [
        DefaultInfo(files = depset([attested_wasm])),
        OutputGroupInfo(wasm = depset([attested_wasm])),
    ]

    if component_info:
        providers.append(WasmComponentInfo(
            wasm_file = attested_wasm,
            wit_info = component_info.wit_info,
            component_type = component_info.component_type,
            imports = component_info.imports,
            exports = component_info.exports,
            metadata = dict(
                component_info.metadata,
                attested = True,
                attestation_tool = ctx.attr.tool_name,
                attestation_type = ctx.attr.transformation_type,
            ),
            profile = component_info.profile,
            profile_variants = component_info.profile_variants,
        ))

    return providers

wasm_attest = rule(
    implementation = _wasm_attest_impl,
    attrs = {
        "input_component": attr.label(
            doc = "Component target representing the input (pre-transformation) WASM",
        ),
        "input_wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "Raw .wasm file for the pre-transformation input (alternative to input_component)",
        ),
        "output_component": attr.label(
            doc = "Component target representing the output (post-transformation) WASM",
        ),
        "output_wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "Raw .wasm file for the post-transformation output (alternative to output_component)",
        ),
        "tool_name": attr.string(
            mandatory = True,
            doc = "Name of the transformation tool (e.g., 'my-custom-instrumentation')",
        ),
        "tool_version": attr.string(
            mandatory = True,
            doc = "Version of the transformation tool",
        ),
        "transformation_type": attr.string(
            default = "custom",
            values = _TRANSFORMATION_TYPES,
            doc = "Type of transformation performed",
        ),
        "_wasmsign2_wrapper": attr.label(
            default = "//tools/wasmsign2_wrapper",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """Record a transformation attestation on a WebAssembly module.

Use this when you run a transformation outside of the built-in pipeline rules
(meld_fuse, wasm_optimize) and want the attestation chain to remain unbroken.
meld_fuse and wasm_optimize embed their own attestations when `attestation =
True` (the default); wasm_attest is the escape hatch for everything else.

The output is a new WASM file with an attestation custom section recording
the input hash, tool name/version, and transformation type, chained to any
prior attestations already embedded in the input.

Example:
    load("@rules_wasm_component//wasm:defs.bzl", "wasm_attest")

    wasm_attest(
        name = "instrumented_attested",
        input_component = ":original_component",
        output_component = ":instrumented_component",
        tool_name = "my-instrumentation-tool",
        tool_version = "1.2.0",
        transformation_type = "instrumentation",
    )
""",
)

def _wasm_verify_chain_impl(ctx):
    """Verify the transformation attestation chain on a WASM module."""
    input_wasm, _ = _resolve_input_wasm(ctx, ctx.attr.component, ctx.file.wasm_file)

    marker = ctx.actions.declare_file(ctx.label.name + "_chain_verified.txt")
    wrapper = ctx.executable._wasmsign2_wrapper

    args = ctx.actions.args()
    args.add("verify-chain")
    args.add("--input-file", input_wasm)

    inputs = [input_wasm]
    if ctx.file.policy:
        args.add("--policy", ctx.file.policy)
        inputs.append(ctx.file.policy)
    if ctx.file.trusted_tools:
        args.add("--trusted-tools", ctx.file.trusted_tools)
        inputs.append(ctx.file.trusted_tools)
    if ctx.attr.require_signatures:
        args.add("--require-signatures")
    if ctx.attr.require_attestation_signatures:
        args.add("--require-attestation-signatures")
    if ctx.attr.max_age_days > 0:
        args.add("--max-age-days", str(ctx.attr.max_age_days))
    if ctx.attr.strict:
        args.add("--strict")
    if ctx.attr.report_only:
        args.add("--report-only")

    args.add("--bazel-marker-file=" + marker.path)

    ctx.actions.run(
        executable = wrapper,
        arguments = [args],
        inputs = inputs,
        outputs = [marker],
        mnemonic = "WasmVerifyChain",
        progress_message = "Verifying attestation chain on %s" % input_wasm.short_path,
    )

    return [
        DefaultInfo(files = depset([marker])),
    ]

wasm_verify_chain = rule(
    implementation = _wasm_verify_chain_impl,
    attrs = {
        "component": attr.label(
            doc = "Component target to verify (provides WasmComponentInfo)",
        ),
        "wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "Raw .wasm file to verify (alternative to component)",
        ),
        "policy": attr.label(
            allow_single_file = [".toml"],
            doc = "TOML policy file for SLSA-aware verification",
        ),
        "trusted_tools": attr.label(
            allow_single_file = [".json"],
            doc = "Legacy JSON file listing trusted tools (superseded by `policy`)",
        ),
        "require_signatures": attr.bool(
            default = False,
            doc = "Require all root inputs to carry Ed25519 signatures",
        ),
        "require_attestation_signatures": attr.bool(
            default = False,
            doc = "Require each attestation to be signed by a trusted key",
        ),
        "max_age_days": attr.int(
            default = 0,
            doc = "Maximum age of attestations in days (0 = no limit)",
        ),
        "strict": attr.bool(
            default = False,
            doc = "Override all policy rules to strict enforcement",
        ),
        "report_only": attr.bool(
            default = False,
            doc = "Override all policy rules to report-only (no build failures)",
        ),
        "_wasmsign2_wrapper": attr.label(
            default = "//tools/wasmsign2_wrapper",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """Verify a WebAssembly module's transformation attestation chain.

Emits a marker file on success; the build fails if verification fails (unless
`report_only = True`). Use this as the ship-gate after the full pipeline:

    rust_wasm_component -> wasm_sign -> meld_fuse -> wasm_optimize
                                                         |
                                                         +- wasm_verify_chain

The rule understands the same policy format wsc accepts directly: a TOML file
with trusted tool identities, minimum attestation signing policies, and
freshness requirements. Pair with `strict = True` for production builds and
`report_only = True` to see what a new policy would flag without blocking.

Example:
    load("@rules_wasm_component//wasm:defs.bzl", "wasm_verify_chain")

    wasm_verify_chain(
        name = "verify_shipped_component",
        component = ":final_component",
        policy = ":trust_policy.toml",
        require_signatures = True,
        strict = True,
    )
""",
)

def _wasm_show_chain_impl(ctx):
    """Extract the attestation chain from a WASM module as a JSON artifact."""
    input_wasm, _ = _resolve_input_wasm(ctx, ctx.attr.component, ctx.file.wasm_file)

    ext = "json" if ctx.attr.as_json else "txt"
    out = ctx.actions.declare_file("{}.{}".format(ctx.label.name, ext))

    wrapper = ctx.executable._wasmsign2_wrapper

    args = ctx.actions.args()
    args.add("show-chain")
    args.add("--input-file", input_wasm)
    if ctx.attr.as_json:
        args.add("--json")

    # wsc writes the chain rendering to stdout; the wrapper's
    # --bazel-capture-stdout flag redirects it into the declared Bazel output
    # so no shell action is needed.
    args = ctx.actions.args()
    args.add("--bazel-capture-stdout=" + out.path)
    args.add("show-chain")
    args.add("--input-file", input_wasm)
    if ctx.attr.as_json:
        args.add("--json")

    ctx.actions.run(
        executable = wrapper,
        arguments = [args],
        inputs = [input_wasm],
        outputs = [out],
        mnemonic = "WasmShowChain",
        progress_message = "Extracting attestation chain from %s" % input_wasm.short_path,
    )

    return [
        DefaultInfo(files = depset([out])),
    ]

wasm_show_chain = rule(
    implementation = _wasm_show_chain_impl,
    attrs = {
        "component": attr.label(
            doc = "Component target to inspect (provides WasmComponentInfo)",
        ),
        "wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "Raw .wasm file to inspect (alternative to component)",
        ),
        "as_json": attr.bool(
            default = True,
            doc = "Emit JSON (True) or human-readable text (False)",
        ),
        "_wasmsign2_wrapper": attr.label(
            default = "//tools/wasmsign2_wrapper",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """Extract a WebAssembly module's transformation attestation chain to a file.

Produces a JSON (default) or text rendering of the transformation chain stored
in the module's custom sections. Useful as a CI build artifact for diagnostics
and compliance reporting.

Example:
    load("@rules_wasm_component//wasm:defs.bzl", "wasm_show_chain")

    wasm_show_chain(
        name = "final_component_chain",
        component = ":final_component",
        as_json = True,
    )
""",
)
