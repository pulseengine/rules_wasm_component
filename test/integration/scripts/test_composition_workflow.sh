#!/bin/bash
set -euo pipefail

# Component composition integration test
# Tests that multi-component compositions work correctly

echo "Testing component composition workflow..."

# Source runfiles library for Bazel
source "${BASH_RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" || \
  (echo >&2 "ERROR: cannot find @bazel_tools runfiles library" && exit 1)

# Get composed system paths
MULTI_SERVICE=$(rlocation "rules_wasm_component/test/integration/multi_service_system.wasm")
WASI_SYSTEM=$(rlocation "rules_wasm_component/test/integration/wasi_system.wasm")

echo "Checking multi-service composition exists..."
if [[ ! -f "$MULTI_SERVICE" ]]; then
    echo "ERROR: Multi-service system not found at $MULTI_SERVICE"
    exit 1
fi

echo "Checking WASI system composition exists..."
if [[ ! -f "$WASI_SYSTEM" ]]; then
    echo "ERROR: WASI system not found at $WASI_SYSTEM"
    exit 1
fi

# Validate compositions with wasm-tools if available
if command -v wasm-tools >/dev/null 2>&1; then
    echo "Validating multi-service composition..."
    wasm-tools validate "$MULTI_SERVICE"
    
    echo "Validating WASI system composition..."
    wasm-tools validate "$WASI_SYSTEM"
    
    echo "Checking multi-service composition structure..."
    wasm-tools component wit "$MULTI_SERVICE" > /tmp/multi_wit.txt
    if grep -q "service-b" /tmp/multi_wit.txt; then
        echo "✓ Multi-service composition exports service-b interface"
    else
        echo "✗ Multi-service composition missing service-b export"
        cat /tmp/multi_wit.txt
        exit 1
    fi
    
    echo "Checking WASI system composition structure..."
    wasm-tools component wit "$WASI_SYSTEM" > /tmp/wasi_wit.txt
    if grep -q "wasi-app" /tmp/wasi_wit.txt; then
        echo "✓ WASI system composition exports wasi-app interface"
    else
        echo "✗ WASI system composition missing wasi-app export"
        cat /tmp/wasi_wit.txt
        exit 1
    fi
    
    # Check that WASI imports are preserved
    if grep -q "wasi:" /tmp/wasi_wit.txt; then
        echo "✓ WASI system preserves WASI imports for host runtime"
    else
        echo "✗ WASI system missing WASI imports - they should pass through"
        cat /tmp/wasi_wit.txt
        exit 1
    fi
else
    echo "wasm-tools not available, skipping detailed validation"
fi

echo "Checking composition file sizes..."
MULTI_SIZE=$(stat -c%s "$MULTI_SERVICE" 2>/dev/null || stat -f%z "$MULTI_SERVICE" 2>/dev/null)
WASI_SIZE=$(stat -c%s "$WASI_SYSTEM" 2>/dev/null || stat -f%z "$WASI_SYSTEM" 2>/dev/null)

echo "Multi-service composition size: $MULTI_SIZE bytes"
echo "WASI system composition size: $WASI_SIZE bytes"

# Compositions should be larger than individual components
if [[ $MULTI_SIZE -gt 1000 ]]; then
    echo "✓ Multi-service composition has reasonable size"
else
    echo "✗ Multi-service composition seems too small"
    exit 1
fi

if [[ $WASI_SIZE -gt 1000 ]]; then
    echo "✓ WASI system composition has reasonable size"
else
    echo "✗ WASI system composition seems too small"
    exit 1
fi

echo "✓ Composition workflow test passed!"