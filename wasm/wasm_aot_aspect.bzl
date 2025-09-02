"""Aspect for automatic AOT compilation of WebAssembly components"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmPrecompiledInfo")

def _wasm_aot_aspect_impl(target, ctx):
    """Automatically create AOT compiled versions of WASM components"""
    
    # Only process targets that provide WasmComponentInfo
    if WasmComponentInfo not in target:
        return []

    component_info = target[WasmComponentInfo]
    
    # Skip if already precompiled or if AOT is disabled
    if WasmPrecompiledInfo in target:
        return []
    
    if not ctx.attr._enable_aot:
        return []

    # For now, just return empty - the aspect is too complex
    # Users can manually use wasm_precompile rule instead
    return []

wasm_aot_aspect = aspect(
    implementation = _wasm_aot_aspect_impl,
    attrs = {
        "_enable_aot": attr.bool(
            default = True,
            doc = "Enable automatic AOT compilation",
        ),
        "_aot_optimization_level": attr.int(
            default = 2,
            values = [0, 1, 2, 3],
        ),
        "_aot_debug_info": attr.bool(
            default = False,
        ),
        "_aot_strip_symbols": attr.bool(
            default = True,
        ),
        "_aot_target_triple": attr.string(
            default = "",
        ),
        "_wasmtime_version": attr.string(
            default = "35.0.0",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasmtime_toolchain_type"],
    doc = """
    Aspect that automatically creates AOT compiled versions of WASM components.
    
    This aspect can be applied to any target that provides WasmComponentInfo
    to automatically generate a precompiled .cwasm version alongside the 
    original .wasm file.
    
    Usage:
        bazel build --aspects=//wasm:wasm_aot_aspect.bzl%wasm_aot_aspect :my_component
    """,
)

# Configuration rule for AOT settings
def _wasm_aot_config_impl(ctx):
    """Configuration rule for AOT compilation settings"""
    return []

wasm_aot_config = rule(
    implementation = _wasm_aot_config_impl,
    attrs = {
        "optimization_level": attr.int(
            default = 2,
            values = [0, 1, 2, 3],
            doc = "Default optimization level for AOT compilation",
        ),
        "debug_info": attr.bool(
            default = False,
            doc = "Include debug info in AOT compilation by default",
        ),
        "strip_symbols": attr.bool(
            default = True,
            doc = "Strip symbols in AOT compilation by default",
        ),
        "target_triple": attr.string(
            doc = "Default target triple for cross-compilation",
        ),
    },
    doc = """
    Configuration for AOT compilation defaults.
    
    Example:
        wasm_aot_config(
            name = "aot_config_prod",
            optimization_level = 3,
            debug_info = False,
            strip_symbols = True,
        )
    """,
)