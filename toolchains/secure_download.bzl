"""Secure tool download infrastructure with mandatory verification"""

load("//checksums:registry.bzl", "get_github_repo", "get_tool_checksum", "get_tool_info")

def secure_download_tool(ctx, tool_name, version, platform):
    """Download tool with mandatory checksum verification using central registry

    Supports configurable mirrors via environment variables for enterprise/air-gap deployments:
    - BAZEL_WASM_GITHUB_MIRROR: Override default GitHub URL
    - BAZEL_WASM_OFFLINE: Use vendored files from third_party/ instead of downloading

    Offline mode workflow:
    1. Vendor toolchains: bazel run @vendored_toolchains//:export_to_third_party
    2. Set environment: export BAZEL_WASM_OFFLINE=1
    3. Build uses vendored files instead of downloading
    """

    # Get verified checksum from central registry
    expected_checksum = get_tool_checksum(ctx, tool_name, version, platform)
    if not expected_checksum:
        fail("SECURITY: Tool '{}' version '{}' platform '{}' not in verified checksum registry. Check //checksums/tools/{}.json".format(
            tool_name,
            version,
            platform,
            tool_name,
        ))

    # Get additional tool info for URL construction
    tool_info = get_tool_info(ctx, tool_name, version, platform)
    if not tool_info:
        fail("SECURITY: Tool info not found for '{}' version '{}' platform '{}'".format(tool_name, version, platform))

    # Check for offline mode (use vendored files)
    offline_mode = ctx.os.environ.get("BAZEL_WASM_OFFLINE", "0") == "1"

    if offline_mode:
        # Use vendored files from third_party/
        vendored_path = "third_party/toolchains/{}/{}/{}".format(tool_name, version, platform)

        # Check if vendored file exists
        if ctx.path(vendored_path).exists:
            print("Using vendored toolchain: {}/{}/{} from {}".format(tool_name, version, platform, vendored_path))

            # Symlink vendored directory into repository
            ctx.symlink(vendored_path, tool_name)
            return None  # No download needed
        else:
            fail("OFFLINE MODE: Vendored toolchain not found at {}\nRun 'bazel run @vendored_toolchains//:export_to_third_party' to vendor toolchains first.".format(vendored_path))

    # Online mode: download from mirror
    # Get mirror configuration from environment (enterprise support)
    github_mirror = ctx.os.environ.get("BAZEL_WASM_GITHUB_MIRROR", "https://github.com")

    # Download with verification
    url = _build_download_url(ctx, tool_name, version, platform, tool_info, github_mirror)

    # Determine archive type from URL suffix
    archive_type = "zip" if tool_info.get("url_suffix", "").endswith(".zip") else "tar.gz"

    return ctx.download_and_extract(
        url = url,
        sha256 = expected_checksum,
        type = archive_type,
    )

def _build_download_url(ctx, tool_name, version, platform, tool_info, github_mirror):
    """Build download URL using tool info from central registry

    Args:
        ctx: Repository context
        tool_name: Name of the tool
        version: Version to download
        platform: Target platform
        tool_info: Tool metadata from registry
        github_mirror: Mirror URL for GitHub releases (enterprise support)

    Returns:
        Download URL (either public GitHub or corporate mirror)
    """

    # Get GitHub repository from registry
    github_repo = get_github_repo(ctx, tool_name)
    if not github_repo:
        fail("GitHub repository not found for tool '{}'".format(tool_name))

    url_suffix = tool_info.get("url_suffix")
    if not url_suffix:
        fail("URL suffix not found for tool '{}' version '{}' platform '{}'".format(tool_name, version, platform))

    # Build the URL using GitHub releases pattern with configurable mirror
    return "{mirror}/{github_repo}/releases/download/v{version}/{tool_name}-{version}-{suffix}".format(
        mirror = github_mirror,
        github_repo = github_repo,
        tool_name = tool_name,
        version = version,
        suffix = url_suffix,
    )
