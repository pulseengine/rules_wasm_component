"""wit_from_component rule — recover WIT from a prebuilt component's binary.

Motivating use case (rules_wasm_component#626): `wasm_component_import` adopts
a prebuilt `.wasm` component into the build graph but cannot recover its WIT —
the interfaces are baked into the binary as a real, non-optional part of the
component-model encoding, so "extract it" is a mechanical operation, not a
guess. Before this rule that extraction happened outside Bazel (a manual
`wasm-tools component wit` invocation copied into the consuming repo), which is
exactly the kind of out-of-band copy that drifts from the artifact it was taken
from.

This rule runs `wasm-tools component wit` twice, producing two shapes of the
same extraction:

1. `-o <out.wit>`: one self-contained file inlining every transitively
   referenced package (the component's own exports plus every WASI/host
   interface it imports). This becomes `WitInfo.wit_files` — a real,
   individually addressable File, which `wit_bindgen`'s directory-detection
   loop needs at least one of regardless of which code path it takes (an
   empty `wit_files` depset hits a genuine Starlark landmine there: slicing
   `cmd_args[:-len(wit_file_args)]` with `len(wit_file_args) == 0` evaluates
   as `cmd_args[:-0]`, i.e. `cmd_args[:0]` — silently empties the whole
   argument list instead of leaving it untouched).
2. `--out-dir <dir>`: the same content split into `component.wit` + `deps/`.
   This becomes `DefaultInfo.files` so `wit_bindgen` finds a directory via its
   `file.is_directory` scan and takes the well-tested `wit_library_dir` code
   path — the one every existing `wit_library` consumer already exercises —
   rather than the sibling "no external dependencies" flat-file fallback,
   which (as of this writing) never copies its generated output to the
   filename Bazel declared and fails on any real invocation. Two extractions
   sidesteps that bug rather than depending on a fix to it.

Naming caveat: a component binary retains only its structural imports/exports,
not the original source WIT's package/world names — those aren't part of the
component-model encoding. `wasm-tools component wit` extracting from a binary
always synthesizes the wrapper identifiers `package root:component` /
`world root` (verified against wasm-tools 1.246.2+ output), so this rule
reports those as `WitInfo.package_name` / `world_name` rather than guessing.
The real interface names — what the component actually exports — are exactly
right in the extracted WIT text; only the synthetic outer wrapper is generic.
"""

load("//providers:providers.bzl", "WasmComponentInfo", "WitInfo")

# wasm-tools' fixed synthesized identifiers when extracting WIT from a
# component binary (not a WIT source package) — see the module doc above.
_SYNTHESIZED_PACKAGE_NAME = "root:component"
_SYNTHESIZED_WORLD_NAME = "root"

def _wit_from_component_impl(ctx):
    wasm_file = ctx.attr.component[WasmComponentInfo].wasm_file
    wasm_tools = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"].wasm_tools

    out_file = ctx.actions.declare_file(ctx.label.name + ".wit")
    ctx.actions.run(
        executable = wasm_tools,
        arguments = ["component", "wit", wasm_file.path, "-o", out_file.path],
        inputs = [wasm_file],
        outputs = [out_file],
        mnemonic = "WitFromComponent",
        progress_message = "Extracting WIT from %s for %s" % (wasm_file.short_path, ctx.label),
    )

    out_dir = ctx.actions.declare_directory(ctx.label.name + "_dir")
    ctx.actions.run(
        executable = wasm_tools,
        arguments = ["component", "wit", wasm_file.path, "--out-dir", out_dir.path],
        inputs = [wasm_file],
        outputs = [out_dir],
        mnemonic = "WitFromComponentDir",
        progress_message = "Extracting WIT (directory form) from %s for %s" % (wasm_file.short_path, ctx.label),
    )

    return [
        DefaultInfo(files = depset([out_dir])),
        WitInfo(
            wit_files = depset([out_file]),
            wit_deps = depset(),
            package_name = _SYNTHESIZED_PACKAGE_NAME,
            world_name = _SYNTHESIZED_WORLD_NAME,
            interface_names = ctx.attr.interface_names,
        ),
    ]

wit_from_component = rule(
    implementation = _wit_from_component_impl,
    doc = """Recovers a `WitInfo` from a prebuilt component by extracting its WIT.

Use this to close the gap `wasm_component_import` leaves open — an adopted
component's WIT lives in the binary; this rule pulls it out mechanically
instead of requiring an out-of-band copy that can drift:

```starlark
load("@rules_wasm_component//wasm:defs.bzl", "wasm_component_import")
load("@rules_wasm_component//wit:defs.bzl", "wit_from_component")

wasm_component_import(
    name = "gale_nano",
    wasm = "@gale_nano_wasm//file",
)

wit_from_component(
    name = "gale_nano_wit",
    component = ":gale_nano",
)

wit_bindgen(
    name = "gale_nano_bindings",
    wit = ":gale_nano_wit",
    language = "rust",
)
```

See the file-level doc for the package/world naming caveat: the extracted WIT
carries the component's real interfaces, but the wrapper package/world names
are wasm-tools' fixed synthesized identifiers (`root:component` / `root`), not
whatever the original source WIT called them — a component binary does not
retain that.

For the union case — deriving one `WitInfo` from several components that
together define a complete, non-overlapping-but-shared type set (e.g. a
fused/composed pipeline where no single component's WIT is complete on its
own) — see rules_wasm_component#626; that needs a semantic merge, not a
mechanical extraction, and isn't what this rule does.
""",
    attrs = {
        "component": attr.label(
            mandatory = True,
            providers = [WasmComponentInfo],
            doc = "The adopted component to extract WIT from, e.g. a `wasm_component_import` target.",
        ),
        "interface_names": attr.string_list(
            default = [],
            doc = "Optional, caller-declared interface names (informational only — " +
                  "nothing in this repo's toolchain reads WitInfo.interface_names " +
                  "today; the real interfaces are in the extracted WIT text).",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
)
