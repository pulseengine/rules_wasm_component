"""Rust WASM component test rule"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _rust_wasm_component_test_impl(ctx):
    """Implementation of rust_wasm_component_test rule"""
    
    # Get component info
    component_info = ctx.attr.component[WasmComponentInfo]
    
    # Create test script
    test_script = ctx.actions.declare_file(ctx.label.name + "_test.sh")
    
    # Get wasmtime from toolchain (if available)
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = toolchain.wasm_tools
    
    # Generate test script
    ctx.actions.write(
        output = test_script,
        content = """#!/bin/bash
set -e

# Validate component
echo "Validating WASM component..."
{wasm_tools} validate {component_wasm}

# TODO: Run component with wasmtime if available
echo "✅ Component validation passed"
""".format(
            wasm_tools = wasm_tools.path,
            component_wasm = component_info.wasm_file.path,
        ),
        is_executable = True,
    )
    
    return [
        DefaultInfo(
            executable = test_script,
            runfiles = ctx.runfiles(
                files = [component_info.wasm_file, wasm_tools],
            ),
        ),
    ]

rust_wasm_component_test = rule(
    implementation = _rust_wasm_component_test_impl,
    attrs = {
        "component": attr.label(
            providers = [WasmComponentInfo],
            mandatory = True,
            doc = "WASM component to test",
        ),
    },
    test = True,
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
    Test rule for Rust WASM components.
    
    This rule validates WASM components and can run basic tests.
    
    Example:
        rust_wasm_component_test(
            name = "my_component_test",
            component = ":my_component",
        )
    """,
)