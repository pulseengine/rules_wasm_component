"""Single source of truth for tool versions

This file defines the canonical versions for all WebAssembly toolchain components.
All toolchain setup code MUST reference these constants to ensure version consistency.

IMPORTANT: When updating versions here:
1. Update corresponding JSON registry in checksums/tools/<tool>.json
2. Verify compatibility using validate_tool_compatibility() in checksums/registry.bzl
3. Check embedded runtimes (rust_wasm_component_bindgen.bzl) for API compatibility
4. Update Cargo.toml dependencies if using the tool as a crate
5. Test the full build pipeline
"""

# Tool versions - single source of truth
TOOL_VERSIONS = {
    # Core WebAssembly toolchain
    "wasm-tools": "1.240.0",  # Component model tools (validate, parse, compose, etc.)
    "wasmtime": "28.0.0",     # WebAssembly runtime for testing/execution

    # WIT and binding generation
    "wit-bindgen": "0.49.0",  # WIT binding generator (MUST match Cargo.toml if used as crate)
    "wac": "0.8.0",           # WebAssembly Composition tool
    "wkg": "0.11.0",          # WebAssembly package manager

    # Optimization and initialization
    "wizer": "8.1.0",         # WebAssembly pre-initialization tool

    # Signatures and security
    "wasmsign2": "0.2.6",     # WebAssembly signing tool

    # Platform SDKs
    "wasi-sdk": "26",         # WASI SDK for C/C++ compilation
    "tinygo": "0.39.0",       # TinyGo compiler for Go→WASM

    # Node.js ecosystem
    "nodejs": "20.18.0",      # Node.js runtime for jco toolchain
}

# Compatibility matrix - defines which versions work together
# Key: wasm-tools version
# Value: Dict of compatible tool versions
TOOL_COMPATIBILITY_MATRIX = {
    "1.240.0": {
        "wit-bindgen": ["0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.7.0", "0.8.0"],
        "wkg": ["0.11.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["27.0.0", "28.0.0"],
    },
    "1.239.0": {
        "wit-bindgen": ["0.43.0", "0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.7.0", "0.8.0"],
        "wkg": ["0.11.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["27.0.0", "28.0.0"],
    },
    "1.235.0": {
        "wit-bindgen": ["0.43.0", "0.46.0", "0.48.1", "0.49.0"],
        "wac": ["0.7.0", "0.8.0"],
        "wkg": ["0.11.0"],
        "wasmsign2": ["0.2.6"],
        "wasmtime": ["27.0.0"],
    },
}

def get_tool_version(tool_name):
    """Get the canonical version for a tool

    Args:
        tool_name: Name of the tool (e.g., "wasm-tools", "wit-bindgen")

    Returns:
        String: Version number

    Fails:
        If tool_name is not defined in TOOL_VERSIONS
    """
    if tool_name not in TOOL_VERSIONS:
        fail("Unknown tool: {}. Available tools: {}".format(
            tool_name,
            ", ".join(TOOL_VERSIONS.keys())
        ))
    return TOOL_VERSIONS[tool_name]

def get_compatible_versions(base_tool, base_version):
    """Get compatible versions for other tools based on a base tool version

    Args:
        base_tool: Name of the base tool (usually "wasm-tools")
        base_version: Version of the base tool

    Returns:
        Dict: Mapping of tool names to list of compatible versions
        Empty dict if no compatibility info available
    """
    if base_tool == "wasm-tools" and base_version in TOOL_COMPATIBILITY_MATRIX:
        return TOOL_COMPATIBILITY_MATRIX[base_version]
    return {}

def validate_tool_versions(tools_config):
    """Validate that a set of tool versions are compatible

    Args:
        tools_config: Dict mapping tool names to versions

    Returns:
        List: List of warning messages (empty if all compatible)
    """
    warnings = []

    # Check if wasm-tools is in the config
    if "wasm-tools" not in tools_config:
        return warnings

    wasm_tools_version = tools_config["wasm-tools"]
    compat_info = get_compatible_versions("wasm-tools", wasm_tools_version)

    if not compat_info:
        warnings.append(
            "Warning: No compatibility information for wasm-tools {}".format(wasm_tools_version)
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
                    )
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
