"""Component Checksum Registry API

This module provides a unified API for accessing OCI component checksums
from JSON files, mirroring the toolchain registry pattern.

The component registry enables:
1. Reproducible builds with digest-based pulls
2. Security auditing via centralized checksums
3. Air-gap builds with pre-verified components

Usage:
    load("//checksums:component_registry.bzl", "component_registry")

    # Get component digest for reproducible pulls
    digest = component_registry.get_digest(ctx, "wasi-http-proxy", "0.2.6")

    # Get full component info
    info = component_registry.get_info(ctx, "wasi-http-proxy", "0.2.6")
"""

def _load_component_json(repository_ctx, component_name):
    """Load component data from JSON file.

    Args:
        repository_ctx: Repository context for file operations
        component_name: Name of the component (e.g., 'wasi-http-proxy')

    Returns:
        Dict: Component data from JSON file

    Raises:
        fail: If JSON file not found
    """
    json_file = repository_ctx.path(
        Label("@rules_wasm_component//checksums/components:{}.json".format(component_name)),
    )
    if not json_file.exists:
        fail("Component checksums not found: //checksums/components/{}.json\n".format(component_name) +
             "Add the component to the registry or use vendored_component attribute.")

    content = repository_ctx.read(json_file)
    return json.decode(content)

def _get_component_digest(repository_ctx, component_name, version):
    """Get verified digest for a component version.

    Args:
        repository_ctx: Repository context for file operations
        component_name: Name of the component (e.g., 'wasi-http-proxy')
        version: Version string (e.g., '0.2.6')

    Returns:
        String: SHA256 digest in format 'sha256:abc123...', or None if not found
    """
    component_data = _load_component_json(repository_ctx, component_name)

    versions = component_data.get("versions", {})
    version_data = versions.get(version, {})

    return version_data.get("digest")

def _get_component_info(repository_ctx, component_name, version):
    """Get complete component information for a version.

    Args:
        repository_ctx: Repository context for file operations
        component_name: Name of the component
        version: Version string

    Returns:
        Dict: Complete version information including digest, wit_world, etc.
    """
    component_data = _load_component_json(repository_ctx, component_name)

    versions = component_data.get("versions", {})
    return versions.get(version)

def _get_latest_version(repository_ctx, component_name):
    """Get latest available version for a component.

    Args:
        repository_ctx: Repository context for file operations
        component_name: Name of the component

    Returns:
        String: Latest version, or None if component not found
    """
    component_data = _load_component_json(repository_ctx, component_name)
    return component_data.get("latest_version")

def _get_oci_repository(repository_ctx, component_name):
    """Get OCI repository URL for a component.

    Args:
        repository_ctx: Repository context for file operations
        component_name: Name of the component

    Returns:
        String: OCI repository URL (e.g., 'ghcr.io/bytecodealliance/wasi-http-proxy')
    """
    component_data = _load_component_json(repository_ctx, component_name)
    return component_data.get("oci_repository")

def _list_versions(repository_ctx, component_name):
    """List all available versions for a component.

    Args:
        repository_ctx: Repository context for file operations
        component_name: Name of the component

    Returns:
        List: List of version strings
    """
    component_data = _load_component_json(repository_ctx, component_name)
    versions = component_data.get("versions", {})
    return list(versions.keys())

def _verify_digest(repository_ctx, component_name, version, actual_digest):
    """Verify a component's digest against the registry.

    Args:
        repository_ctx: Repository context for file operations
        component_name: Name of the component
        version: Version string
        actual_digest: The digest to verify

    Returns:
        Boolean: True if digest matches, False otherwise
    """
    expected = _get_component_digest(repository_ctx, component_name, version)
    if not expected:
        return False
    return expected == actual_digest

# Public API
component_registry = struct(
    get_digest = _get_component_digest,
    get_info = _get_component_info,
    get_latest_version = _get_latest_version,
    get_oci_repository = _get_oci_repository,
    list_versions = _list_versions,
    verify_digest = _verify_digest,
)
