"""WASM Tools Component toolchain implementation"""

WasmToolsInfo = provider(
    doc = "WASM Tools Integration Component toolchain information",
    fields = {
        "wasm_tools_component": "The WASM Tools Integration Component executable",
        "wit_files": "WIT interface files for the component",
        "runtime_deps": "Runtime dependencies for the component",
    },
)

def _wasm_tools_component_toolchain_impl(ctx):
    """Implementation of the WASM Tools Component toolchain rule"""

    return [
        platform_common.ToolchainInfo(
            wasm_tools_info = WasmToolsInfo(
                wasm_tools_component = ctx.attr.wasm_tools_component,
                wit_files = ctx.files.wit_files,
                runtime_deps = ctx.files.runtime_deps,
            ),
        ),
    ]

wasm_tools_component_toolchain = rule(
    implementation = _wasm_tools_component_toolchain_impl,
    attrs = {
        "wasm_tools_component": attr.label(
            doc = "The WASM Tools Integration Component executable",
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "wit_files": attr.label_list(
            doc = "WIT interface files for the component",
            allow_files = [".wit"],
        ),
        "runtime_deps": attr.label_list(
            doc = "Runtime dependencies for the component",
            allow_files = True,
        ),
    },
    doc = "Defines a WASM Tools Integration Component toolchain",
)
