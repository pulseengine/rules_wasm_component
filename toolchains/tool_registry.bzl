"""Unified Tool Registry - Single API for all toolchain downloads

This module consolidates ~500 lines of duplicate download logic across toolchains
into a single, unified API. All toolchains should use this instead of implementing
their own platform detection, URL construction, and download logic.

Usage:
    load("//toolchains:tool_registry.bzl", "tool_registry")

    # In repository rule implementation:
    platform = tool_registry.detect_platform(ctx)
    tool_registry.download(ctx, "wasm-tools", "1.243.0", platform)

Enterprise/Air-Gap Support:
    The registry respects these environment variables for enterprise deployments:

    BAZEL_WASM_OFFLINE=1
        Use vendored files from third_party/toolchains/ (must run vendor workflow first)

    BAZEL_WASM_VENDOR_DIR=/path/to/vendor
        Use custom vendor directory (e.g., NFS mount for shared cache)

    BAZEL_WASM_MIRROR=https://mirror.company.com
        Download from corporate mirror instead of public URLs
        Mirror structure: {mirror}/{tool}/{version}/{platform}/{filename}

    Example .bazelrc for enterprise:
        common --repo_env=BAZEL_WASM_VENDOR_DIR=/mnt/shared/wasm-tools
        common --repo_env=BAZEL_NPM_REGISTRY=https://npm.company.com

    Vendor workflow (run once by IT):
        bazel fetch @vendored_toolchains//...
        bazel run @vendored_toolchains//:export_to_third_party
        rsync -av third_party/toolchains/ /mnt/shared/wasm-tools/
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
        # wkg releases are standalone binaries (url_suffix contains full filename)
        "base": "https://github.com/{repo}/releases/download/v{version}",
        "filename": "{suffix}",  # url_suffix IS the filename (e.g., "wkg-aarch64-apple-darwin")
        "is_binary": True,
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
    "go": {
        "base": "https://go.dev/dl",
        "filename": "go{version}.{suffix}",
    },
    "binaryen": {
        "base": "https://github.com/{repo}/releases/download/version_{version}",
        "filename": "binaryen-version_{version}-{suffix}",
    },
    "componentize-py": {
        # componentize-py releases use tag name directly (e.g., "canary"), no 'v' prefix
        "base": "https://github.com/{repo}/releases/download/{version}",
        "filename": "componentize-py-{version}-{suffix}",
    },
}

def _build_download_url(tool_name, version, platform, tool_info, github_repo):
    """Build the download URL for a tool.

    Args:
        tool_name: Name of the tool
        version: Version to download
        platform: Platform string (e.g., "darwin_arm64")
        tool_info: Tool info dict from registry
        github_repo: GitHub repo in "owner/repo" format (can be None for non-GitHub tools)

    Returns:
        Download URL string
    """
    pattern = _URL_PATTERNS.get(tool_name)
    if not pattern:
        fail("No URL pattern defined for tool '{}'. Add it to _URL_PATTERNS.".format(tool_name))

    # Build base URL - handle both GitHub and non-GitHub tools
    base_template = pattern["base"]
    if "{repo}" in base_template:
        if not github_repo:
            fail("Tool '{}' requires github_repo but none provided".format(tool_name))
        base_url = base_template.format(repo = github_repo, version = version)
    else:
        base_url = base_template.format(version = version)

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
# Enterprise/Air-Gap Source Resolution
# =============================================================================

def _resolve_download_source(repository_ctx, tool_name, version, platform, default_url, filename):
    """Resolve download source with enterprise air-gap support.

    Checks environment variables in priority order:
    1. BAZEL_WASM_OFFLINE=1 - Use vendored files from third_party/toolchains/
    2. BAZEL_WASM_VENDOR_DIR - Custom vendor directory (NFS/shared)
    3. BAZEL_WASM_MIRROR - Single mirror for all tools
    4. Default URL (github.com, go.dev, nodejs.org, etc.)

    Args:
        repository_ctx: Bazel repository context
        tool_name: Name of the tool (e.g., "wasm-tools")
        version: Version string (e.g., "1.243.0")
        platform: Platform string (e.g., "darwin_arm64")
        default_url: Default download URL
        filename: Filename portion of the URL

    Returns:
        struct with:
            type: "local" or "url"
            path: Local file path (if type == "local")
            url: Download URL (if type == "url")
    """
    # Priority 1: Offline mode with default vendor path
    offline_mode = repository_ctx.os.environ.get("BAZEL_WASM_OFFLINE", "0") == "1"
    if offline_mode:
        # Try workspace-relative path first
        vendor_path = repository_ctx.path(
            repository_ctx.workspace_root
        ).dirname.get_child("third_party").get_child("toolchains").get_child(tool_name).get_child(version).get_child(platform).get_child(filename)
        if vendor_path.exists:
            print("OFFLINE: Using vendored {} from {}".format(tool_name, vendor_path))
            return struct(type = "local", path = str(vendor_path), url = None)

        # Fall through to try vendor dir or fail
        print("WARNING: BAZEL_WASM_OFFLINE=1 but {} not found at {}".format(tool_name, vendor_path))

    # Priority 2: Custom vendor directory (NFS/shared)
    vendor_dir = repository_ctx.os.environ.get("BAZEL_WASM_VENDOR_DIR")
    if vendor_dir:
        vendor_path = repository_ctx.path(vendor_dir).get_child(tool_name).get_child(version).get_child(platform).get_child(filename)
        if vendor_path.exists:
            print("Using vendored {} from {}".format(tool_name, vendor_path))
            return struct(type = "local", path = str(vendor_path), url = None)

        # Warn but don't fail - fall through to mirror or default
        print("WARNING: BAZEL_WASM_VENDOR_DIR set but {} not found at {}".format(tool_name, vendor_path))

    # Priority 3: Mirror URL
    mirror = repository_ctx.os.environ.get("BAZEL_WASM_MIRROR")
    if mirror:
        mirror_url = "{}/{}/{}/{}/{}".format(
            mirror.rstrip("/"),
            tool_name,
            version,
            platform,
            filename,
        )
        print("Using mirror for {}: {}".format(tool_name, mirror_url))
        return struct(type = "url", url = mirror_url, path = None)

    # Priority 4: Strict offline mode - fail if offline but no vendor found
    if offline_mode:
        fail("BAZEL_WASM_OFFLINE=1 but {} version {} for {} not found in vendor directories".format(
            tool_name, version, platform,
        ))

    # Default: use original URL
    return struct(type = "url", url = default_url, path = None)

def _get_download_filename(tool_name, version, tool_info):
    """Extract the download filename from tool info.

    Args:
        tool_name: Name of the tool
        version: Version string
        tool_info: Tool info dict from registry

    Returns:
        Filename string
    """
    url_suffix = tool_info.get("url_suffix", "")

    # For binary downloads, use the binary_name
    if tool_info.get("binary_name"):
        return tool_info.get("binary_name")

    # For archives, construct filename based on tool pattern
    pattern = _URL_PATTERNS.get(tool_name, {})
    filename_template = pattern.get("filename", "{tool_name}-{version}.tar.gz")

    return filename_template.format(
        version = version,
        suffix = url_suffix,
        platform_name = tool_info.get("platform_name", ""),
        binary_name = tool_info.get("binary_name", ""),
    )

# =============================================================================
# Download Functions
# =============================================================================

def _download_tool(repository_ctx, tool_name, version, platform = None, output_name = None, output_dir = None):
    """Download a tool with checksum verification from the centralized registry.

    This is the SINGLE download function all toolchains should use.

    Args:
        repository_ctx: Bazel repository context
        tool_name: Name of the tool (e.g., "wasm-tools", "wasmtime")
        version: Version to download
        platform: Platform string (auto-detected if None)
        output_name: Custom output name for the binary (optional)
        output_dir: Directory to extract to (optional, defaults to repo root)

    Returns:
        Dict with download results:
            - binary_path: Path to the main binary
            - extract_dir: Directory where files were extracted (if applicable)
            - tool_info: Full tool info dict from registry (for custom paths like npm_path)
    """
    if platform == None:
        platform = _detect_platform(repository_ctx)

    # Get tool info from centralized registry
    tool_info = get_tool_info(repository_ctx, tool_name, version, platform)
    if not tool_info:
        fail("Tool '{}' version '{}' platform '{}' not found in registry. Check //checksums/tools/{}.json".format(
            tool_name, version, platform, tool_name))

    # Get checksum
    checksum = get_tool_checksum(repository_ctx, tool_name, version, platform)
    if not checksum:
        fail("No checksum found for {} {} {}".format(tool_name, version, platform))

    # Get GitHub repo (optional - some tools like Go use go.dev, not GitHub)
    github_repo = get_github_repo(repository_ctx, tool_name)

    # Build default URL
    default_url = _build_download_url(tool_name, version, platform, tool_info, github_repo)

    # Get filename for enterprise source resolution
    filename = _get_download_filename(tool_name, version, tool_info)

    # Resolve download source (handles offline/mirror/vendor)
    source = _resolve_download_source(
        repository_ctx,
        tool_name,
        version,
        platform,
        default_url,
        filename,
    )

    # Check if this is a binary download (no extraction)
    pattern = _URL_PATTERNS.get(tool_name, {})
    is_binary = pattern.get("is_binary", False)

    # Archive type detection
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

    # Determine output directory
    extract_dir = output_dir if output_dir else "."

    if source.type == "local":
        # Use vendored files - symlink or extract from local path
        print("Using local vendored {} from: {}".format(tool_name, source.path))

        if is_binary:
            binary_name = output_name or tool_info.get("binary_name", tool_name)
            if output_dir:
                binary_path = "{}/{}".format(output_dir, binary_name)
            else:
                binary_path = binary_name
            repository_ctx.symlink(source.path, binary_path)
            # Make executable
            repository_ctx.execute(["chmod", "+x", binary_path])
            return {
                "binary_path": binary_path,
                "extract_dir": extract_dir,
                "tool_info": tool_info,
            }
        else:
            # Extract from local archive (no checksum needed - already verified during vendor)
            repository_ctx.extract(
                source.path,
                output = output_dir if output_dir else "",
                type = archive_type,
                stripPrefix = strip_prefix,
            )
    else:
        # Download from URL (mirror or default)
        actual_url = source.url
        print("Downloading {} {} for {} from: {}".format(tool_name, version, platform, actual_url))

        if is_binary:
            # Direct binary download
            binary_name = output_name or tool_info.get("binary_name", tool_name)
            if output_dir:
                binary_path = "{}/{}".format(output_dir, binary_name)
            else:
                binary_path = binary_name
            repository_ctx.download(
                url = actual_url,
                output = binary_path,
                sha256 = checksum,
                executable = True,
            )
            return {
                "binary_path": binary_path,
                "extract_dir": extract_dir,
                "tool_info": tool_info,
            }

        repository_ctx.download_and_extract(
            url = actual_url,
            output = output_dir if output_dir else "",
            sha256 = checksum,
            type = archive_type,
            stripPrefix = strip_prefix,
        )

    # Find the binary after extraction
    binary_path = _find_binary_after_extract(repository_ctx, tool_name, version, platform, tool_info, output_name, output_dir)

    return {
        "binary_path": binary_path,
        "extract_dir": extract_dir,
        "tool_info": tool_info,
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
        # WASI SDK archive contains versioned+platform directory: wasi-sdk-29.0-arm64-macos/
        url_suffix = tool_info.get("url_suffix", "")
        # Extract platform part from url_suffix (e.g., "arm64-macos.tar.gz" -> "arm64-macos")
        platform_part = url_suffix.replace(".tar.gz", "").replace(".zip", "")
        return "wasi-sdk-{}.0-{}".format(version, platform_part)
    elif tool_name == "nodejs":
        # Node.js keeps its directory structure (node-v20.18.0-darwin-arm64/)
        # Paths are accessed via tool_info["binary_path"] and tool_info["npm_path"]
        return ""
    elif tool_name == "tinygo":
        return "tinygo"
    elif tool_name == "go":
        return "go"  # Go SDK extracts to "go" directory
    elif tool_name == "binaryen":
        return "binaryen-version_{}".format(version)

    return ""

def _find_binary_after_extract(repository_ctx, tool_name, version, platform, tool_info, output_name = None, output_dir = None):
    """Find the main binary after archive extraction.

    Args:
        repository_ctx: Repository context
        tool_name: Name of the tool
        version: Version string (needed for some path templates)
        platform: Platform string
        tool_info: Tool info dict from registry
        output_name: Optional custom output name
        output_dir: Directory where files were extracted

    Returns:
        Path to the binary (symlinked if needed)
    """
    target_name = output_name or tool_name
    is_windows = platform.startswith("windows")
    exe_suffix = ".exe" if is_windows else ""
    prefix = (output_dir + "/") if output_dir else ""

    # Tools with custom binary_path in registry (like Node.js)
    if tool_info.get("binary_path"):
        binary_path = prefix + tool_info["binary_path"].format(version)
        if repository_ctx.path(binary_path).exists:
            return binary_path
        # Fallback - try without version formatting
        return prefix + tool_info["binary_path"]

    # Tool-specific binary locations
    if tool_name == "go":
        possible_paths = [prefix + "bin/go" + exe_suffix]
    elif tool_name == "binaryen":
        # Binaryen's main binary is wasm-opt
        possible_paths = [prefix + "bin/wasm-opt" + exe_suffix]
    elif tool_name == "tinygo":
        possible_paths = [prefix + "bin/tinygo" + exe_suffix]
    else:
        # Common binary locations to check
        possible_paths = [
            prefix + tool_name + exe_suffix,
            prefix + "bin/" + tool_name + exe_suffix,
            prefix + tool_name + "/" + tool_name + exe_suffix,
        ]

    for path in possible_paths:
        if repository_ctx.path(path).exists:
            return path

    # Binary should exist at root after strip_prefix
    return prefix + tool_name + exe_suffix

# =============================================================================
# Public API (struct for namespacing)
# =============================================================================

tool_registry = struct(
    # Core functions
    detect_platform = _detect_platform,
    download = _download_tool,
    build_url = _build_download_url,

    # Enterprise/Air-Gap support
    # Use these for custom download logic that needs enterprise support
    resolve_source = _resolve_download_source,
    get_filename = _get_download_filename,
)
