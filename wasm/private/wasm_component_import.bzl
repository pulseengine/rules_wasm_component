"""wasm_component_import rule — adopt a prebuilt .wasm component into the graph.

Wraps an already-built (fetched, vendored, or released) WebAssembly component
file in a `WasmComponentInfo` so the downstream rules (`wasm_validate`,
`wasm_optimize`, `meld_fuse`, `synth_compile`, signing) can consume it without
rebuilding it from source.

Motivating use case (rules_wasm_component#489): a consumer adopts a released
component artifact — e.g. a flight-control `.wasm` fetched via `http_file` — and
runs validate / optimize / fuse / compile over it. Before this rule that
required a hand-rolled shim in every consuming repo.
"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _wasm_component_import_impl(ctx):
    wasm_file = ctx.file.wasm

    metadata = dict(ctx.attr.metadata)
    metadata.setdefault("imported", "true")
    metadata.setdefault("name", ctx.label.name)

    return [
        DefaultInfo(files = depset([wasm_file])),
        WasmComponentInfo(
            wasm_file = wasm_file,
            # No WIT is recovered from a prebuilt binary here; consumers that
            # need typed bindings can supply it out of band. None is the
            # documented "no WIT available" value.
            wit_info = None,
            component_type = "component",
            # Optional, caller-declared interface surface. Left empty when the
            # caller does not know it — downstream rules must not hard-fail on a
            # stripped/opaque adopted component.
            imports = ctx.attr.imports,
            exports = ctx.attr.exports,
            metadata = metadata,
            profile = "release",
            profile_variants = {},
        ),
    ]

wasm_component_import = rule(
    implementation = _wasm_component_import_impl,
    doc = """Adopt a prebuilt `.wasm` component as a `WasmComponentInfo` target.

Use this to bring an external/released component into a rules_wasm_component
build so `wasm_validate`, `wasm_optimize`, `meld_fuse`, `synth_compile`, and the
signing rules can consume it:

```starlark
load("@rules_wasm_component//wasm:defs.bzl", "wasm_component_import", "wasm_validate")

wasm_component_import(
    name = "falcon_flight",
    wasm = "@falcon_flight_wasm//file",   # e.g. an http_file-fetched release asset
)

wasm_validate(
    name = "falcon_validate",
    component = ":falcon_flight",
)
```

`imports`/`exports` are optional and caller-declared; omit them for an opaque
component (downstream rules tolerate empty lists). `wit_info` is always `None`
for an imported binary — supply typed bindings out of band if needed.
""",
    attrs = {
        "wasm": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "The prebuilt WebAssembly component file to adopt.",
        ),
        "imports": attr.string_list(
            default = [],
            doc = "Optional, caller-declared import interface names. Empty if unknown.",
        ),
        "exports": attr.string_list(
            default = [],
            doc = "Optional, caller-declared export interface names. Empty if unknown.",
        ),
        "metadata": attr.string_dict(
            default = {},
            doc = "Optional extra metadata to attach to the WasmComponentInfo.",
        ),
    },
)
