#!/bin/bash
# Run clippy on all Rust targets in the project

set -e

echo "Running clippy on all Rust targets..."

# Run clippy using the clippy configuration
bazel build --config=clippy //...

echo "Clippy checks completed successfully!"