#!/bin/bash
# Validation script for wit-bindgen-rt fix (no build required)
# This validates the code structure is correct

set -e

echo "=================================================================="
echo "Validating wit-bindgen-rt Fix"
echo "=================================================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

check() {
    local description=$1
    shift
    local command="$@"

    echo -n "Checking: $description... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌${NC}"
        FAILED=$((FAILED + 1))
        echo "  Command: $command"
    fi
}

check_contains() {
    local file=$1
    local pattern=$2
    local description=$3

    echo -n "Checking $description in $file... "
    if grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✅${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌${NC}"
        echo "  Expected to find: $pattern"
        FAILED=$((FAILED + 1))
    fi
}

check_not_contains() {
    local file=$1
    local pattern=$2
    local description=$3

    echo -n "Checking $description NOT in $file... "
    if ! grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✅${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌${NC}"
        echo "  Should not contain: $pattern"
        FAILED=$((FAILED + 1))
    fi
}

echo "1. Checking Cargo.toml dependencies"
echo "----------------------------------------------------------------"

check_contains "tools/checksum_updater/Cargo.toml" \
    'wit-bindgen-rt = "0.39.0"' \
    "wit-bindgen-rt dependency added"

check_contains "tools/checksum_updater/Cargo.toml" \
    'wit-bindgen = "0.47.0"' \
    "wit-bindgen macro crate present"

echo ""
echo "2. Checking wrapper code in rust_wasm_component_bindgen.bzl"
echo "----------------------------------------------------------------"

check_contains "rust/rust_wasm_component_bindgen.bzl" \
    'pub use wit_bindgen_rt as wit_bindgen;' \
    "Runtime re-export present"

check_not_contains "rust/rust_wasm_component_bindgen.bzl" \
    'pub use wit_bindgen_rt::export;' \
    "Incorrect export re-export removed"

check_not_contains "rust/rust_wasm_component_bindgen.bzl" \
    'let ptr = 1 as \*mut u8' \
    "Dummy pointer hack removed"

check_contains "rust/rust_wasm_component_bindgen.bzl" \
    '@crates//:wit-bindgen-rt' \
    "Dependencies use wit-bindgen-rt"

echo ""
echo "3. Checking MODULE.bazel comments"
echo "----------------------------------------------------------------"

check_contains "MODULE.bazel" \
    'wit-bindgen-rt' \
    "Documentation mentions wit-bindgen-rt"

echo ""
echo "4. Checking test files"
echo "----------------------------------------------------------------"

check "Alignment test WIT file exists" \
    "test -f test/alignment/alignment.wit"

check "Alignment test source exists" \
    "test -f test/alignment/src/lib.rs"

check "Alignment test BUILD.bazel exists" \
    "test -f test/alignment/BUILD.bazel"

echo ""
echo "5. Checking example usage patterns"
echo "----------------------------------------------------------------"

check_contains "examples/basic/src/lib.rs" \
    'hello_component_bindings::export!' \
    "Basic example uses export! macro correctly"

check_contains "test/integration/src/service_a.rs" \
    'service_a_component_bindings::export!' \
    "Integration test uses export! macro correctly"

echo ""
echo "6. Checking alignment test implementation"
echo "----------------------------------------------------------------"

check_contains "test/alignment/src/lib.rs" \
    'ComplexNested' \
    "Complex nested structure defined"

check_contains "test/alignment/src/lib.rs" \
    'alignment_component_bindings::export!' \
    "Alignment test uses export! macro"

check_contains "test/alignment/alignment.wit" \
    'record complex-nested' \
    "Complex nested record in WIT"

echo ""
echo "7. Checking for removed embedded runtime"
echo "----------------------------------------------------------------"

# Check for embedded runtime (should not exist)
check_not_contains "rust/rust_wasm_component_bindgen.bzl" \
    'pub mod wit_bindgen' \
    "Embedded runtime removed"

echo ""
echo "8. Checking dependency versions"
echo "----------------------------------------------------------------"

check_contains "tools/wizer_initializer/Cargo.toml" \
    'clap = { version = "4.5.51"' \
    "clap upgraded to 4.5.51"

check_contains "tools/wizer_initializer/Cargo.toml" \
    'octocrab = { version = "0.47.1"' \
    "octocrab upgraded to 0.47.1"

echo ""
echo "=================================================================="
echo "VALIDATION SUMMARY"
echo "=================================================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL VALIDATIONS PASSED!${NC}"
    echo ""
    echo "Code structure is correct. The fix should work when built."
    echo ""
    echo "Next steps:"
    echo "  1. Run: bazel build //test/alignment:alignment_component"
    echo "  2. Run: bazel build //test/integration:service_a_component"
    echo "  3. Run: ./test_components_with_wasmtime.sh"
    echo ""
    exit 0
else
    echo -e "${RED}❌ VALIDATION FAILED${NC}"
    echo "Fix the issues above before building."
    exit 1
fi
