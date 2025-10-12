#!/usr/bin/env bash
# Cross-platform hermiticity test
# Automatically detects OS and uses appropriate tracing tool

set -euo pipefail

OS="$(uname -s)"

case "$OS" in
    Linux*)
        echo "🐧 Detected Linux - using strace"
        exec "$(dirname "$0")/linux_hermetic_test.sh" "$@"
        ;;
    Darwin*)
        echo "🍎 Detected macOS - using fs_usage"
        exec "$(dirname "$0")/macos_hermetic_test.sh" "$@"
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        echo "This tool supports Linux (strace) and macOS (fs_usage)"
        exit 1
        ;;
esac
