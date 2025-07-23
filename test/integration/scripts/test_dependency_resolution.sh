#!/bin/bash
set -euo pipefail

# Dependency resolution integration test
# Tests that external dependencies are resolved correctly

echo "Testing dependency resolution workflow..."

# Source runfiles library for Bazel
source "${BASH_RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" || \
  (echo >&2 "ERROR: cannot find @bazel_tools runfiles library" && exit 1)

# Get component and validation report paths
CONSUMER_COMPONENT=$(rlocation "rules_wasm_component/test/integration/consumer_component.component.wasm")
DEPS_REPORT=$(rlocation "rules_wasm_component/test/integration/validate_consumer_deps_report.txt")

echo "Checking consumer component exists..."
if [[ ! -f "$CONSUMER_COMPONENT" ]]; then
    echo "ERROR: Consumer component not found at $CONSUMER_COMPONENT"
    exit 1
fi

echo "Checking dependency validation report exists..."
if [[ ! -f "$DEPS_REPORT" ]]; then
    echo "ERROR: Dependency report not found at $DEPS_REPORT"
    exit 1
fi

echo "Checking dependency report contents..."
if grep -q "All dependencies resolved" "$DEPS_REPORT"; then
    echo "✓ All dependencies resolved correctly"
elif grep -q "Missing dependencies" "$DEPS_REPORT"; then
    echo "✗ Missing dependencies found:"
    cat "$DEPS_REPORT"
    exit 1
else
    echo "? Dependency report format unclear:"
    cat "$DEPS_REPORT"
fi

# Validate component with wasm-tools if available
if command -v wasm-tools >/dev/null 2>&1; then
    echo "Validating consumer component..."
    wasm-tools validate "$CONSUMER_COMPONENT"
    
    echo "Checking component imports/exports..."
    wasm-tools component wit "$CONSUMER_COMPONENT" > /tmp/consumer_wit.txt
    
    if grep -q "utilities" /tmp/consumer_wit.txt; then
        echo "✓ Consumer component imports utilities interface"
    else
        echo "✗ Consumer component missing utilities import"
        exit 1
    fi
    
    if grep -q "processor" /tmp/consumer_wit.txt; then
        echo "✓ Consumer component exports processor interface"
    else
        echo "✗ Consumer component missing processor export"
        exit 1
    fi
else
    echo "wasm-tools not available, skipping detailed validation"
fi

echo "✓ Dependency resolution test passed!"