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

# Provider for WASM signature information
WasmSignatureInfo = provider(
    doc = "Information about WebAssembly component signatures",
    fields = {
        "signed_wasm": "Signed WASM component file",
        "signature_file": "Detached signature file (if applicable)",
        "public_key": "Public key file used for verification",
        "secret_key": "Secret key file used for signing (for key generation only)",
        "is_signed": "Boolean indicating if component is signed",
        "signature_type": "Type of signature (embedded, detached)",
        "signature_metadata": "Dict with signature details (key_id, algorithm, etc.)",
        "verification_status": "Verification result (verified, failed, not_checked)",
    },
)

# Provider for WASM key pair information
WasmKeyInfo = provider(
    doc = "Information about WebAssembly signing key pairs",
    fields = {
        "public_key": "Public key file",
        "secret_key": "Secret key file",
        "key_format": "Key format (compact, openssh, der, pem)",
        "key_metadata": "Dict with key information (algorithm, created_date, etc.)",
    },
)

# Provider for WASM OCI image information
WasmOciInfo = provider(
    doc = "Information about WebAssembly component OCI images",
    fields = {
        "image_ref": "Full OCI image reference (registry/namespace/name:tag)",
        "registry": "Registry URL",
        "namespace": "Registry namespace/organization",
        "name": "Component name",
        "tags": "List of image tags",
        "digest": "Image content digest (sha256:...)",
        "annotations": "Dict of OCI annotations",
        "manifest": "OCI manifest file (if available)",
        "config": "OCI config file (if available)",
        "component_file": "Associated WASM component file",
        "is_signed": "Boolean indicating if OCI image is signed",
        "signature_annotations": "Dict of signature-related annotations",
    },
)

# Provider for registry configuration and authentication
WasmRegistryInfo = provider(
    doc = "Information about WebAssembly component registry configuration",
    fields = {
        "registries": "Dict of registry name to configuration",
        "auth_configs": "Dict of registry to authentication configuration",
        "default_registry": "Default registry for operations",
        "config_file": "Generated wkg config file (if any)",
        "credentials": "Dict of registry credentials (tokens, usernames)",
    },
)

# Provider for WASM security policy information
WasmSecurityPolicyInfo = provider(
    doc = "Information about WebAssembly component security policies",
    fields = {
        "policy_file": "Security policy configuration file",
        "default_signing_required": "Boolean indicating if signing is required by default",
        "key_source": "Default key source (file, env, keychain)",
        "signature_type": "Default signature type (embedded, detached)",
        "openssh_format": "Boolean indicating if OpenSSH format is default",
    },
)

# Provider for WASM multi-architecture information
WasmMultiArchInfo = provider(
    doc = "Information about WebAssembly component multi-architecture builds",
    fields = {
        "architectures": "Dict of architecture name to component information",
        "manifest": "Multi-architecture manifest file",
        "default_architecture": "Default architecture for single-arch scenarios",
        "package_name": "Package name for the multi-arch component",
        "version": "Package version",
    },
)

# Provider for WASM component metadata extraction
WasmComponentMetadataInfo = provider(
    doc = "Information about extracted WebAssembly component metadata",
    fields = {
        "metadata_file": "JSON file containing extracted metadata",
        "component_file": "Source WebAssembly component file",
        "extraction_script": "Script used for metadata extraction",
    },
)

# Provider for WASM OCI metadata mapping
WasmOciMetadataMappingInfo = provider(
    doc = "Information about OCI metadata mapping for WebAssembly components",
    fields = {
        "mapping_file": "JSON file containing OCI annotation mapping",
        "oci_annotations": "Dict of OCI annotations",
        "component_info": "WasmComponentInfo provider",
        "metadata_sources": "List of metadata sources used",
    },
)
