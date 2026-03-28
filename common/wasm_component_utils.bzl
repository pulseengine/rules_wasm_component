"""Shared utilities for WebAssembly component rules.

Eliminates duplication across language-specific rules by providing:
- Common attribute definitions (wasi_version, validate_wit)
- WasmComponentInfo factory function
- WIT info normalization (3 incompatible patterns → 1)
- Component validation action
"""

load("//providers:providers.bzl", "WasmComponentInfo", "WitInfo")

# =============================================================================
# Shared Attribute Definitions
# =============================================================================
# Note: attr.string/attr.bool can only be called inside rule() attrs dicts.
# These constants provide the kwargs to pass, not the attr objects themselves.

# wasi_version attribute kwargs — use as: "wasi_version": attr.string(**WASI_VERSION_ATTR_KWARGS)
WASI_VERSION_ATTR_KWARGS = {
    "default": "p2",
    "values": ["p2", "p3"],
    "doc": "WASI version: 'p2' (stable, default) or 'p3' (experimental async). " +
           "P3 requires wasmtime 43+, wit-bindgen 0.54+, wasi-sdk 32+.",
}

# validate_wit attribute kwargs
VALIDATE_WIT_ATTR_KWARGS = {
    "default": False,
    "doc": "Validate that the component exports match the WIT specification.",
}

# =============================================================================
# P3 Build Configuration
# =============================================================================

def get_p3_config(wasi_version):
    """Get P3-specific build configuration flags.

    Returns a struct with flags that language rules should apply when
    wasi_version = "p3". When wasi_version = "p2", all flags are empty/default.

    Args:
        wasi_version: "p2" or "p3"

    Returns:
        struct with:
            is_p3: bool
            wit_bindgen_async_args: list of --async flags for wit-bindgen
            wasmtime_flags: list of flags for wasmtime invocations
            wasi_cli_world: the WASI CLI world version string
    """
    if wasi_version == "p3":
        return struct(
            is_p3 = True,
            wit_bindgen_async_args = ["--async"],
            wasmtime_flags = ["-Sp3", "-Wcomponent-model-async"],
            wasi_cli_world = "wasi:cli/command@0.3.0",
        )
    return struct(
        is_p3 = False,
        wit_bindgen_async_args = [],
        wasmtime_flags = [],
        wasi_cli_world = "wasi:cli/command@0.2.0",
    )

# =============================================================================
# WIT Info Normalization
# =============================================================================

def normalize_wit_info(ctx, wit_attr = None, wit_file = None, package_name = None):
    """Normalize WIT information from different sources into a consistent format.

    Language rules use three incompatible patterns for WIT info:
    1. Rust/Go: ctx.attr.wit[WitInfo] provider
    2. Python/C++/JS: manual struct(wit_file=..., package_name=...)
    3. Python binary: struct(wit_file=None, package_name="wasi:cli@0.2.0")

    This function accepts any of these and returns a consistent result.

    Args:
        ctx: Rule context (used for label name fallback)
        wit_attr: The wit attribute value (may have WitInfo provider)
        wit_file: Direct wit file reference (for manual struct pattern)
        package_name: Package name override

    Returns:
        WitInfo provider or compatible struct, or None if no WIT info available.
    """
    if wit_attr and WitInfo in wit_attr:
        return wit_attr[WitInfo]

    if wit_file or package_name:
        return struct(
            wit_file = wit_file,
            package_name = package_name or "component:{}@1.0.0".format(ctx.label.name),
        )

    return None

# =============================================================================
# WasmComponentInfo Factory
# =============================================================================

def create_component_info(
        ctx,
        wasm_file,
        language,
        target = "wasm32-wasip2",
        wit_info = None,
        component_type = "component",
        imports = [],
        exports = [],
        profile = "release",
        profile_variants = {},
        extra_metadata = {}):
    """Create a WasmComponentInfo provider with consistent metadata.

    Replaces 7 near-identical WasmComponentInfo creation blocks across
    language-specific rules.

    Args:
        ctx: Rule context
        wasm_file: The compiled WASM component file
        language: Language name (e.g., "rust", "python", "go", "cpp", "javascript")
        target: Target triple (default: wasm32-wasip2)
        wit_info: WitInfo provider or compatible struct (use normalize_wit_info)
        component_type: "component" or "command"
        imports: List of imported interfaces
        exports: List of exported interfaces
        profile: Build profile name
        profile_variants: Dict of profile name → wasm file
        extra_metadata: Language-specific metadata fields

    Returns:
        WasmComponentInfo provider
    """
    metadata = {
        "name": ctx.label.name,
        "language": language,
        "target": target,
    }

    # Add wasi_version if the rule has it
    if hasattr(ctx.attr, "wasi_version"):
        metadata["wasi_version"] = ctx.attr.wasi_version

    # Merge language-specific metadata
    metadata.update(extra_metadata)

    return WasmComponentInfo(
        wasm_file = wasm_file,
        wit_info = wit_info,
        component_type = component_type,
        imports = imports,
        exports = exports,
        metadata = metadata,
        profile = profile,
        profile_variants = profile_variants,
    )

# =============================================================================
# Component Validation
# =============================================================================

def validate_component_action(ctx, wasm_file, wit_file = None):
    """Create a validation action for a WASM component.

    Provides consistent validation across all languages. Currently only
    Rust and Go implement validation; this makes it available to all.

    Args:
        ctx: Rule context (must have wasm_tools_toolchain_type in toolchains)
        wasm_file: The WASM component to validate
        wit_file: Optional WIT file for interface comparison

    Returns:
        List of output files (validation log), or empty list if validation disabled.
    """
    if not (hasattr(ctx.attr, "validate_wit") and ctx.attr.validate_wit):
        return []

    wasm_toolchain = ctx.toolchains.get("@rules_wasm_component//toolchains:wasm_tools_toolchain_type")
    if not wasm_toolchain:
        return []

    wasm_tools = wasm_toolchain.wasm_tools
    validation_log = ctx.actions.declare_file(ctx.attr.name + "_wit_validation.log")

    if wit_file:
        ctx.actions.run_shell(
            command = '''
            "$1" validate --features component-model "$2" 2>&1
            if [ $? -ne 0 ]; then
                echo "ERROR: Component validation failed for $2" > "$3"
                "$1" validate --features component-model "$2" >> "$3" 2>&1
                exit 1
            fi
            echo "=== COMPONENT VALIDATION PASSED ===" > "$3"
            echo "Component is valid WebAssembly with component model" >> "$3"
            echo "" >> "$3"
            echo "=== COMPONENT WIT INTERFACE ===" >> "$3"
            "$1" component wit "$2" >> "$3" 2>&1 || echo "Failed to extract WIT" >> "$3"
            echo "" >> "$3"
            echo "=== EXPECTED WIT SPECIFICATION ===" >> "$3"
            cat "$4" >> "$3"
            ''',
            arguments = [wasm_tools.path, wasm_file.path, validation_log.path, wit_file.path],
            inputs = [wasm_file, wit_file],
            outputs = [validation_log],
            tools = [wasm_tools],
            mnemonic = "ValidateWasmComponent",
            progress_message = "Validating WebAssembly component for %s" % ctx.label,
        )
    else:
        ctx.actions.run_shell(
            command = '''
            "$1" validate --features component-model "$2" 2>&1
            if [ $? -ne 0 ]; then
                echo "ERROR: Component validation failed for $2" > "$3"
                "$1" validate --features component-model "$2" >> "$3" 2>&1
                exit 1
            fi
            echo "=== COMPONENT VALIDATION PASSED ===" > "$3"
            echo "Component is valid WebAssembly with component model" >> "$3"
            echo "" >> "$3"
            echo "=== EXPORTED WIT INTERFACE ===" >> "$3"
            "$1" component wit "$2" >> "$3" 2>&1 || echo "Failed to extract WIT" >> "$3"
            ''',
            arguments = [wasm_tools.path, wasm_file.path, validation_log.path],
            inputs = [wasm_file],
            outputs = [validation_log],
            tools = [wasm_tools],
            mnemonic = "ValidateWasmComponent",
            progress_message = "Validating WebAssembly component for %s" % ctx.label,
        )

    return [validation_log]
