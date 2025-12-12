"""Toolchain bundle management for rules_wasm_component.

This module provides functions to load and validate toolchain version bundles,
ensuring compatible tool versions are used together.
"""

# Bundle status values
BUNDLE_STATUS_STABLE = "stable"
BUNDLE_STATUS_BETA = "beta"
BUNDLE_STATUS_DEPRECATED = "deprecated"

def _read_bundles_json(repository_ctx):
    """Read the toolchain_bundles.json file.

    Args:
        repository_ctx: Repository context for file operations.

    Returns:
        Parsed JSON dict or None if file doesn't exist.
    """
    bundles_path = repository_ctx.path(Label("//checksums:toolchain_bundles.json"))
    if not bundles_path.exists:
        return None
    content = repository_ctx.read(bundles_path)
    return json.decode(content)

def get_bundle(repository_ctx, bundle_name = None):
    """Get a toolchain bundle by name.

    Args:
        repository_ctx: Repository context for file operations.
        bundle_name: Name of the bundle to get. If None, uses default bundle.

    Returns:
        Dict containing bundle configuration, or None if not found.
    """
    bundles_data = _read_bundles_json(repository_ctx)
    if not bundles_data:
        return None

    if not bundle_name:
        bundle_name = bundles_data.get("default_bundle", "stable-2025-12")

    bundles = bundles_data.get("bundles", {})
    return bundles.get(bundle_name)

def get_bundle_tool_version(repository_ctx, bundle_name, tool_name):
    """Get a specific tool version from a bundle.

    Args:
        repository_ctx: Repository context for file operations.
        bundle_name: Name of the bundle.
        tool_name: Name of the tool (e.g., "wasm-tools", "wit-bindgen").

    Returns:
        Version string or None if not found.
    """
    bundle = get_bundle(repository_ctx, bundle_name)
    if not bundle:
        return None

    tools = bundle.get("tools", {})
    return tools.get(tool_name)

def get_all_bundle_names(repository_ctx):
    """Get list of all available bundle names.

    Args:
        repository_ctx: Repository context for file operations.

    Returns:
        List of bundle name strings.
    """
    bundles_data = _read_bundles_json(repository_ctx)
    if not bundles_data:
        return []

    return list(bundles_data.get("bundles", {}).keys())

def get_default_bundle_name(repository_ctx):
    """Get the default bundle name.

    Args:
        repository_ctx: Repository context for file operations.

    Returns:
        Default bundle name string.
    """
    bundles_data = _read_bundles_json(repository_ctx)
    if not bundles_data:
        return "stable-2025-12"

    return bundles_data.get("default_bundle", "stable-2025-12")

def validate_bundle(repository_ctx, bundle_name):
    """Validate that a bundle exists and has required tools.

    Args:
        repository_ctx: Repository context for file operations.
        bundle_name: Name of the bundle to validate.

    Returns:
        Tuple of (is_valid, error_message).
    """
    bundle = get_bundle(repository_ctx, bundle_name)
    if not bundle:
        available = get_all_bundle_names(repository_ctx)
        return (False, "Bundle '{}' not found. Available bundles: {}".format(
            bundle_name, ", ".join(available) if available else "none"))

    # Check required fields
    required_fields = ["tools", "compatibility"]
    for field in required_fields:
        if field not in bundle:
            return (False, "Bundle '{}' is missing required field: {}".format(
                bundle_name, field))

    # Check tools is non-empty
    if not bundle.get("tools"):
        return (False, "Bundle '{}' has no tools defined".format(bundle_name))

    # Check status is not deprecated (warn only)
    status = bundle.get("status", BUNDLE_STATUS_STABLE)
    if status == BUNDLE_STATUS_DEPRECATED:
        # We still allow deprecated bundles but could log a warning
        pass

    return (True, None)

def resolve_tool_versions(repository_ctx, bundle_name = None, overrides = None):
    """Resolve tool versions from a bundle with optional overrides.

    This is the main entry point for toolchains to get their versions.

    Args:
        repository_ctx: Repository context for file operations.
        bundle_name: Name of the bundle to use. If None, uses default.
        overrides: Dict of tool_name -> version to override bundle versions.

    Returns:
        Dict of tool_name -> version for all tools in the bundle.
    """
    bundle = get_bundle(repository_ctx, bundle_name)
    if not bundle:
        # Fall back to empty dict if no bundle found
        return overrides or {}

    # Start with bundle tools
    versions = dict(bundle.get("tools", {}))

    # Apply overrides
    if overrides:
        for tool, version in overrides.items():
            versions[tool] = version

    return versions

def print_bundle_info(repository_ctx, bundle_name = None):
    """Print information about a bundle (for debugging/diagnostics).

    Args:
        repository_ctx: Repository context for file operations.
        bundle_name: Name of the bundle. If None, uses default.

    Returns:
        Formatted string with bundle information.
    """
    bundle = get_bundle(repository_ctx, bundle_name)
    if not bundle:
        return "Bundle not found: {}".format(bundle_name or "default")

    lines = []
    lines.append("Bundle: {}".format(bundle_name or get_default_bundle_name(repository_ctx)))
    lines.append("Description: {}".format(bundle.get("description", "N/A")))
    lines.append("Status: {}".format(bundle.get("status", "unknown")))
    lines.append("Release Date: {}".format(bundle.get("release_date", "N/A")))
    lines.append("")
    lines.append("Tools:")
    for tool, version in sorted(bundle.get("tools", {}).items()):
        lines.append("  {}: {}".format(tool, version))

    compat = bundle.get("compatibility", {})
    if compat:
        lines.append("")
        lines.append("Compatibility:")
        lines.append("  Component Model: {}".format(compat.get("component_model_version", "N/A")))
        lines.append("  WASI Version: {}".format(compat.get("wasi_version", "N/A")))

    platforms = bundle.get("tested_platforms", [])
    if platforms:
        lines.append("")
        lines.append("Tested Platforms: {}".format(", ".join(platforms)))

    notes = bundle.get("notes")
    if notes:
        lines.append("")
        lines.append("Notes: {}".format(notes))

    return "\n".join(lines)

def get_version_for_tool(repository_ctx, tool_name, bundle_name = None, fallback_version = None):
    """Get version for a specific tool from bundle, with fallback support.

    This is the main entry point for toolchain repository rules to get their version.

    Args:
        repository_ctx: Repository context for file operations.
        tool_name: Name of the tool (e.g., "wasm-tools", "wasmtime").
        bundle_name: Name of the bundle to use. If empty/None, uses default bundle.
        fallback_version: Version to use if tool not found in bundle.

    Returns:
        Version string for the tool.
    """
    # If no bundle specified, try to use default
    effective_bundle = bundle_name if bundle_name else None

    version = get_bundle_tool_version(repository_ctx, effective_bundle, tool_name)

    if version:
        return version

    # Tool not in bundle - use fallback or fail
    if fallback_version:
        return fallback_version

    # No fallback - check if bundle exists but doesn't have this tool
    bundle = get_bundle(repository_ctx, effective_bundle)
    if bundle:
        available_tools = list(bundle.get("tools", {}).keys())
        fail("Tool '{}' not found in bundle '{}'. Available tools: {}".format(
            tool_name,
            effective_bundle or get_default_bundle_name(repository_ctx),
            ", ".join(available_tools) if available_tools else "none",
        ))

    # No bundle found at all - fail with helpful message
    fail("Could not determine version for tool '{}'. No bundle found and no fallback specified.".format(tool_name))

def log_bundle_usage(repository_ctx, tool_name, version, bundle_name = None):
    """Log which version is being used from which bundle (for debugging).

    Args:
        repository_ctx: Repository context for file operations.
        tool_name: Name of the tool.
        version: Version being used.
        bundle_name: Bundle name (or None for default).
    """
    effective_bundle = bundle_name or get_default_bundle_name(repository_ctx)
    # buildifier: disable=print
    print("Bundle '{}': using {} version {}".format(effective_bundle, tool_name, version))

# Public API
bundle_api = struct(
    get_bundle = get_bundle,
    get_bundle_tool_version = get_bundle_tool_version,
    get_all_bundle_names = get_all_bundle_names,
    get_default_bundle_name = get_default_bundle_name,
    validate_bundle = validate_bundle,
    resolve_tool_versions = resolve_tool_versions,
    print_bundle_info = print_bundle_info,
    get_version_for_tool = get_version_for_tool,
    log_bundle_usage = log_bundle_usage,

    # Constants
    STATUS_STABLE = BUNDLE_STATUS_STABLE,
    STATUS_BETA = BUNDLE_STATUS_BETA,
    STATUS_DEPRECATED = BUNDLE_STATUS_DEPRECATED,
)
