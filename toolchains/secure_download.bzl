"""Secure tool download infrastructure with mandatory verification"""

load("//checksums:registry.bzl", "get_github_repo", "get_tool_checksum", "get_tool_info")

def secure_download_tool(ctx, tool_name, version, platform):
    """Download tool with mandatory checksum verification using central registry"""

    # Get verified checksum from central registry
    expected_checksum = get_tool_checksum(tool_name, version, platform)
    if not expected_checksum:
        fail("SECURITY: Tool '{}' version '{}' platform '{}' not in verified checksum registry. Check //checksums/tools/{}.json".format(
            tool_name,
            version,
            platform,
            tool_name,
        ))

    # Get additional tool info for URL construction
    tool_info = get_tool_info(tool_name, version, platform)
    if not tool_info:
        fail("SECURITY: Tool info not found for '{}' version '{}' platform '{}'".format(tool_name, version, platform))

    # Download with verification
    url = _build_download_url(tool_name, version, platform, tool_info)

    # Determine archive type from URL suffix
    archive_type = "zip" if tool_info.get("url_suffix", "").endswith(".zip") else "tar.gz"

    return ctx.download_and_extract(
        url = url,
        sha256 = expected_checksum,
        type = archive_type,
    )

def _build_download_url(tool_name, version, platform, tool_info):
    """Build download URL using tool info from central registry"""

    # Get GitHub repository from registry
    github_repo = get_github_repo(tool_name)
    if not github_repo:
        fail("GitHub repository not found for tool '{}'".format(tool_name))

    url_suffix = tool_info.get("url_suffix")
    if not url_suffix:
        fail("URL suffix not found for tool '{}' version '{}' platform '{}'".format(tool_name, version, platform))

    # Build the URL using GitHub releases pattern
    return "https://github.com/{github_repo}/releases/download/v{version}/{tool_name}-{version}-{suffix}".format(
        github_repo = github_repo,
        tool_name = tool_name,
        version = version,
        suffix = url_suffix,
    )
