#!/bin/bash
# Simple test that verifies the component was built successfully
# If the export! macro is not accessible, the build will fail

if [[ -f "$TEST_SRCDIR/_main/test/export_macro/test_component_release.component.wasm" ]]; then
    echo "✓ Component built successfully - export! macro is accessible"
    exit 0
else
    echo "✗ Component build failed - export! macro may not be accessible"
    exit 1
fi