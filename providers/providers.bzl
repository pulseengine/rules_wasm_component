"""Provider definitions for WebAssembly Component Model rules"""

# Provider for WIT library information
WitInfo = provider(
    doc = "Information about a WIT library",
    fields = {
        "wit_files": "Depset of WIT source files",
        "wit_deps": "Depset of WIT dependencies", 
        "package_name": "WIT package name",
        "world_name": "Optional world name",
        "interface_names": "List of interface names",
    },
)

# Provider for WASM component information
WasmComponentInfo = provider(
    doc = "Information about a WebAssembly component",
    fields = {
        "wasm_file": "The compiled WASM component file",
        "wit_info": "WitInfo provider from the component's interfaces",
        "component_type": "Type of component (module or component)",
        "imports": "List of imported interfaces",
        "exports": "List of exported interfaces",
        "metadata": "Component metadata dict",
        "profile": "Build profile (debug, release, custom)",
        "profile_variants": "Dict of profile -> wasm_file for multi-profile components",
    },
)

# Provider for WAC composition information
WacCompositionInfo = provider(
    doc = "Information about a WAC composition",
    fields = {
        "composed_wasm": "The composed WASM file",
        "components": "Dict of component name to WasmComponentInfo",
        "composition_wit": "WIT file describing the composition",
        "instantiations": "List of component instantiations",
        "connections": "List of inter-component connections",
    },
)

# Provider for WASM validation results
WasmValidationInfo = provider(
    doc = "Results from WASM validation",
    fields = {
        "is_valid": "Whether the WASM is valid",
        "validation_log": "Validation output log file",
        "errors": "List of validation errors",
        "warnings": "List of validation warnings",
    },
)