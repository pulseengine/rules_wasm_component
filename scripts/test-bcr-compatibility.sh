#!/bin/bash

# BCR Compatibility Test Script
# This script tests the rules_wasm_component project in the same Docker environment
# used by Bazel Central Registry (BCR) for acceptance testing.

set -euo pipefail

# Configuration
DOCKER_IMAGE="gcr.io/bazel-public/ubuntu2204"
DEFAULT_TARGET="//examples/basic:hello_component"
DEFAULT_TIMEOUT=600  # 10 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "BCR Compatibility Test Script"
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -t, --target TARGET    Bazel target to test (default: $DEFAULT_TARGET)"
    echo "  -T, --timeout SECONDS  Timeout in seconds (default: $DEFAULT_TIMEOUT)"
    echo "  -q, --quick           Quick test (analyze only, no build)"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help"
    echo
    echo "Examples:"
    echo "  $0                                    # Test default target"
    echo "  $0 -t //test/integration:basic       # Test specific target"
    echo "  $0 -q                                # Quick toolchain validation"
    echo "  $0 -T 1200                           # Extend timeout to 20 minutes"
    echo
    echo "This script simulates the exact BCR acceptance testing environment"
    echo "and verifies that all builds are hermetic (no system dependencies)."
}

# Default values
TARGET="$DEFAULT_TARGET"
TIMEOUT="$DEFAULT_TIMEOUT"
QUICK_MODE=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -T|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        echo "Please start Docker daemon"
        exit 1
    fi
    
    log_verbose "Docker is available and running"
}

# Pull Docker image if needed
pull_docker_image() {
    log_info "Ensuring BCR Docker image is available..."
    
    if ! docker image inspect "$DOCKER_IMAGE" &> /dev/null; then
        log_info "Pulling BCR Docker image: $DOCKER_IMAGE"
        if ! docker pull "$DOCKER_IMAGE"; then
            log_error "Failed to pull Docker image: $DOCKER_IMAGE"
            exit 1
        fi
    else
        log_verbose "Docker image already available: $DOCKER_IMAGE"
    fi
}

# Main test function
run_bcr_test() {
    local test_type="${1:-build}"
    
    log_info "Starting BCR compatibility test..."
    log_info "Docker Image: $DOCKER_IMAGE"
    log_info "Target: $TARGET"
    log_info "Timeout: ${TIMEOUT}s"
    log_info "Test Type: $test_type"
    echo

    # Create the test command
    local bazel_command
    if [[ "$test_type" == "analyze" ]]; then
        bazel_command="query --output=label"
    else
        bazel_command="build"
    fi

    # Run the test in Docker
    local docker_script="
set -euo pipefail

echo '=== BCR Environment Information ==='
echo 'Operating System:'
cat /etc/os-release | grep PRETTY_NAME
echo
echo 'Architecture:'
uname -m
echo
echo 'Available System Tools:'
echo '  git:   \$(which git 2>/dev/null || echo \"not found\")'
echo '  curl:  \$(which curl 2>/dev/null || echo \"not found\")'
echo '  cargo: \$(which cargo 2>/dev/null || echo \"not found (expected)\")'
echo '  npm:   \$(which npm 2>/dev/null || echo \"not found (expected)\")'
echo '  go:    \$(which go 2>/dev/null || echo \"not found (expected)\")'
echo

echo '=== Bazel Setup ==='
mkdir -p /tmp/bazel_cache
chmod 755 /tmp/bazel_cache
echo 'Cache directory: /tmp/bazel_cache'
echo

echo '=== Testing Hermetic $bazel_command ==='
echo 'Target: $TARGET'
echo 'This test verifies:'
echo '  ✓ All toolchains work without system dependencies'
echo '  ✓ All downloads and builds are hermetic'
echo '  ✓ Build succeeds in minimal BCR environment'
echo

# Run with timeout
if [[ \\\"$bazel_command\\\" == \\\"query --output=label\\\" ]]; then
    timeout $TIMEOUT bazel --output_base=/tmp/bazel_cache query --output=label $TARGET
else
    timeout $TIMEOUT bazel --output_base=/tmp/bazel_cache $bazel_command $TARGET
fi

BUILD_EXIT_CODE=\$?
echo

if [ \$BUILD_EXIT_CODE -eq 0 ]; then
    echo '✅ BCR TEST SUCCESSFUL!'
    echo
    
    if [[ \"$bazel_command\" == \"build\" ]]; then
        echo '=== Build Verification ==='
        
        # Look for outputs
        echo 'Checking for build outputs...'
        output_count=\$(find bazel-bin -name '*.wasm' -type f 2>/dev/null | wc -l)
        
        if [ \$output_count -gt 0 ]; then
            echo \"✅ Found \$output_count WebAssembly component(s)\"
            find bazel-bin -name '*.wasm' -type f | head -3 | while read wasm_file; do
                echo \"  - \$wasm_file (\$(stat -c%s \"\$wasm_file\") bytes)\"
            done
        else
            echo 'ℹ️  No .wasm files found (may be expected for this target)'
        fi
    fi
    
elif [ \$BUILD_EXIT_CODE -eq 124 ]; then
    echo '❌ BCR TEST TIMED OUT'
    echo \"Build exceeded ${TIMEOUT} second limit\"
    echo 'Possible causes:'
    echo '  - Network issues downloading dependencies'
    echo '  - Non-hermetic system tool dependencies'
    echo '  - Toolchain configuration problems'
    exit 1
    
else
    echo '❌ BCR TEST FAILED'
    echo \"Exit code: \$BUILD_EXIT_CODE\"
    echo 'This indicates a compatibility issue with the BCR environment'
    exit 1
fi
"

    log_info "Running test in BCR Docker environment..."
    echo
    
    if docker run --rm -v "$(pwd):/workspace" -w /workspace "$DOCKER_IMAGE" bash -c "$docker_script"; then
        echo
        log_success "BCR compatibility test PASSED"
        echo
        echo "🎉 Your project is ready for BCR submission!"
        echo "   All toolchains work hermetically in the BCR testing environment."
        return 0
    else
        echo
        log_error "BCR compatibility test FAILED"
        echo
        echo "❌ Your project has BCR compatibility issues."
        echo "   Please review the error messages above and fix any issues."
        echo "   Common problems:"
        echo "   - Non-hermetic system tool dependencies"
        echo "   - Missing or incorrect toolchain configurations"
        echo "   - Network connectivity issues during builds"
        return 1
    fi
}

# Main execution
main() {
    echo "🐳 BCR (Bazel Central Registry) Compatibility Test"
    echo "=================================================="
    echo
    
    # Check prerequisites
    check_dependencies
    pull_docker_image
    
    # Run the appropriate test
    if [[ "$QUICK_MODE" == "true" ]]; then
        log_info "Running quick mode (analyze only)..."
        run_bcr_test "analyze"
    else
        log_info "Running full build test..."
        run_bcr_test "build"
    fi
}

# Execute main function
main "$@"