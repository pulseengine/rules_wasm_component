"""Module extensions for WASM tool repositories"""

load("//toolchains:wasm_tools_repositories.bzl", "register_wasm_tool_repositories")
load("//toolchains:symmetric_wit_bindgen_toolchain.bzl", "symmetric_wit_bindgen_repository")

def _wasm_tool_repositories_impl(module_ctx):
    """Implementation of wasm_tool_repositories extension"""
    register_wasm_tool_repositories()

wasm_tool_repositories = module_extension(
    implementation = _wasm_tool_repositories_impl,
    doc = "Extension for registering modernized WASM tool repositories",
)

def _symmetric_wit_bindgen_impl(module_ctx):
    """Implementation of symmetric_wit_bindgen extension"""
    symmetric_wit_bindgen_repository(name = "symmetric_wit_bindgen")

symmetric_wit_bindgen = module_extension(
    implementation = _symmetric_wit_bindgen_impl,
    doc = "Extension for setting up symmetric wit-bindgen toolchain",
)
