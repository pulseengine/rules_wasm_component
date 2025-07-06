"""Public API for WASM utility rules"""

load(
    "//wasm:wasm_validate.bzl",
    _wasm_validate = "wasm_validate",
)
load(
    "//wasm:wasm_component_new.bzl", 
    _wasm_component_new = "wasm_component_new",
)

# Re-export public rules
wasm_validate = _wasm_validate
wasm_component_new = _wasm_component_new