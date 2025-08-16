"""WASM component creation rule implementation"""

load("//providers:providers.bzl", "WasmComponentInfo")
load("//tools/bazel_helpers:wasm_tools_actions.bzl", "create_component_action")

def _wasm_component_new_impl(ctx):
    """Implementation of wasm_component_new rule"""

    # Input and output files
    wasm_module = ctx.file.wasm_module
    component_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")

    # Use WASM Tools Integration Component for component creation
    created_component = create_component_action(
        ctx,
        wasm_module = wasm_module,
        adapter = ctx.file.adapter,
        output_name = component_wasm.basename,
    )

    # Create component info provider
    component_info = WasmComponentInfo(
        wasm_file = created_component,
        wit_info = None,  # No WIT info for converted modules
        component_type = "component",
        imports = [],  # TODO: Extract from component
        exports = [],  # TODO: Extract from component
        metadata = {
            "name": ctx.label.name,
            "source_module": wasm_module.path,
            "adapter": ctx.file.adapter.path if ctx.file.adapter else None,
        },
        profile = "unknown",
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(files = depset([created_component])),
    ]

wasm_component_new = rule(
    implementation = _wasm_component_new_impl,
    attrs = {
        "wasm_module": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "WASM module to convert to component",
        ),
        "adapter": attr.label(
            allow_single_file = [".wasm"],
            doc = "WASI adapter module for Preview1 compatibility",
        ),
        "options": attr.string_list(
            doc = "Additional options to pass to wasm-tools component new",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_component_toolchain_type"],
    doc = """
    Converts a WebAssembly module to a component.

    This rule uses wasm-tools to convert a core WASM module into
    a WebAssembly component, optionally with a WASI adapter.

    Example:
        wasm_component_new(
            name = "my_component",
            wasm_module = "my_module.wasm",
            adapter = "@wasi_preview1_adapter//file",
        )
    """,
)
