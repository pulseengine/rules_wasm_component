"""Module extensions for WebAssembly toolchain configuration"""

load("//toolchains:wasm_toolchain.bzl", "wasm_toolchain_repository")

def _wasm_toolchain_extension_impl(module_ctx):
    """Implementation of wasm_toolchain module extension"""

    registrations = {}

    # Collect all toolchain registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create toolchain repositories
    for name, registration in registrations.items():
        wasm_toolchain_repository(
            name = name + "_toolchains",
            strategy = registration.strategy,
            version = registration.version,
            git_commit = registration.git_commit,
            wasm_tools_url = registration.wasm_tools_url,
            wac_url = registration.wac_url,
            wit_bindgen_url = registration.wit_bindgen_url,
        )

    # If no registrations, create default system toolchain
    if not registrations:
        wasm_toolchain_repository(
            name = "wasm_tools_toolchains",
            strategy = "system",
            version = "1.235.0",
            git_commit = "main",
            wasm_tools_url = "",
            wac_url = "",
            wit_bindgen_url = "",
        )

# Module extension for WASM toolchain
wasm_toolchain = module_extension(
    implementation = _wasm_toolchain_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this toolchain registration",
                    default = "wasm_tools",
                ),
                "strategy": attr.string(
                    doc = "Tool acquisition strategy: 'system', 'download', or 'build'",
                    default = "system",
                    values = ["system", "download", "build"],
                ),
                "version": attr.string(
                    doc = "Version to use (for download/build strategies)",
                    default = "1.235.0",
                ),
                "git_commit": attr.string(
                    doc = "Git commit/tag to build from (for build strategy)",
                    default = "main",
                ),
                "wasm_tools_url": attr.string(
                    doc = "Custom download URL for wasm-tools (optional)",
                ),
                "wac_url": attr.string(
                    doc = "Custom download URL for wac (optional)",
                ),
                "wit_bindgen_url": attr.string(
                    doc = "Custom download URL for wit-bindgen (optional)",
                ),
            },
        ),
    },
)
