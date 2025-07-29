"""Module extensions for WASM tool repositories"""

load("//toolchains:wasm_tools_repositories.bzl", "register_wasm_tool_repositories")

def _wasm_tool_repositories_impl(module_ctx):
    """Implementation of wasm_tool_repositories extension"""
    register_wasm_tool_repositories()

wasm_tool_repositories = module_extension(
    implementation = _wasm_tool_repositories_impl,
    doc = "Extension for registering modernized WASM tool repositories",
)