"""Module extensions for WASM tool repositories"""

load("//toolchains:wasm_tools_repositories.bzl", "register_wasm_tool_repositories")
load("//toolchains:symmetric_wit_bindgen_toolchain.bzl", "symmetric_wit_bindgen_repository")

def _wasm_tool_repositories_impl(module_ctx):
    """Implementation of wasm_tool_repositories extension"""

    # Check for bundle configuration from tags
    bundle_name = None
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            if tag.bundle:
                bundle_name = tag.bundle

    # Pass bundle to repository registration (for future use)
    register_wasm_tool_repositories(bundle = bundle_name)

_configure_tag = tag_class(
    attrs = {
        "bundle": attr.string(
            doc = "Name of the toolchain bundle to use (e.g., 'stable-2025-12', 'minimal', 'composition'). See checksums/toolchain_bundles.json for available bundles.",
            default = "",
        ),
    },
)

wasm_tool_repositories = module_extension(
    implementation = _wasm_tool_repositories_impl,
    doc = "Extension for registering modernized WASM tool repositories",
    tag_classes = {
        "configure": _configure_tag,
    },
)

def _symmetric_wit_bindgen_impl(module_ctx):
    """Implementation of symmetric_wit_bindgen extension"""
    symmetric_wit_bindgen_repository(name = "symmetric_wit_bindgen")

symmetric_wit_bindgen = module_extension(
    implementation = _symmetric_wit_bindgen_impl,
    doc = "Extension for setting up symmetric wit-bindgen toolchain",
)
