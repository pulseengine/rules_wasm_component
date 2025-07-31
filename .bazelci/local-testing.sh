#!/bin/bash
# Local testing script to reproduce Buildkite CI environment
# This script helps validate the CI configuration before submitting

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BAZEL_VERSION="${BAZEL_VERSION:-8.3.1}"
PLATFORM="${PLATFORM:-wasm32-wasi}"
CONFIG="${CONFIG:-wasm_component}"

echo -e "${GREEN}=== rules_wasm_component Local CI Testing ===${NC}"
echo "Bazel Version: $BAZEL_VERSION"
echo "Platform: $PLATFORM"
echo "Config: $CONFIG"
echo ""

# Function to run commands with error handling
run_command() {
    local description="$1"
    shift
    echo -e "${YELLOW}Running: $description${NC}"
    echo "Command: $*"
    if "$@"; then
        echo -e "${GREEN}✓ $description succeeded${NC}"
    else
        echo -e "${RED}✗ $description failed${NC}"
        return 1
    fi
    echo ""
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Setup WebAssembly toolchain (similar to CI)
setup_wasm_toolchain() {
    echo -e "${YELLOW}=== Setting up WebAssembly toolchain ===${NC}"

    # Install Rust if not present
    if ! command_exists rustc; then
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi

    # Add WASM targets
    run_command "Adding wasm32-wasip1 target" rustup target add wasm32-wasip1
    run_command "Adding wasm32-wasip2 target" rustup target add wasm32-wasip2
    run_command "Adding wasm32-unknown-unknown target" rustup target add wasm32-unknown-unknown

    # Install WebAssembly tools
    if ! command_exists wasm-tools; then
        run_command "Installing wasm-tools" cargo install wasm-tools
    fi

    if ! command_exists wac; then
        run_command "Installing wac-cli" cargo install wac-cli
    fi

    if ! command_exists wit-bindgen; then
        run_command "Installing wit-bindgen-cli" cargo install wit-bindgen-cli
    fi
}

# Setup Bazel configuration (similar to CI)
setup_bazel_config() {
    echo -e "${YELLOW}=== Setting up Bazel configuration ===${NC}"

    # Create user.bazelrc with CI-like settings
    cat > user.bazelrc << EOF
# CI-like configuration for local testing
build --incompatible_enable_cc_toolchain_resolution
build --platforms=//platforms:$PLATFORM
build --config=$CONFIG

# Test settings
test --test_output=errors
test --test_summary=detailed

# Resource limits (adjust based on your machine)
build --local_resources=memory=HOST_RAM*.6
build --local_resources=cpu=HOST_CPUS*.8
EOF

    echo "Created user.bazelrc with CI-like settings"
}

# Test basic functionality
test_basic() {
    echo -e "${YELLOW}=== Testing basic functionality ===${NC}"

    run_command "Bazel version check" bazel version

    run_command "Build all targets" bazel build //...

    run_command "Run all tests" bazel test //...

    # Test specific examples
    run_command "Build basic example" bazel build //examples/basic:hello_component

    run_command "Build multi-profile examples" bazel build //examples/multi_profile:camera_sensor //examples/multi_profile:object_detection
}

# Test with Clippy (if requested)
test_with_clippy() {
    if [[ "${WITH_CLIPPY:-}" == "true" ]]; then
        echo -e "${YELLOW}=== Testing with Clippy ===${NC}"

        # Add clippy config to user.bazelrc
        echo "build --config=clippy" >> user.bazelrc

        run_command "Build with Clippy" bazel build //...
    fi
}

# Validate generated WebAssembly components
validate_wasm_components() {
    echo -e "${YELLOW}=== Validating WebAssembly components ===${NC}"

    # Build components first
    run_command "Build hello component" bazel build //examples/basic:hello_component

    # Validate with wasm-tools
    if command_exists wasm-tools; then
        HELLO_COMPONENT="bazel-bin/examples/basic/hello_component.wasm"
        if [[ -f "$HELLO_COMPONENT" ]]; then
            run_command "Validate hello component" wasm-tools validate "$HELLO_COMPONENT"
        else
            echo -e "${RED}Component file not found: $HELLO_COMPONENT${NC}"
        fi
    else
        echo -e "${YELLOW}wasm-tools not available, skipping validation${NC}"
    fi

    # Test multi-profile components if they exist
    run_command "Build multi-profile debug component" bazel build //examples/multi_profile:camera_sensor_debug || true
    run_command "Build multi-profile release component" bazel build //examples/multi_profile:camera_sensor_release || true

    # Validate multi-profile components
    for component in "camera_sensor_debug.component.wasm" "camera_sensor_release.component.wasm"; do
        COMPONENT_PATH="bazel-bin/examples/multi_profile/$component"
        if [[ -f "$COMPONENT_PATH" ]] && command_exists wasm-tools; then
            run_command "Validate $component" wasm-tools validate "$COMPONENT_PATH"
        fi
    done
}

# Test integration scenarios
test_integration() {
    echo -e "${YELLOW}=== Testing integration scenarios ===${NC}"

    # Integration tests
    run_command "Run integration tests" bazel test //test/integration/... || true

    # Unit tests
    run_command "Run unit tests" bazel test //test/unit/... || true

    # Toolchain tests
    run_command "Run toolchain tests" bazel test //test/toolchain/... || true
}

# Test different configurations
test_configurations() {
    echo -e "${YELLOW}=== Testing different configurations ===${NC}"

    # Test optimized build
    echo "build --compilation_mode=opt" >> user.bazelrc
    run_command "Build with optimization" bazel build //examples/basic:hello_component

    # Remove opt flag
    sed -i.bak '/--compilation_mode=opt/d' user.bazelrc
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}=== Cleaning up ===${NC}"

    # Remove generated files
    rm -f user.bazelrc user.bazelrc.bak

    # Clean Bazel outputs (optional)
    if [[ "${CLEAN_AFTER:-}" == "true" ]]; then
        run_command "Clean Bazel outputs" bazel clean
    fi
}

# Main execution
main() {
    echo -e "${GREEN}Starting local CI testing...${NC}"
    echo ""

    # Check if we're in the right directory
    if [[ ! -f "MODULE.bazel" ]] || [[ ! -f ".bazelci/presubmit.yml" ]]; then
        echo -e "${RED}Error: Please run this script from the rules_wasm_component root directory${NC}"
        exit 1
    fi

    # Set up environment
    setup_wasm_toolchain
    setup_bazel_config

    # Run tests
    test_basic
    test_with_clippy
    validate_wasm_components
    test_integration
    test_configurations

    # Cleanup
    cleanup

    echo -e "${GREEN}=== Local CI testing completed successfully! ===${NC}"
}

# Handle script arguments
case "${1:-all}" in
    "setup")
        setup_wasm_toolchain
        setup_bazel_config
        ;;
    "basic")
        setup_bazel_config
        test_basic
        ;;
    "validate")
        setup_bazel_config
        validate_wasm_components
        ;;
    "integration")
        setup_bazel_config
        test_integration
        ;;
    "clean")
        cleanup
        ;;
    "all"|*)
        main
        ;;
esac
