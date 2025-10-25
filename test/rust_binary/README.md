# Rust WASM Binary Tests

This directory contains tests for the `rust_wasm_binary` rule, which creates
executable WASI CLI binaries from Rust source code.

## Test Coverage

### Build Tests

- **hello_cli_build_test**: Validates basic CLI binary compilation
- **cli_with_deps_build_test**: Validates CLI binary with Rust dependencies

## Purpose

The `rust_wasm_binary` rule is different from `rust_wasm_component_bindgen`:

- `rust_wasm_binary`: Creates **executable** WASI CLI binaries (like command-line tools)
- `rust_wasm_component_bindgen`: Creates **library** components with WIT interfaces

## Verification

These tests ensure:
1. The rule compiles Rust source to WASM successfully
2. The rule properly sets `executable = True` and creates executable outputs
3. Dependencies are correctly linked
4. The output is a valid WASI component (version 0x1000d)

## Running Tests

```bash
# Run all rust_wasm_binary tests
bazel test //test/rust_binary:rust_binary_tests

# Run all Rust tests (including these)
bazel test //test/language_support:rust_tests
```

## Example Usage

See the BUILD.bazel file in this directory for examples of using `rust_wasm_binary`.
