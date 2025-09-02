"""Public API for WASM utility rules"""

load(
    "//wasm:multi_language_wasm_component.bzl",
    _multi_language_wasm_component = "multi_language_wasm_component",
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
load(
    "//wasm:wasm_signing.bzl",
    _wasm_keygen = "wasm_keygen",
    _wasm_sign = "wasm_sign",
    _wasm_verify = "wasm_verify",
)
load(
    "//wasm:wasm_validate.bzl",
    _wasm_validate = "wasm_validate",
)
load(
    "//wasm:wasm_precompile.bzl",
    _wasm_precompile = "wasm_precompile",
)
load(
    "//wasm:wasm_run.bzl",
    _wasm_run = "wasm_run",
    _wasm_test = "wasm_test",
)
load(
    "//wasm:wasm_aot_aspect.bzl",
    _wasm_aot_aspect = "wasm_aot_aspect",
    _wasm_aot_config = "wasm_aot_config",
)

# Re-export public rules
wasm_validate = _wasm_validate
wasm_component_new = _wasm_component_new
wasm_component_wizer = _wasm_component_wizer
wizer_chain = _wizer_chain
multi_language_wasm_component = _multi_language_wasm_component

# WebAssembly signing rules
wasm_keygen = _wasm_keygen
wasm_sign = _wasm_sign
wasm_verify = _wasm_verify

# WebAssembly AOT compilation rules
wasm_precompile = _wasm_precompile
wasm_run = _wasm_run
wasm_test = _wasm_test
wasm_aot_aspect = _wasm_aot_aspect
wasm_aot_config = _wasm_aot_config
