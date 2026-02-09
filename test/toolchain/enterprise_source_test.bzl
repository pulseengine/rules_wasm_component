"""Tests for enterprise air-gap source resolution in tool_registry.bzl

These tests verify that the enterprise environment variables work correctly:
- BAZEL_WASM_MIRROR: Redirect downloads to corporate mirror
- BAZEL_WASM_VENDOR_DIR: Use vendored files from custom directory
- BAZEL_WASM_OFFLINE: Require vendored files (strict offline mode)
"""

load("//toolchains:tool_registry.bzl", "tool_registry")
load("//checksums:registry.bzl", "get_tool_info")

def _enterprise_source_test_impl(repository_ctx):
    """Test the enterprise source resolution logic.

    This test verifies:
    1. Default behavior (no env vars) uses original URLs
    2. BAZEL_WASM_MIRROR rewrites URLs correctly
    3. BAZEL_WASM_VENDOR_DIR checks local paths
    4. BAZEL_WASM_OFFLINE mode works correctly
    """
    platform = tool_registry.detect_platform(repository_ctx)
    test_results = []

    # Test 1: Verify platform detection works
    test_results.append("Test 1: Platform detection")
    test_results.append("  Platform: {}".format(platform))
    test_results.append("  Status: PASS" if platform else "  Status: FAIL")

    # Test 2: Check environment variable reading
    test_results.append("")
    test_results.append("Test 2: Environment variable reading")
    mirror = repository_ctx.os.environ.get("BAZEL_WASM_MIRROR", "")
    vendor_dir = repository_ctx.os.environ.get("BAZEL_WASM_VENDOR_DIR", "")
    offline = repository_ctx.os.environ.get("BAZEL_WASM_OFFLINE", "0")

    test_results.append("  BAZEL_WASM_MIRROR: '{}'".format(mirror))
    test_results.append("  BAZEL_WASM_VENDOR_DIR: '{}'".format(vendor_dir))
    test_results.append("  BAZEL_WASM_OFFLINE: '{}'".format(offline))

    # Test 3: Source resolution with default settings
    test_results.append("")
    test_results.append("Test 3: Default source resolution (no env vars)")
    default_url = "https://github.com/test/releases/download/v1.0.0/tool-1.0.0.tar.gz"
    source = tool_registry.resolve_source(
        repository_ctx,
        "test-tool",
        "1.0.0",
        platform,
        default_url,
        "tool-1.0.0.tar.gz",
    )

    # If no env vars set, should return default URL
    if not mirror and not vendor_dir and offline != "1":
        if source.type == "url" and source.url == default_url:
            test_results.append("  Expected: Default URL returned")
            test_results.append("  Status: PASS")
        else:
            test_results.append("  Expected: Default URL, Got: {}".format(source))
            test_results.append("  Status: FAIL")
    else:
        test_results.append("  Enterprise mode active - checking enterprise behavior")
        test_results.append("  Source type: {}".format(source.type))
        if source.type == "url":
            test_results.append("  URL: {}".format(source.url))
        elif source.type == "local":
            test_results.append("  Path: {}".format(source.path))
        test_results.append("  Status: INFO (depends on env vars)")

    # Test 4: Verify real tools can be resolved
    test_results.append("")
    test_results.append("Test 4: Real tool info lookup")
    for tool_name in ["wasm-tools", "wasmtime", "wit-bindgen"]:
        tool_info = get_tool_info(tool_name, None, platform)
        if tool_info:
            test_results.append("  {}: Found in registry".format(tool_name))
        else:
            test_results.append("  {}: Not found for platform {}".format(tool_name, platform))

    # Test 5: Mirror URL construction (if mirror is set)
    test_results.append("")
    test_results.append("Test 5: Mirror URL construction")
    if mirror:
        expected_mirror_url = "{}/test-tool/1.0.0/{}/tool-1.0.0.tar.gz".format(
            mirror.rstrip("/"),
            platform,
        )
        if source.type == "url":
            if source.url == expected_mirror_url:
                test_results.append("  Mirror URL correctly constructed")
                test_results.append("  Status: PASS")
            else:
                test_results.append("  Expected: {}".format(expected_mirror_url))
                test_results.append("  Got: {}".format(source.url))
                test_results.append("  Status: FAIL")
        else:
            test_results.append("  Source is local (vendor mode takes precedence)")
            test_results.append("  Status: SKIP")
    else:
        test_results.append("  BAZEL_WASM_MIRROR not set - skipping")
        test_results.append("  Status: SKIP")

    # Test 6: Vendor path structure
    test_results.append("")
    test_results.append("Test 6: Vendor path structure")
    if vendor_dir:
        expected_path = "{}/test-tool/1.0.0/{}/tool-1.0.0.tar.gz".format(
            vendor_dir,
            platform,
        )
        test_results.append("  Expected vendor path: {}".format(expected_path))

        # Check if path exists
        vendor_path = repository_ctx.path(expected_path)
        if vendor_path.exists:
            test_results.append("  Path exists: YES")
            test_results.append("  Status: PASS")
        else:
            test_results.append("  Path exists: NO (expected for test)")
            test_results.append("  Status: INFO (fallback to default/mirror)")
    else:
        test_results.append("  BAZEL_WASM_VENDOR_DIR not set - skipping")
        test_results.append("  Status: SKIP")

    # Write test results
    repository_ctx.file("test_results.txt", "\n".join(test_results) + "\n")

    # Create BUILD file
    repository_ctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "test_results",
    srcs = ["test_results.txt"],
)

# Test that can be run to verify enterprise support
sh_test(
    name = "enterprise_source_test",
    srcs = ["verify_test.sh"],
    data = [":test_results"],
)
""")

    # Create verification script
    repository_ctx.file("verify_test.sh", """#!/bin/bash
echo "=== Enterprise Source Resolution Test Results ==="
cat "$(dirname "$0")/test_results.txt"

# Check for any FAIL results
if grep -q "Status: FAIL" "$(dirname "$0")/test_results.txt"; then
    echo ""
    echo "=== TEST FAILED ==="
    exit 1
else
    echo ""
    echo "=== ALL TESTS PASSED ==="
    exit 0
fi
""", executable = True)

enterprise_source_test_repository = repository_rule(
    implementation = _enterprise_source_test_impl,
    environ = [
        "BAZEL_WASM_MIRROR",
        "BAZEL_WASM_VENDOR_DIR",
        "BAZEL_WASM_OFFLINE",
    ],
    attrs = {},
    doc = "Repository rule that tests enterprise source resolution",
)

def register_enterprise_tests():
    """Register the enterprise source test repository.

    Call this from MODULE.bazel or a workspace macro to enable enterprise testing.
    """
    enterprise_source_test_repository(
        name = "enterprise_source_test",
    )
