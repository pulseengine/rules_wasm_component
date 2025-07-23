#!/bin/bash
set -euo pipefail

# Basic workflow integration test
# Tests that basic components can be built in multiple profiles

echo "Testing basic component workflow..."

# Source runfiles library for Bazel
source "${BASH_RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" || \
  (echo >&2 "ERROR: cannot find @bazel_tools runfiles library" && exit 1)

# Get component paths
DEBUG_COMPONENT=$(rlocation "rules_wasm_component/test/integration/basic_component_debug.component.wasm")
RELEASE_COMPONENT=$(rlocation "rules_wasm_component/test/integration/basic_component_release.component.wasm")

echo "Checking debug component exists..."
if [[ ! -f "$DEBUG_COMPONENT" ]]; then
    echo "ERROR: Debug component not found at $DEBUG_COMPONENT"
    exit 1
fi

echo "Checking release component exists..."
if [[ ! -f "$RELEASE_COMPONENT" ]]; then
    echo "ERROR: Release component not found at $RELEASE_COMPONENT"
    exit 1
fi

echo "Checking debug component size..."
DEBUG_SIZE=$(stat -c%s "$DEBUG_COMPONENT" 2>/dev/null || stat -f%z "$DEBUG_COMPONENT" 2>/dev/null)
echo "Debug component size: $DEBUG_SIZE bytes"

echo "Checking release component size..."
RELEASE_SIZE=$(stat -c%s "$RELEASE_COMPONENT" 2>/dev/null || stat -f%z "$RELEASE_COMPONENT" 2>/dev/null)
echo "Release component size: $RELEASE_SIZE bytes"

# Validate components with wasm-tools if available
if command -v wasm-tools >/dev/null 2>&1; then
    echo "Validating debug component with wasm-tools..."
    wasm-tools validate "$DEBUG_COMPONENT"
    
    echo "Validating release component with wasm-tools..."
    wasm-tools validate "$RELEASE_COMPONENT"
    
    echo "Checking component metadata..."
    wasm-tools component wit "$DEBUG_COMPONENT" > /tmp/debug_wit.txt
    if grep -q "calculator" /tmp/debug_wit.txt; then
        echo "✓ Debug component exports calculator interface"
    else
        echo "✗ Debug component missing calculator interface"
        exit 1
    fi
else
    echo "wasm-tools not available, skipping validation"
fi

echo "✓ Basic workflow test passed!"