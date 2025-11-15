"""Bazel-native toolchain vendoring using file-ops WASM component

This module provides pure Bazel toolchain vendoring without any shell scripts.
All file operations are performed using the file-ops WASM component.

Usage:
    # In MODULE.bazel or workspace_deps.bzl
    load("//tools/vendor:vendor_toolchains.bzl", "vendor_all_toolchains")

    vendor_all_toolchains(
        name = "vendored_toolchains",
        platforms = ["linux_amd64", "darwin_arm64"],
    )

    # Download all toolchains to Bazel cache
    $ bazel fetch @vendored_toolchains//...

    # Export to third_party/ using file-ops component
    $ bazel run @vendored_toolchains//:export_to_third_party
"""

load("//checksums:registry.bzl", "get_github_repo", "get_tool_checksum", "get_tool_info")

def _construct_download_url(tool_name, version, platform, tool_info, github_mirror = "https://github.com"):
    """Build download URL for a tool"""

    github_repo = get_github_repo(tool_name)
    if not github_repo:
        fail("GitHub repository not found for tool '{}'".format(tool_name))

    url_suffix = tool_info.get("url_suffix")
    if not url_suffix:
        fail("URL suffix not found for tool '{}' version '{}' platform '{}'".format(tool_name, version, platform))

    # Build the URL using GitHub releases pattern
    return "{mirror}/{github_repo}/releases/download/v{version}/{tool_name}-{version}-{suffix}".format(
        mirror = github_mirror,
        github_repo = github_repo,
        tool_name = tool_name,
        version = version,
        suffix = url_suffix,
    )

def _vendor_all_toolchains_impl(repository_ctx):
    """Download all toolchains for specified platforms using Bazel repository rules

    This reuses our existing secure download infrastructure to download all
    toolchains into Bazel's repository cache. The files can then be exported
    to third_party/ using the export action.
    """

    platforms = repository_ctx.attr.platforms

    # All tools from our registry
    all_tools = [
        ("wasm-tools", "1.240.0"),
        ("wit-bindgen", "0.39.0"),
        ("wac", "0.7.0"),
        ("wkg", "0.11.1"),
        ("wasmtime", "29.0.1"),
        ("wizer", "9.0.1"),
        ("wasi-sdk", "25.0.0"),
        ("nodejs", "20.18.0"),
        ("tinygo", "0.39.0"),
    ]

    print("Vendoring toolchains for platforms: {}".format(", ".join(platforms)))

    # Track what we've downloaded
    vendored_items = []
    download_count = 0
    skip_count = 0

    for tool_name, version in all_tools:
        for platform in platforms:
            # Get tool info from registry
            tool_info = get_tool_info(tool_name, version, platform)

            if not tool_info:
                print("Skipping {}/{}/{} (not in registry)".format(tool_name, version, platform))
                skip_count += 1
                continue

            # Get checksum
            checksum = get_tool_checksum(tool_name, version, platform)
            if not checksum:
                print("Skipping {}/{}/{} (no checksum)".format(tool_name, version, platform))
                skip_count += 1
                continue

            # Build download URL
            url = _construct_download_url(tool_name, version, platform, tool_info)

            # Determine archive type
            url_suffix = tool_info.get("url_suffix", "")
            archive_type = "zip" if url_suffix.endswith(".zip") else "tar.gz"

            # Download to organized directory structure
            output_dir = "vendored/{}/{}/{}".format(tool_name, version, platform)

            print("Downloading {}/{}/{} from {}".format(tool_name, version, platform, url))

            # Download with verification (goes to Bazel cache)
            result = repository_ctx.download_and_extract(
                url = url,
                sha256 = checksum,
                type = archive_type,
                output = output_dir,
            )

            if result:
                vendored_items.append({
                    "tool": tool_name,
                    "version": version,
                    "platform": platform,
                    "path": output_dir,
                    "checksum": checksum,
                    "url": url,
                })
                download_count += 1

    print("Vendored {} toolchains ({} skipped)".format(download_count, skip_count))

    # Create manifest of vendored toolchains
    manifest = {
        "vendored_toolchains": vendored_items,
        "platforms": platforms,
        "download_count": download_count,
        "skip_count": skip_count,
    }

    repository_ctx.file(
        "vendored_manifest.json",
        content = json.encode_indent(manifest, indent = "  "),
    )

    # Create BUILD file with targets
    repository_ctx.file("BUILD.bazel", """
load("//tools/vendor:defs.bzl", "vendor_export_action")

package(default_visibility = ["//visibility:public"])

# All vendored files
filegroup(
    name = "all_vendored",
    srcs = glob(["vendored/**/*"]),
)

# Manifest file
filegroup(
    name = "manifest",
    srcs = ["vendored_manifest.json"],
)

# Export action to copy vendored files to third_party/ using file-ops component
vendor_export_action(
    name = "export_to_third_party",
    manifest = ":manifest",
    vendored_files = ":all_vendored",
)
""")

    print("Vendoring complete! Run 'bazel run @vendored_toolchains//:export_to_third_party' to export.")

vendor_all_toolchains = repository_rule(
    implementation = _vendor_all_toolchains_impl,
    attrs = {
        "platforms": attr.string_list(
            default = ["linux_amd64", "darwin_arm64"],
            doc = "Platforms to vendor toolchains for",
        ),
    },
    doc = "Downloads all toolchains for specified platforms to Bazel repository cache",
)
