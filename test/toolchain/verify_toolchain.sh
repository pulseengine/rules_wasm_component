#!/bin/bash
# Verify toolchain download URL and prefix generation

set -euo pipefail

# Get the test results file
TEST_RESULTS="$1"

echo "=== Toolchain Download Test ==="
echo "Reading test results from: $TEST_RESULTS"
echo

# Display the test results
cat "$TEST_RESULTS"
echo

# Parse the results
PLATFORM=$(grep "Platform:" "$TEST_RESULTS" | cut -d' ' -f2)
PLATFORM_SUFFIX=$(grep "Platform Suffix:" "$TEST_RESULTS" | cut -d' ' -f3)
URL=$(grep "URL:" "$TEST_RESULTS" | cut -d' ' -f2)
PREFIX=$(grep "Expected Prefix:" "$TEST_RESULTS" | cut -d' ' -f3)

echo "=== Verification ==="

# Test 1: Platform suffix should contain the platform in a specific format
echo "✓ Platform detected: $PLATFORM"
echo "✓ Platform suffix: $PLATFORM_SUFFIX"

# Test 2: URL should follow the expected pattern
if [[ "$URL" =~ ^https://github\.com/bytecodealliance/wasm-tools/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/wasm-tools-[0-9]+\.[0-9]+\.[0-9]+-.*\.tar\.gz$ ]]; then
    echo "✓ URL format is correct: $URL"
else
    echo "✗ URL format is incorrect: $URL"
    exit 1
fi

# Test 3: Prefix should match the archive structure (version-platform)
if [[ "$PREFIX" =~ ^wasm-tools-[0-9]+\.[0-9]+\.[0-9]+-.*$ ]]; then
    echo "✓ Prefix format is correct: $PREFIX"
else
    echo "✗ Prefix format is incorrect: $PREFIX"
    exit 1
fi

# Test 4: Verify the prefix matches the URL filename
URL_FILENAME=$(basename "$URL" .tar.gz)
if [[ "$PREFIX" == "$URL_FILENAME" ]]; then
    echo "✓ Prefix matches URL filename"
else
    echo "✗ Prefix ($PREFIX) does not match URL filename ($URL_FILENAME)"
    exit 1
fi

# Test 5: Platform-specific validation
case "$PLATFORM" in
    "darwin_arm64")
        if [[ "$PLATFORM_SUFFIX" == "aarch64-macos" ]]; then
            echo "✓ macOS ARM64 platform suffix is correct"
        else
            echo "✗ macOS ARM64 platform suffix should be 'aarch64-macos', got '$PLATFORM_SUFFIX'"
            exit 1
        fi
        ;;
    "darwin_amd64")
        if [[ "$PLATFORM_SUFFIX" == "x86_64-macos" ]]; then
            echo "✓ macOS Intel platform suffix is correct"
        else
            echo "✗ macOS Intel platform suffix should be 'x86_64-macos', got '$PLATFORM_SUFFIX'"
            exit 1
        fi
        ;;
    "linux_arm64")
        if [[ "$PLATFORM_SUFFIX" == "aarch64-linux" ]]; then
            echo "✓ Linux ARM64 platform suffix is correct"
        else
            echo "✗ Linux ARM64 platform suffix should be 'aarch64-linux', got '$PLATFORM_SUFFIX'"
            exit 1
        fi
        ;;
    "linux_amd64")
        if [[ "$PLATFORM_SUFFIX" == "x86_64-linux" ]]; then
            echo "✓ Linux Intel platform suffix is correct"
        else
            echo "✗ Linux Intel platform suffix should be 'x86_64-linux', got '$PLATFORM_SUFFIX'"
            exit 1
        fi
        ;;
    *)
        echo "✓ Platform '$PLATFORM' detected (using default suffix '$PLATFORM_SUFFIX')"
        ;;
esac

echo
echo "=== All Tests Passed! ==="
echo "The toolchain download configuration should work correctly for platform: $PLATFORM"