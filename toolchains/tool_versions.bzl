"""Single source of truth for tool versions

This file defines the canonical versions for all WebAssembly toolchain components.
All toolchain setup code MUST reference these constants to ensure version consistency.

TOOLCHAIN BUNDLES:
For validated, tested combinations of tool versions, see checksums/toolchain_bundles.json.
Bundles provide:
- Pre-tested tool version combinations
- Guaranteed compatibility
- Easy atomic upgrades

To use a bundle:
    wasm_component_toolchains(bundle = "stable-2025-12")

IMPORTANT: When updating versions here:
1. Update corresponding JSON registry in checksums/tools/<tool>.json
2. Verify compatibility using validate_tool_compatibility() in checksums/registry.bzl
3. Check embedded runtimes (rust_wasm_component_bindgen.bzl) for API compatibility
4. Update Cargo.toml dependencies if using the tool as a crate
5. Test the full build pipeline
6. Update checksums/toolchain_bundles.json with new validated combinations
"""

# Tool versions - single source of truth
TOOL_VERSIONS = {
    # Core WebAssembly toolchain
    "wasm-tools": "1.244.0",  # Component model tools (validate, parse, compose, etc.)
    "wasmtime": "39.0.1",  # WebAssembly runtime for testing/execution

    # WIT and binding generation
    "wit-bindgen": "0.49.0",  # WIT binding generator (MUST match Cargo.toml if used as crate)
    "wac": "0.8.1",  # WebAssembly Composition tool
    "wkg": "0.13.0",  # WebAssembly package manager

    # Note: wizer removed - now part of wasmtime v39.0.0+, use `wasmtime wizer` subcommand

    # Signatures and security
    "wasmsign2": "0.2.6",  # WebAssembly signing tool

    # WRPC (WebAssembly Component RPC)
    "wrpc": "0.16.0",  # wrpc-wasmtime runtime for component RPC
    "wit-bindgen-wrpc": "0.16.0",  # WIT binding generator for wrpc

    # Platform SDKs
    "wasi-sdk": "29",  # WASI SDK for C/C++ compilation
    "tinygo": "0.39.0",  # TinyGo compiler for Go→WASM

    # Node.js ecosystem
    "nodejs": "20.18.0",  # Node.js runtime for jco toolchain
}

# Compatibility matrix - defines which versions work together
# Key: wasm-tools version
# Value: Dict of compatible tool versions
TOOL_COMPATIBILITY_MATRIX = {
    "1.244.0": {
        "wit-bindgen": ["0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.8.0", "0.8.1"],
        "wkg": ["0.11.0", "0.12.0", "0.13.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["37.0.2", "39.0.1"],
    },
    "1.243.0": {
        "wit-bindgen": ["0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.8.0", "0.8.1"],
        "wkg": ["0.11.0", "0.12.0", "0.13.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["37.0.2", "39.0.1"],
    },
    "1.240.0": {
        "wit-bindgen": ["0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.7.0", "0.8.0", "0.8.1"],
        "wkg": ["0.11.0", "0.12.0", "0.13.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["27.0.0", "28.0.0", "37.0.2", "39.0.1"],
    },
    "1.239.0": {
        "wit-bindgen": ["0.43.0", "0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.7.0", "0.8.0", "0.8.1"],
        "wkg": ["0.11.0", "0.12.0", "0.13.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["27.0.0", "28.0.0", "37.0.2", "39.0.1"],
    },
    "1.235.0": {
        "wit-bindgen": ["0.43.0", "0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.7.0", "0.8.0", "0.8.1"],
        "wkg": ["0.11.0", "0.12.0", "0.13.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["27.0.0", "37.0.2", "39.0.1"],
    },
}

def get_tool_version(tool_name):
    """Returns the canonical version for the given tool name.

    Args:
        tool_name: The name of the tool (e.g., "wasm-tools", "wit-bindgen").

    Returns:
        The version string for the tool, or fails if tool_name is not defined.
    """
    if tool_name not in TOOL_VERSIONS:
        fail("Unknown tool: {}. Available tools: {}".format(
            tool_name,
            ", ".join(TOOL_VERSIONS.keys()),
        ))
    return TOOL_VERSIONS[tool_name]

def get_compatible_versions(base_tool, base_version):
    """Returns compatible versions for other tools based on a base tool version.

    Args:
        base_tool: The name of the base tool (usually "wasm-tools").
        base_version: The version of the base tool.

    Returns:
        A dict mapping tool names to lists of compatible versions, or an empty dict if no compatibility info is available.
    """
    if base_tool == "wasm-tools" and base_version in TOOL_COMPATIBILITY_MATRIX:
        return TOOL_COMPATIBILITY_MATRIX[base_version]
    return {}

def validate_tool_versions(tools_config):
    """Validates that a set of tool versions are compatible with each other.

    Args:
        tools_config: A dict mapping tool names to their versions.

    Returns:
        A list of warning messages (empty if all versions are compatible).
    """
    warnings = []

    # Check if wasm-tools is in the config
    if "wasm-tools" not in tools_config:
        return warnings

    wasm_tools_version = tools_config["wasm-tools"]
    compat_info = get_compatible_versions("wasm-tools", wasm_tools_version)

    if not compat_info:
        warnings.append(
            "Warning: No compatibility information for wasm-tools {}".format(wasm_tools_version),
        )
        return warnings

    # Check each tool against compatibility matrix
    for tool, version in tools_config.items():
        if tool == "wasm-tools":
            continue

        if tool in compat_info:
            if version not in compat_info[tool]:
                warnings.append(
                    "Warning: {} version {} may not be compatible with wasm-tools {}. " +
                    "Recommended versions: {}".format(
                        tool,
                        version,
                        wasm_tools_version,
                        ", ".join(compat_info[tool]),
                    ),
                )

    return warnings

def get_all_tool_versions():
    """Get all tool versions as a dict

    Returns:
        Dict: Copy of TOOL_VERSIONS
    """
    return dict(TOOL_VERSIONS)

# Export compatibility matrix for external use
def get_compatibility_matrix():
    """Get the full compatibility matrix

    Returns:
        Dict: Copy of TOOL_COMPATIBILITY_MATRIX
    """
    return dict(TOOL_COMPATIBILITY_MATRIX)
