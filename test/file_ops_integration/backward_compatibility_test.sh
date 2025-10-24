#!/bin/bash
# Backward Compatibility Test
# Verifies that embedded and external implementations produce identical results

set -e

echo "========================================="
echo "File Operations Backward Compatibility Test"
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

# Create test directories
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

EMBEDDED_WORKSPACE="$TEST_DIR/embedded_workspace"
EXTERNAL_WORKSPACE="$TEST_DIR/external_workspace"

echo "Test directory: $TEST_DIR"

# Create test configuration
cat > "$TEST_DIR/config.json" <<EOF
{
  "workspace_dir": "WORKSPACE_PLACEHOLDER",
  "operations": [
    {
      "type": "mkdir",
      "path": "subdir1"
    },
    {
      "type": "mkdir",
      "path": "subdir2"
    }
  ]
}
EOF

# Test embedded implementation
echo ""
echo "Testing embedded implementation..."
EMBEDDED_CONFIG="$TEST_DIR/embedded_config.json"
sed "s|WORKSPACE_PLACEHOLDER|$EMBEDDED_WORKSPACE|g" "$TEST_DIR/config.json" > "$EMBEDDED_CONFIG"

if [ -f "$EMBEDDED_BINARY" ]; then
    "$EMBEDDED_BINARY" "$EMBEDDED_CONFIG"
    EMBEDDED_STATUS=$?
else
    echo "WARNING: Embedded binary not found at $EMBEDDED_BINARY"
    EMBEDDED_STATUS=1
fi

# Test external implementation
echo ""
echo "Testing external implementation..."
EXTERNAL_CONFIG="$TEST_DIR/external_config.json"
sed "s|WORKSPACE_PLACEHOLDER|$EXTERNAL_WORKSPACE|g" "$TEST_DIR/config.json" > "$EXTERNAL_CONFIG"

if [ -f "$EXTERNAL_BINARY" ]; then
    "$EXTERNAL_BINARY" "$EXTERNAL_CONFIG"
    EXTERNAL_STATUS=$?
else
    echo "WARNING: External binary not found at $EXTERNAL_BINARY"
    EXTERNAL_STATUS=1
fi

# Compare results
echo ""
echo "Comparing results..."

# Check if both succeeded
if [ $EMBEDDED_STATUS -ne 0 ]; then
    echo "FAIL: Embedded implementation failed"
    exit 1
fi

if [ $EXTERNAL_STATUS -ne 0 ]; then
    echo "FAIL: External implementation failed"
    exit 1
fi

# Verify both created the same directory structure
if [ ! -d "$EMBEDDED_WORKSPACE/subdir1" ] || [ ! -d "$EMBEDDED_WORKSPACE/subdir2" ]; then
    echo "FAIL: Embedded implementation did not create expected directories"
    exit 1
fi

if [ ! -d "$EXTERNAL_WORKSPACE/subdir1" ] || [ ! -d "$EXTERNAL_WORKSPACE/subdir2" ]; then
    echo "FAIL: External implementation did not create expected directories"
    exit 1
fi

# Compare directory structures
EMBEDDED_TREE=$(cd "$EMBEDDED_WORKSPACE" && find . -type d | sort)
EXTERNAL_TREE=$(cd "$EXTERNAL_WORKSPACE" && find . -type d | sort)

if [ "$EMBEDDED_TREE" != "$EXTERNAL_TREE" ]; then
    echo "FAIL: Directory structures differ"
    echo "Embedded:"
    echo "$EMBEDDED_TREE"
    echo "External:"
    echo "$EXTERNAL_TREE"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ PASS: Both implementations produced identical results"
echo "========================================="
