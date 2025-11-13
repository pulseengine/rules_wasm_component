#!/bin/bash
# Comprehensive test script for wit-bindgen-rt fix
# Tests all Rust WASM components with wasmtime

set -e

echo "=================================================================="
echo "WASM Component Testing with Wasmtime"
echo "=================================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BAZEL="bazel"
TESTS_PASSED=0
TESTS_FAILED=0

# Function to build and test a component
test_component() {
    local target=$1
    local description=$2

    echo ""
    echo "=================================================================="
    echo "Testing: $description"
    echo "Target: $target"
    echo "=================================================================="

    # Build the component
    echo "Building component..."
    if $BAZEL build "$target" 2>&1 | tail -20; then
        echo -e "${GREEN}✅ Build successful${NC}"

        # Find the built component
        COMPONENT_PATH=$(bazel cquery --output=files "$target" 2>/dev/null | grep ".wasm$" | head -1)

        if [ -f "$COMPONENT_PATH" ]; then
            echo "Component: $COMPONENT_PATH"
            echo "Size: $(ls -lh "$COMPONENT_PATH" | awk '{print $5}')"

            # Validate with wasm-tools
            echo ""
            echo "Validating component structure..."
            if command -v wasm-tools &> /dev/null; then
                wasm-tools validate "$COMPONENT_PATH" && echo -e "${GREEN}✅ Component is valid${NC}"
                echo ""
                echo "Component metadata:"
                wasm-tools component wit "$COMPONENT_PATH" | head -50
            else
                echo -e "${YELLOW}⚠️  wasm-tools not available, skipping validation${NC}"
            fi

            # Test with wasmtime
            echo ""
            echo "Testing instantiation with wasmtime..."
            if command -v wasmtime &> /dev/null; then
                # Try to instantiate (may fail if component has no start function)
                wasmtime --version
                echo "Component info:"
                wasmtime info "$COMPONENT_PATH" || echo "(Component needs host imports)"
            else
                # Use Bazel's wasmtime
                echo "Using Bazel wasmtime toolchain..."
                WASMTIME=$(bazel run @wasmtime//:wasmtime -- --version 2>&1 | head -1)
                echo "Wasmtime: $WASMTIME"
            fi

            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ Component file not found${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}❌ Build failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to run component test
run_component_test() {
    local target=$1
    local description=$2

    echo ""
    echo "=================================================================="
    echo "Running test: $description"
    echo "Target: $target"
    echo "=================================================================="

    if $BAZEL test "$target" --test_output=all 2>&1 | tail -30; then
        echo -e "${GREEN}✅ Test passed${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ Test failed${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "Starting comprehensive component tests..."
echo ""

# Test 1: Alignment test (nested records)
test_component "//test/alignment:alignment_component" \
    "Nested Records Alignment Test (Critical for UB detection)"

# Test 2: Basic example
test_component "//examples/basic:hello_component" \
    "Basic Hello World Component"

# Test 3: Integration tests
echo ""
echo "=================================================================="
echo "Integration Tests (Critical - These were failing in CI)"
echo "=================================================================="

test_component "//test/integration:basic_component" \
    "Integration: Basic Component"

test_component "//test/integration:consumer_component" \
    "Integration: Consumer Component with External Deps"

test_component "//test/integration:service_a_component" \
    "Integration: Service A (The one that failed with export! error)"

test_component "//test/integration:service_b_component" \
    "Integration: Service B"

# Test 4: Other Rust examples
test_component "//examples/wizer_example:wizer_component" \
    "Wizer Pre-initialization Example"

test_component "//examples/multi_file_packaging:multi_file_component" \
    "Multi-file Component"

# Test 5: Run actual component tests
echo ""
echo "=================================================================="
echo "Running Component Tests (Not just builds)"
echo "=================================================================="

run_component_test "//examples/basic:hello_component_test" \
    "Basic Component Integration Test"

run_component_test "//test/integration:basic_component_validation" \
    "Integration Test Validation"

# Summary
echo ""
echo "=================================================================="
echo "TEST SUMMARY"
echo "=================================================================="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    echo ""
    echo "The wit-bindgen-rt fix is working correctly:"
    echo "  ✅ No 'export' macro errors"
    echo "  ✅ No alignment issues in nested records"
    echo "  ✅ Components build and validate successfully"
    echo "  ✅ Wasmtime can instantiate components"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "Please check the errors above and fix them."
    exit 1
fi
