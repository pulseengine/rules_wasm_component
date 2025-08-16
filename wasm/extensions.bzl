"""Module extensions for WebAssembly toolchain configuration"""

load("//toolchains:wasm_toolchain.bzl", "wasm_toolchain_repository")
load("//toolchains:wasi_sdk_toolchain.bzl", "wasi_sdk_repository")
load("//toolchains:wkg_toolchain.bzl", "wkg_toolchain_repository")
load("//toolchains:jco_toolchain.bzl", "jco_toolchain_repository")
load("//toolchains:cpp_component_toolchain.bzl", "cpp_component_toolchain_repository")
load("//toolchains:tinygo_toolchain.bzl", "tinygo_toolchain_repository")
load("//toolchains:wizer_toolchain.bzl", "wizer_toolchain_repository")
load("//toolchains:wasmtime_toolchain.bzl", "wasmtime_repository")

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
            wasm_tools_commit = registration.wasm_tools_commit,
            wac_commit = registration.wac_commit,
            wit_bindgen_commit = registration.wit_bindgen_commit,
            wrpc_commit = registration.wrpc_commit,
            wasm_tools_url = registration.wasm_tools_url,
            wac_url = registration.wac_url,
            wit_bindgen_url = registration.wit_bindgen_url,
            wrpc_url = registration.wrpc_url,
        )

    # If no registrations, create default system toolchain
    if not registrations:
        wasm_toolchain_repository(
            name = "wasm_tools_toolchains",
            strategy = "system",
            version = "1.235.0",
            git_commit = "main",
            wasm_tools_commit = "",
            wac_commit = "",
            wit_bindgen_commit = "",
            wrpc_commit = "",
            wasm_tools_url = "",
            wac_url = "",
            wit_bindgen_url = "",
            wrpc_url = "",
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
                    doc = "Tool acquisition strategy: 'system', 'download', 'build', or 'hybrid'",
                    default = "system",
                    values = ["system", "download", "build", "hybrid"],
                ),
                "version": attr.string(
                    doc = "Version to use (for download/build strategies)",
                    default = "1.235.0",
                ),
                "git_commit": attr.string(
                    doc = "Git commit/tag to build from (for build strategy) - fallback for all tools",
                    default = "main",
                ),
                "wasm_tools_commit": attr.string(
                    doc = "Git commit/tag for wasm-tools (overrides git_commit)",
                ),
                "wac_commit": attr.string(
                    doc = "Git commit/tag for wac (overrides git_commit)",
                ),
                "wit_bindgen_commit": attr.string(
                    doc = "Git commit/tag for wit-bindgen (overrides git_commit)",
                ),
                "wrpc_commit": attr.string(
                    doc = "Git commit/tag for wrpc (overrides git_commit)",
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
                "wrpc_url": attr.string(
                    doc = "Custom download URL for wrpc (optional)",
                ),
            },
        ),
    },
)

def _wasi_sdk_extension_impl(module_ctx):
    """Implementation of wasi_sdk module extension"""

    registrations = {}

    # Collect all SDK registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create SDK repositories
    for name, registration in registrations.items():
        wasi_sdk_repository(
            name = name + "_sdk",
            strategy = registration.strategy,
            version = registration.version,
            url = registration.url,
            wasi_sdk_root = registration.wasi_sdk_root,
        )

    # If no registrations, create default system SDK
    if not registrations:
        wasi_sdk_repository(
            name = "wasi_sdk",
            strategy = "system",
            version = "25",
        )

# Module extension for WASI SDK
wasi_sdk = module_extension(
    implementation = _wasi_sdk_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this SDK registration",
                    default = "wasi",
                ),
                "strategy": attr.string(
                    doc = "SDK acquisition strategy: 'system' or 'download'",
                    default = "system",
                    values = ["system", "download"],
                ),
                "version": attr.string(
                    doc = "Version to use (for download strategy)",
                    default = "25",
                ),
                "url": attr.string(
                    doc = "Custom download URL for WASI SDK (optional)",
                ),
                "wasi_sdk_root": attr.string(
                    doc = "Path to system WASI SDK (for system strategy)",
                ),
            },
        ),
    },
)

def _wkg_extension_impl(module_ctx):
    """Implementation of wkg module extension"""

    registrations = {}

    # Collect all wkg registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create wkg repositories
    for name, registration in registrations.items():
        wkg_toolchain_repository(
            name = name + "_toolchain",
            strategy = registration.strategy,
            version = registration.version,
            url = registration.url,
            git_url = registration.git_url,
            git_commit = registration.git_commit,
        )

    # If no registrations, create default system toolchain
    if not registrations:
        wkg_toolchain_repository(
            name = "wkg_toolchain",
            strategy = "system",
            version = "0.11.0",
        )

# Module extension for wkg (WebAssembly Package Tools)
wkg = module_extension(
    implementation = _wkg_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this wkg registration",
                    default = "wkg",
                ),
                "strategy": attr.string(
                    doc = "Tool acquisition strategy: 'system', 'download', or 'build'",
                    default = "system",
                    values = ["system", "download", "build"],
                ),
                "version": attr.string(
                    doc = "Version to use (for download/build strategies)",
                    default = "0.11.0",
                ),
                "url": attr.string(
                    doc = "Custom base URL for downloads (optional)",
                ),
                "git_url": attr.string(
                    doc = "Git repository URL for build strategy (optional)",
                ),
                "git_commit": attr.string(
                    doc = "Git commit/tag to build from (optional)",
                ),
            },
        ),
    },
)

def _jco_extension_impl(module_ctx):
    """Implementation of jco module extension"""

    registrations = {}

    # Collect all jco registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create jco repositories
    for name, registration in registrations.items():
        jco_toolchain_repository(
            name = name + "_toolchain",
            strategy = registration.strategy,
            version = registration.version,
        )

    # If no registrations, create default system toolchain
    if not registrations:
        jco_toolchain_repository(
            name = "jco_toolchain",
            strategy = "system",
            version = "1.4.0",
        )

# Module extension for jco (JavaScript Component Tools)
jco = module_extension(
    implementation = _jco_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this jco registration",
                    default = "jco",
                ),
                "strategy": attr.string(
                    doc = "Tool acquisition strategy: 'system', 'download', or 'npm'",
                    default = "system",
                    values = ["system", "download", "npm"],
                ),
                "version": attr.string(
                    doc = "jco version to use",
                    default = "1.4.0",
                ),
            },
        ),
    },
)

def _cpp_component_extension_impl(module_ctx):
    """Implementation of cpp_component module extension"""

    registrations = {}

    # Collect all C/C++ component registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create C/C++ component repositories
    for name, registration in registrations.items():
        cpp_component_toolchain_repository(
            name = name + "_toolchain",
            strategy = registration.strategy,
            wasi_sdk_version = registration.wasi_sdk_version,
        )

    # If no registrations, create default system toolchain
    if not registrations:
        cpp_component_toolchain_repository(
            name = "cpp_component_toolchain",
            strategy = "system",
            wasi_sdk_version = "24",
        )

# Module extension for C/C++ WebAssembly components
cpp_component = module_extension(
    implementation = _cpp_component_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this C/C++ component registration",
                    default = "cpp_component",
                ),
                "strategy": attr.string(
                    doc = "Tool acquisition strategy: 'system', 'download', or 'build'",
                    default = "system",
                    values = ["system", "download", "build"],
                ),
                "wasi_sdk_version": attr.string(
                    doc = "WASI SDK version to use",
                    default = "24",
                ),
            },
        ),
    },
)

def _tinygo_extension_impl(module_ctx):
    """Implementation of TinyGo module extension"""

    registrations = {}

    # Collect all TinyGo registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create TinyGo repositories
    for name, registration in registrations.items():
        tinygo_toolchain_repository(
            name = name + "_toolchain",
            tinygo_version = registration.tinygo_version,
        )

    # If no registrations, create default TinyGo toolchain
    if not registrations:
        tinygo_toolchain_repository(
            name = "tinygo_toolchain",
            tinygo_version = "0.38.0",
        )

# Module extension for TinyGo WASI Preview 2 WebAssembly components
tinygo = module_extension(
    implementation = _tinygo_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this TinyGo registration",
                    default = "tinygo",
                ),
                "tinygo_version": attr.string(
                    doc = "TinyGo version to download and use",
                    default = "0.38.0",
                ),
            },
        ),
    },
)

def _wizer_extension_impl(module_ctx):
    """Implementation of Wizer module extension"""

    registrations = {}

    # Collect all Wizer registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create Wizer repositories
    for name, registration in registrations.items():
        wizer_toolchain_repository(
            name = name + "_toolchain",
            version = registration.version,
            strategy = registration.strategy,
        )

    # If no registrations, create default Wizer toolchain
    if not registrations:
        wizer_toolchain_repository(
            name = "wizer_toolchain",
            version = "9.0.0",
            strategy = "cargo",
        )

# Module extension for Wizer WebAssembly pre-initialization
wizer = module_extension(
    implementation = _wizer_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this Wizer registration",
                    default = "wizer",
                ),
                "version": attr.string(
                    doc = "Wizer version to install",
                    default = "9.0.0",
                ),
                "strategy": attr.string(
                    doc = "Installation strategy: 'build' (build from source), 'cargo' (install via cargo) or 'system' (use system install)",
                    default = "cargo",
                    values = ["build", "cargo", "system"],
                ),
            },
        ),
    },
)

def _wasmtime_extension_impl(module_ctx):
    """Implementation of Wasmtime module extension"""

    registrations = {}

    # Collect all Wasmtime registrations
    for mod in module_ctx.modules:
        for registration in mod.tags.register:
            registrations[registration.name] = registration

    # Create Wasmtime repositories
    for name, registration in registrations.items():
        wasmtime_repository(
            name = name + "_toolchain",
            version = registration.version,
            strategy = registration.strategy,
        )

    # If no registrations, create default Wasmtime toolchain
    if not registrations:
        wasmtime_repository(
            name = "wasmtime_toolchain",
            version = "35.0.0",
            strategy = "download",
        )

# Module extension for Wasmtime WebAssembly runtime
wasmtime = module_extension(
    implementation = _wasmtime_extension_impl,
    tag_classes = {
        "register": tag_class(
            attrs = {
                "name": attr.string(
                    doc = "Name for this Wasmtime registration",
                    default = "wasmtime",
                ),
                "version": attr.string(
                    doc = "Wasmtime version to install",
                    default = "35.0.0",
                ),
                "strategy": attr.string(
                    doc = "Installation strategy: 'download' (download binary) or 'system' (use system install)",
                    default = "download",
                    values = ["download", "system"],
                ),
            },
        ),
    },
)
