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
            wasm_tools_version = registration.version,
        )
    
    # If no registrations, create default
    if not registrations:
        wasm_toolchain_repository(
            name = "wasm_tools_toolchains", 
            wasm_tools_version = "1.0.60",
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
                "version": attr.string(
                    doc = "Version of wasm-tools to use",
                    default = "1.0.60",
                ),
            },
        ),
    },
)