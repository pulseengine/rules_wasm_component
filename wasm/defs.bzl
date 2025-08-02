"""Public API for WASM utility rules"""

load(
    "//wasm:wasm_validate.bzl",
    _wasm_validate = "wasm_validate",
)
load(
    "//wasm:wasm_component_new.bzl",
    _wasm_component_new = "wasm_component_new",
)
load(
    "//wasm:wasm_component_wizer.bzl",
    _wasm_component_wizer = "wasm_component_wizer",
    _wizer_chain = "wizer_chain",
)

# Re-export public rules
wasm_validate = _wasm_validate
wasm_component_new = _wasm_component_new
wasm_component_wizer = _wasm_component_wizer
wizer_chain = _wizer_chain
