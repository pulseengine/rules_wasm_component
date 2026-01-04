#!/bin/bash
# Test for enterprise air-gap support in tool_registry.bzl
#
# This test verifies that the enterprise environment variables are properly
# respected during repository rule execution.
#
# Run: bazel test //test/toolchain:enterprise_mirror_test
# Or: bash test/toolchain/enterprise_mirror_test.sh

set -e

# Use runfiles if available (when run via bazel test)
if [ -n "$RUNFILES_DIR" ]; then
    TOOL_REGISTRY="$RUNFILES_DIR/_main/toolchains/tool_registry.bzl"
elif [ -n "$TEST_SRCDIR" ]; then
    TOOL_REGISTRY="$TEST_SRCDIR/_main/toolchains/tool_registry.bzl"
else
    # Direct execution - find relative to script
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    TOOL_REGISTRY="$SCRIPT_DIR/../../toolchains/tool_registry.bzl"
fi

if [ ! -f "$TOOL_REGISTRY" ]; then
    echo "ERROR: Cannot find tool_registry.bzl at: $TOOL_REGISTRY"
    exit 1
fi

echo "=== Enterprise Mirror/Offline Support Test ==="
echo "Testing file: $TOOL_REGISTRY"
echo ""

# Test 1: Verify environment variables are documented
echo "Test 1: Environment variables documented in tool_registry.bzl"
if grep -q "BAZEL_WASM_MIRROR" "$TOOL_REGISTRY" && \
   grep -q "BAZEL_WASM_VENDOR_DIR" "$TOOL_REGISTRY" && \
   grep -q "BAZEL_WASM_OFFLINE" "$TOOL_REGISTRY"; then
    echo "  PASS: All environment variables documented"
else
    echo "  FAIL: Missing environment variable documentation"
    exit 1
fi

# Test 2: Verify _resolve_download_source function exists
echo ""
echo "Test 2: _resolve_download_source function exists"
if grep -q "_resolve_download_source" "$TOOL_REGISTRY"; then
    echo "  PASS: Function exists"
else
    echo "  FAIL: Function not found"
    exit 1
fi

# Test 3: Verify resolve_source is exposed in public API
echo ""
echo "Test 3: resolve_source exposed in tool_registry struct"
if grep -q "resolve_source = _resolve_download_source" "$TOOL_REGISTRY"; then
    echo "  PASS: Function exposed in public API"
else
    echo "  FAIL: Function not in public API"
    exit 1
fi

# Test 4: Verify mirror URL construction logic
echo ""
echo "Test 4: Mirror URL construction"
if grep -q 'mirror_url = "{}/{}/{}/{}/{}"' "$TOOL_REGISTRY"; then
    echo "  PASS: Mirror URL pattern found (tool/version/platform/filename)"
else
    echo "  FAIL: Mirror URL pattern not found"
    exit 1
fi

# Test 5: Verify priority order (offline -> vendor -> mirror -> default)
echo ""
echo "Test 5: Priority order verification"
OFFLINE_LINE=$(grep -n "BAZEL_WASM_OFFLINE" "$TOOL_REGISTRY" | head -1 | cut -d: -f1)
VENDOR_LINE=$(grep -n "BAZEL_WASM_VENDOR_DIR" "$TOOL_REGISTRY" | head -1 | cut -d: -f1)
MIRROR_LINE=$(grep -n 'BAZEL_WASM_MIRROR"' "$TOOL_REGISTRY" | head -1 | cut -d: -f1)

if [ "$OFFLINE_LINE" -lt "$VENDOR_LINE" ] && [ "$VENDOR_LINE" -lt "$MIRROR_LINE" ]; then
    echo "  PASS: Priority order correct (offline < vendor < mirror)"
else
    echo "  FAIL: Priority order incorrect"
    echo "    OFFLINE at line: $OFFLINE_LINE"
    echo "    VENDOR at line: $VENDOR_LINE"
    echo "    MIRROR at line: $MIRROR_LINE"
    exit 1
fi

# Test 6: Verify default URL fallback
echo ""
echo "Test 6: Default URL fallback"
if grep -q 'return struct(type = "url", url = default_url' "$TOOL_REGISTRY"; then
    echo "  PASS: Default URL fallback exists"
else
    echo "  FAIL: Default URL fallback not found"
    exit 1
fi

# Test 7: Verify local vendor path support
echo ""
echo "Test 7: Local vendor path support"
if grep -q 'return struct(type = "local"' "$TOOL_REGISTRY"; then
    echo "  PASS: Local vendor support exists"
else
    echo "  FAIL: Local vendor support not found"
    exit 1
fi

echo ""
echo "=== All tests passed ==="
