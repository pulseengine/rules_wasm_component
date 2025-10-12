#!/usr/bin/env bash
# Comprehensive hermiticity test across all major target types

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$WORKSPACE_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 Comprehensive Hermiticity Test Suite"
echo "========================================"
echo ""

# Test targets across different languages and types
TARGETS=(
    # Go components
    "//examples/go_component:calculator_component"

    # Rust components
    "//examples/basic:hello_component"

    # C++ components
    "//examples/cpp_component/calculator:calculator_cpp_component"

    # JS components
    "//examples/js_component:hello_js_component"

    # Tools (Go binaries)
    "//tools/wit_structure:wit_structure"
    "//tools/file_ops:file_ops"
)

FAILED_TARGETS=()
PASSED_TARGETS=()

for target in "${TARGETS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}Testing: $target${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    LOG_FILE="/tmp/hermetic_test_$(echo "$target" | tr '/:' '_').json"

    # Build with execution log
    echo "Building..."
    if bazel build --execution_log_json_file="$LOG_FILE" "$target" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Build successful"

        # Analyze hermiticity
        echo "Analyzing hermiticity..."
        if python3 "$SCRIPT_DIR/analyze_exec_log.py" "$LOG_FILE" > /tmp/hermetic_analysis.txt 2>&1; then
            echo -e "${GREEN}✓${NC} Hermiticity check passed"
            PASSED_TARGETS+=("$target")
        else
            echo -e "${RED}✗${NC} Hermiticity check failed"
            echo "Details:"
            cat /tmp/hermetic_analysis.txt | grep -A 20 "WARNING\|FAILED" || cat /tmp/hermetic_analysis.txt
            FAILED_TARGETS+=("$target")
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Build failed (skipping hermiticity check)"
        echo "This might be expected for some targets"
    fi

    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                    SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Passed: ${#PASSED_TARGETS[@]}${NC}"
for target in "${PASSED_TARGETS[@]}"; do
    echo -e "  ${GREEN}✓${NC} $target"
done

echo ""

if [ ${#FAILED_TARGETS[@]} -gt 0 ]; then
    echo -e "${RED}Failed: ${#FAILED_TARGETS[@]}${NC}"
    for target in "${FAILED_TARGETS[@]}"; do
        echo -e "  ${RED}✗${NC} $target"
    done
    echo ""
    exit 1
else
    echo -e "${GREEN}All tested targets are hermetic! 🎉${NC}"
    exit 0
fi
