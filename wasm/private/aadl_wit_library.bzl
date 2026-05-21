"""spar AADL-to-WIT generation integration.

Provides the aadl_wit_library rule, which runs `spar codegen` to generate WIT
interfaces from a formal AADL v2.3 architecture model. This is the front of
the PulseEngine pipeline:

  AADL model → spar → WIT → wit_library → wit_bindgen → build → component

spar emits one `.wit` file per AADL `process` instance, written under a
`wit/` subdirectory of the rule's output. Because the generated filenames
derive from process names in the model, the output is declared as a single
tree artifact (directory) rather than statically-named files.
"""

def _aadl_wit_library_impl(ctx):
    """Implementation of the aadl_wit_library rule."""
    spar_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:spar_toolchain_type"]
    spar = spar_toolchain.spar

    # Tree artifact: spar writes generated WIT under <out_dir>/wit/*.wit.
    out_dir = ctx.actions.declare_directory(ctx.label.name)

    # spar codegen --root <Pkg::Type.Impl> --format wit --output <dir> <srcs...>
    args = ctx.actions.args()
    args.add("codegen")
    args.add("--root", ctx.attr.root)
    args.add("--format", "wit")
    args.add("--output", out_dir.path)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [out_dir],
        executable = spar,
        arguments = [args],
        mnemonic = "SparCodegen",
        progress_message = "Generating WIT from AADL model %s" % ctx.label,
        tools = [spar],
    )

    return [
        DefaultInfo(
            files = depset([out_dir]),
        ),
        OutputGroupInfo(
            wit = depset([out_dir]),
        ),
    ]

aadl_wit_library = rule(
    implementation = _aadl_wit_library_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "AADL source files (.aadl) — a model plus any library files.",
            mandatory = True,
            allow_files = [".aadl"],
        ),
        "root": attr.string(
            doc = "The AADL system implementation to instantiate, as " +
                  "`Package::Type.Impl` (e.g. `BuildingControl::BuildingControlDemo.Impl`).",
            mandatory = True,
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:spar_toolchain_type"],
    doc = """Generate WIT interfaces from an AADL v2.3 architecture model using spar.

spar instantiates the system named by `root`, then emits one `.wit` file per
AADL `process` instance into a `wit/` directory. The output is a single tree
artifact; downstream rules consume the generated WIT.

Pipeline position:
  aadl_wit_library → wit_library → wit_bindgen → rust_wasm_component → ...

Example:
    load("@rules_wasm_component//wasm:defs.bzl", "aadl_wit_library")

    aadl_wit_library(
        name = "building_control_wit",
        srcs = ["building_control.aadl"],
        root = "BuildingControl::BuildingControlDemo.Impl",
    )
""",
)
