"""Public API for Rust WASM component rules"""

load(
    "//rust:rust_wasm_component.bzl",
    _rust_wasm_component = "rust_wasm_component",
)
load(
    "//rust:rust_wasm_component_test.bzl",
    _rust_wasm_component_test = "rust_wasm_component_test",
)

# Re-export public rules
rust_wasm_component = _rust_wasm_component
rust_wasm_component_test = _rust_wasm_component_test