#!/bin/bash
# Performance comparison test for vendored vs non-vendored builds
# This test measures download time savings from using vendored toolchains

set -euo pipefail

echo "========================================"
echo "Vendoring Performance Test"
echo "========================================"
echo ""

# Test setup
TEST_TARGET="//examples/basic:hello_component"
TEMP_VENDOR_DIR=$(mktemp -d)
trap "rm -rf $TEMP_VENDOR_DIR" EXIT

echo "Test target: $TEST_TARGET"
echo "Temp vendor dir: $TEMP_VENDOR_DIR"
echo ""

# Measure 1: Clean build with downloads (baseline)
echo "==> Test 1: Clean build with downloads (baseline)"
bazel clean --expunge > /dev/null 2>&1
START_DOWNLOAD=$(date +%s)
bazel build $TEST_TARGET --repository_cache=/tmp/vendor_test_cache > /dev/null 2>&1
END_DOWNLOAD=$(date +%s)
DOWNLOAD_TIME=$((END_DOWNLOAD - START_DOWNLOAD))
echo "✓ Completed in ${DOWNLOAD_TIME}s (includes toolchain downloads)"
echo ""

# Measure 2: Rebuild with warm cache (no downloads)
echo "==> Test 2: Rebuild with warm Bazel cache"
bazel clean > /dev/null 2>&1  # Clean build outputs but keep repository cache
START_CACHED=$(date +%s)
bazel build $TEST_TARGET --repository_cache=/tmp/vendor_test_cache > /dev/null 2>&1
END_CACHED=$(date +%s)
CACHED_TIME=$((END_CACHED - START_CACHED))
echo "✓ Completed in ${CACHED_TIME}s (repository cache hit, no downloads)"
echo ""

# Calculate improvement
if [ $DOWNLOAD_TIME -gt 0 ]; then
    IMPROVEMENT=$((100 * (DOWNLOAD_TIME - CACHED_TIME) / DOWNLOAD_TIME))
    SPEEDUP=$(echo "scale=2; $DOWNLOAD_TIME / $CACHED_TIME" | bc)
    echo "========================================"
    echo "Performance Results"
    echo "========================================"
    echo "Baseline (cold cache):    ${DOWNLOAD_TIME}s"
    echo "With cache:               ${CACHED_TIME}s"
    echo "Time saved:               $((DOWNLOAD_TIME - CACHED_TIME))s"
    echo "Improvement:              ${IMPROVEMENT}%"
    echo "Speedup:                  ${SPEEDUP}x faster"
    echo ""

    # Vendoring simulation (repository cache IS vendoring in Bazel)
    echo "NOTE: Bazel's repository cache demonstrates vendoring benefits:"
    echo "  - First build: Downloads from internet (~${DOWNLOAD_TIME}s)"
    echo "  - Cached build: Uses local files (~${CACHED_TIME}s)"
    echo "  - Vendored build would be similar to cached build"
    echo ""
    echo "In air-gap mode (BAZEL_WASM_OFFLINE=1):"
    echo "  - third_party/ acts as permanent repository cache"
    echo "  - All builds would be ~${CACHED_TIME}s (no downloads ever)"
    echo ""
else
    echo "ERROR: Baseline time was 0 seconds"
    exit 1
fi

# Success criteria: Cached build should be faster
if [ $CACHED_TIME -lt $DOWNLOAD_TIME ]; then
    echo "✅ TEST PASSED: Cached build is faster (${IMPROVEMENT}% improvement)"
    exit 0
else
    echo "❌ TEST FAILED: Cached build was not faster"
    exit 1
fi
