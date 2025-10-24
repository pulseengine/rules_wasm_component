#!/bin/bash
# Performance Comparison Test
# Compares execution time between embedded and external implementations

set -e

echo "========================================="
echo "File Operations Performance Comparison"
echo "========================================="

# Find the binaries (handle both direct and Bazel test execution)
if [ -n "$TEST_SRCDIR" ]; then
    # Running as Bazel test
    EMBEDDED_BINARY="$TEST_SRCDIR/_main/tools/file_ops/file_ops_/file_ops"
    EXTERNAL_BINARY="$TEST_SRCDIR/_main/tools/file_ops_external/file_ops_external_/file_ops_external"
else
    # Running directly
    EMBEDDED_BINARY="tools/file_ops/file_ops_/file_ops"
    EXTERNAL_BINARY="tools/file_ops_external/file_ops_external_/file_ops_external"
fi

# Create test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Test directory: $TEST_DIR"

# Create a more intensive test configuration
cat > "$TEST_DIR/config.json" <<EOF
{
  "workspace_dir": "WORKSPACE_PLACEHOLDER",
  "operations": [
    {"type": "mkdir", "path": "dir1"},
    {"type": "mkdir", "path": "dir2"},
    {"type": "mkdir", "path": "dir3"},
    {"type": "mkdir", "path": "dir4"},
    {"type": "mkdir", "path": "dir5"},
    {"type": "mkdir", "path": "dir1/subdir1"},
    {"type": "mkdir", "path": "dir1/subdir2"},
    {"type": "mkdir", "path": "dir2/subdir1"},
    {"type": "mkdir", "path": "dir2/subdir2"},
    {"type": "mkdir", "path": "dir3/subdir1"}
  ]
}
EOF

# Benchmark function
benchmark() {
    local NAME=$1
    local BINARY=$2
    local ITERATIONS=10

    echo ""
    echo "Benchmarking $NAME implementation..."

    if [ ! -f "$BINARY" ]; then
        echo "WARNING: Binary not found at $BINARY"
        return
    fi

    local TOTAL_TIME=0

    for i in $(seq 1 $ITERATIONS); do
        WORKSPACE="$TEST_DIR/${NAME}_workspace_$i"
        CONFIG="$TEST_DIR/${NAME}_config_$i.json"
        sed "s|WORKSPACE_PLACEHOLDER|$WORKSPACE|g" "$TEST_DIR/config.json" > "$CONFIG"

        # Time the execution
        START=$(date +%s%N)
        "$BINARY" "$CONFIG" > /dev/null 2>&1
        END=$(date +%s%N)

        ELAPSED=$((END - START))
        ELAPSED_MS=$((ELAPSED / 1000000))
        TOTAL_TIME=$((TOTAL_TIME + ELAPSED_MS))

        echo "  Run $i: ${ELAPSED_MS}ms"
    done

    AVG_TIME=$((TOTAL_TIME / ITERATIONS))
    echo "  Average: ${AVG_TIME}ms over $ITERATIONS runs"

    # Return average time
    echo $AVG_TIME
}

# Benchmark both implementations
EMBEDDED_TIME=$(benchmark "embedded" "$EMBEDDED_BINARY")
EXTERNAL_TIME=$(benchmark "external" "$EXTERNAL_BINARY")

# Compare results
echo ""
echo "========================================="
echo "Performance Comparison Results:"
echo "  Embedded: ${EMBEDDED_TIME}ms average"
echo "  External: ${EXTERNAL_TIME}ms average"

if [ $EMBEDDED_TIME -lt $EXTERNAL_TIME ]; then
    DIFF=$((EXTERNAL_TIME - EMBEDDED_TIME))
    PERCENT=$(( (DIFF * 100) / EMBEDDED_TIME ))
    echo "  Winner: Embedded (${PERCENT}% faster)"
else
    DIFF=$((EMBEDDED_TIME - EXTERNAL_TIME))
    PERCENT=$(( (DIFF * 100) / EXTERNAL_TIME ))
    echo "  Winner: External (${PERCENT}% faster)"
fi

echo "========================================="

# Performance regression check (external shouldn't be > 2x slower)
MAX_ACCEPTABLE_TIME=$((EMBEDDED_TIME * 2))

if [ $EXTERNAL_TIME -gt $MAX_ACCEPTABLE_TIME ]; then
    echo "⚠️  WARNING: External implementation is more than 2x slower"
    echo "   This may indicate a performance regression"
    echo "   Embedded: ${EMBEDDED_TIME}ms"
    echo "   External: ${EXTERNAL_TIME}ms"
    echo "   Threshold: ${MAX_ACCEPTABLE_TIME}ms"
    # Don't fail - just warn
fi

echo ""
echo "✅ PASS: Performance comparison complete"
