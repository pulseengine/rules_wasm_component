"""Unified Tool Registry - Single API for all toolchain downloads

This module consolidates ~500 lines of duplicate download logic across toolchains
into a single, unified API. All toolchains should use this instead of implementing
their own platform detection, URL construction, and download logic.

Usage:
    load("//toolchains:tool_registry.bzl", "tool_registry")

    # In repository rule implementation:
    platform = tool_registry.detect_platform(ctx)
    tool_registry.download(ctx, "wasm-tools", "1.243.0", platform)
"""

load("//checksums:registry.bzl", "get_github_repo", "get_tool_checksum", "get_tool_info")

# =============================================================================
# Platform Detection (Single Implementation)
# =============================================================================

def _detect_platform(repository_ctx):
    """Detect the host platform in normalized format.

    This is the SINGLE source of truth for platform detection.
    All toolchains should use this instead of implementing their own.

    Args:
        repository_ctx: Bazel repository context

    Returns:
        String in format "{os}_{arch}" e.g., "darwin_arm64", "linux_amd64"
    """
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    # Normalize OS names
    if "mac" in os_name or "darwin" in os_name:
        os_name = "darwin"
    elif "windows" in os_name:
        os_name = "windows"
    elif "linux" in os_name:
        os_name = "linux"

    # Normalize architecture names
    if arch in ["x86_64", "amd64"]:
        arch = "amd64"
    elif arch in ["aarch64", "arm64"]:
        arch = "arm64"

    return "{}_{}".format(os_name, arch)

# =============================================================================
# URL Pattern Handlers (Tool-Specific)
# =============================================================================

# Each tool has different URL patterns. These are centralized here.
_URL_PATTERNS = {
    "wasm-tools": {
        "base": "https://github.com/{repo}/releases/download/v{version}",
        "filename": "wasm-tools-{version}-{suffix}",
    },
    "wit-bindgen": {
        "base": "https://github.com/{repo}/releases/download/v{version}",
        "filename": "wit-bindgen-{version}-{suffix}",
    },
    "wasmtime": {
        "base": "https://github.com/{repo}/releases/download/v{version}",
        "filename": "wasmtime-v{version}-{suffix}",
    },
    "wac": {
        "base": "https://github.com/{repo}/releases/download/v{version}",
        "filename": "wac-cli-{platform_name}",
        "is_binary": True,  # wac releases are standalone binaries
    },
    "wkg": {
        # wkg releases are standalone binaries, not archives
        "base": "https://github.com/{repo}/releases/download/v{version}",
        "filename": "{binary_name}",
        "is_binary": True,  # Download as binary, not archive
    },
    "wasi-sdk": {
        "base": "https://github.com/{repo}/releases/download/wasi-sdk-{version}",
        "filename": "wasi-sdk-{version}.0-{suffix}",
    },
    "nodejs": {
        "base": "https://nodejs.org/dist/v{version}",
        "filename": "node-v{version}-{suffix}",
    },
    "tinygo": {
        "base": "https://github.com/{repo}/releases/download/v{version}",
        "filename": "tinygo{version}.{suffix}",
    },
}

def _build_download_url(tool_name, version, platform, tool_info, github_repo):
    """Build the download URL for a tool.

    Args:
        tool_name: Name of the tool
        version: Version to download
        platform: Platform string (e.g., "darwin_arm64")
        tool_info: Tool info dict from registry
        github_repo: GitHub repo in "owner/repo" format

    Returns:
        Download URL string
    """
    pattern = _URL_PATTERNS.get(tool_name)
    if not pattern:
        fail("No URL pattern defined for tool '{}'. Add it to _URL_PATTERNS.".format(tool_name))

    base_url = pattern["base"].format(
        repo = github_repo,
        version = version,
    )

    # Get filename pattern fields from tool_info
    filename_params = {
        "version": version,
        "suffix": tool_info.get("url_suffix", ""),
        "platform_name": tool_info.get("platform_name", ""),
        "binary_name": tool_info.get("binary_name", ""),
    }

    filename = pattern["filename"].format(**filename_params)

    return "{}/{}".format(base_url, filename)

# =============================================================================
# Download Functions
# =============================================================================

def _download_tool(repository_ctx, tool_name, version, platform = None, output_name = None):
    """Download a tool with checksum verification from the centralized registry.

    This is the SINGLE download function all toolchains should use.

    Args:
        repository_ctx: Bazel repository context
        tool_name: Name of the tool (e.g., "wasm-tools", "wasmtime")
        version: Version to download
        platform: Platform string (auto-detected if None)
        output_name: Custom output name for the binary (optional)

    Returns:
        Dict with download results:
            - binary_path: Path to the main binary
            - extract_dir: Directory where files were extracted (if applicable)
    """
    if platform == None:
        platform = _detect_platform(repository_ctx)

    # Get tool info from centralized registry
    tool_info = get_tool_info(tool_name, version, platform)
    if not tool_info:
        fail("Tool '{}' version '{}' platform '{}' not found in registry. Check //checksums/tools/{}.json".format(
            tool_name, version, platform, tool_name))

    # Get checksum
    checksum = get_tool_checksum(tool_name, version, platform)
    if not checksum:
        fail("No checksum found for {} {} {}".format(tool_name, version, platform))

    # Get GitHub repo
    github_repo = get_github_repo(tool_name)
    if not github_repo:
        fail("No GitHub repo found for tool '{}'".format(tool_name))

    # Build URL
    url = _build_download_url(tool_name, version, platform, tool_info, github_repo)

    print("Downloading {} {} for {} from: {}".format(tool_name, version, platform, url))

    # Check if this is a binary download (no extraction)
    pattern = _URL_PATTERNS.get(tool_name, {})
    is_binary = pattern.get("is_binary", False)

    if is_binary:
        # Direct binary download
        binary_name = output_name or tool_info.get("binary_name", tool_name)
        repository_ctx.download(
            url = url,
            output = binary_name,
            sha256 = checksum,
            executable = True,
        )
        return {
            "binary_path": binary_name,
            "extract_dir": None,
        }

    # Archive download - determine type from URL suffix
    url_suffix = tool_info.get("url_suffix", "")
    if url_suffix.endswith(".tar.gz"):
        archive_type = "tar.gz"
    elif url_suffix.endswith(".tar.xz"):
        archive_type = "tar.xz"
    elif url_suffix.endswith(".zip"):
        archive_type = "zip"
    else:
        archive_type = "tar.gz"  # Default

    # Calculate strip prefix for extraction
    strip_prefix = _calculate_strip_prefix(tool_name, version, tool_info)

    repository_ctx.download_and_extract(
        url = url,
        sha256 = checksum,
        type = archive_type,
        stripPrefix = strip_prefix,
    )

    # Find the binary after extraction
    binary_path = _find_binary_after_extract(repository_ctx, tool_name, platform, output_name)

    return {
        "binary_path": binary_path,
        "extract_dir": ".",
    }

def _calculate_strip_prefix(tool_name, version, tool_info):
    """Calculate the strip prefix for archive extraction.

    Args:
        tool_name: Name of the tool
        version: Version being downloaded
        tool_info: Tool info from registry

    Returns:
        String prefix to strip, or empty string
    """
    url_suffix = tool_info.get("url_suffix", "")

    # Tool-specific strip prefix patterns
    if tool_name == "wasmtime":
        # wasmtime-v39.0.1-aarch64-macos.tar.xz -> wasmtime-v39.0.1-aarch64-macos
        return "wasmtime-v{}-{}".format(version, url_suffix.replace(".tar.xz", "").replace(".zip", ""))
    elif tool_name == "wasm-tools":
        # wasm-tools-1.243.0-aarch64-macos.tar.gz -> wasm-tools-1.243.0-aarch64-macos
        return "wasm-tools-{}-{}".format(version, url_suffix.replace(".tar.gz", "").replace(".zip", ""))
    elif tool_name == "wit-bindgen":
        return "wit-bindgen-{}-{}".format(version, url_suffix.replace(".tar.gz", "").replace(".zip", ""))
    elif tool_name == "wac":
        platform_name = tool_info.get("platform_name", "")
        return "wac-v{}-{}".format(version, platform_name)
    elif tool_name == "wasi-sdk":
        return "wasi-sdk-{}.0".format(version)
    elif tool_name == "nodejs":
        return ""  # Node.js has complex directory structure
    elif tool_name == "tinygo":
        return "tinygo"

    return ""

def _find_binary_after_extract(repository_ctx, tool_name, platform, output_name = None):
    """Find the main binary after archive extraction.

    Args:
        repository_ctx: Repository context
        tool_name: Name of the tool
        platform: Platform string
        output_name: Optional custom output name

    Returns:
        Path to the binary (symlinked if needed)
    """
    target_name = output_name or tool_name
    is_windows = platform.startswith("windows")
    exe_suffix = ".exe" if is_windows else ""

    # Common binary locations to check
    possible_paths = [
        tool_name + exe_suffix,
        "bin/" + tool_name + exe_suffix,
        tool_name + "/" + tool_name + exe_suffix,
    ]

    for path in possible_paths:
        if repository_ctx.path(path).exists:
            if path != target_name + exe_suffix:
                repository_ctx.symlink(path, target_name + exe_suffix)
            return target_name + exe_suffix

    # Binary should exist at root after strip_prefix
    return tool_name + exe_suffix

# =============================================================================
# Public API (struct for namespacing)
# =============================================================================

tool_registry = struct(
    # Core functions
    detect_platform = _detect_platform,
    download = _download_tool,
    build_url = _build_download_url,
)
