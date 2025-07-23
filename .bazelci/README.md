# Buildkite CI Configuration

This directory contains Buildkite CI configuration for `rules_wasm_component`, following the same patterns used by major Bazel rules projects like `rules_rust`, `rules_python`, and `rules_go`.

## Configuration Files

- **`presubmit.yml`** - Presubmit testing configuration for pull requests
- **`postsubmit.yml`** - Postsubmit testing configuration for main branch commits

## Test Matrix

### Platforms
- **Ubuntu 22.04** - Primary Linux platform
- **Ubuntu 18.04** - Legacy Linux support
- **macOS ARM64** - Apple Silicon support
- **Windows** - Cross-platform compatibility
- **RBE** - Remote Build Execution for scalability

### Bazel Versions
- **7.4.1** - Minimum supported LTS version
- **rolling** - Latest Bazel version (soft fail)

### Build Configurations
- **Standard** - Default build and test
- **Bzlmod** - Modern dependency management
- **Optimized** - Performance validation
- **Examples** - Real-world usage validation
- **Integration** - End-to-end workflow testing

## Specialized Test Jobs

### WebAssembly Component Specific
- **WAC Composition** - Component composition validation
- **Multi-profile** - Debug/release build variants
- **Toolchain** - WASM toolchain validation
- **Dependencies** - External dependency resolution

### Quality Assurance
- **Integration Tests** - End-to-end workflow validation
- **Unit Tests** - Rule implementation testing
- **Examples** - Real-world usage scenarios

## Integration with GitHub Actions

The project uses a hybrid CI approach:
- **GitHub Actions** - Community accessibility, formatting, documentation
- **Buildkite** - Industry standard for Bazel rules, comprehensive platform matrix

This follows the pattern established by `rules_rust` and other major Bazel rules projects for maximum compatibility with BCR (Bazel Central Registry) requirements.

## BCR Compatibility

The CI configuration is designed to meet BCR submission requirements:
- Multi-platform testing
- Multiple Bazel version support
- Comprehensive test coverage
- Industry-standard patterns

This ensures the rules are ready for publication to the Bazel Central Registry.