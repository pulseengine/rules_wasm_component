"""Public API for Rust WASM component rules"""

load(
    "//rust:rust_wasm_component.bzl",
    _rust_wasm_component = "rust_wasm_component",
)
load(
    "//rust:rust_wasm_component_test.bzl",
    _rust_wasm_component_test = "rust_wasm_component_test",
)
load(
    "//rust:clippy.bzl",
    _rust_wasm_component_clippy = "rust_wasm_component_clippy",
    _rust_clippy_all = "rust_clippy_all",
)
load(
    "//rust:rust_wasm_component_bindgen.bzl",
    _rust_wasm_component_bindgen = "rust_wasm_component_bindgen",
)

# Re-export public rules
rust_wasm_component = _rust_wasm_component
rust_wasm_component_test = _rust_wasm_component_test
rust_wasm_component_bindgen = _rust_wasm_component_bindgen
rust_wasm_component_clippy = _rust_wasm_component_clippy
rust_clippy_all = _rust_clippy_all