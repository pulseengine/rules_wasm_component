"""Module extensions for WebAssembly toolchain configuration"""

load("//toolchains:cpp_component_toolchain.bzl", "cpp_component_toolchain_repository")
load("//toolchains:jco_toolchain.bzl", "jco_toolchain_repository")
load("//toolchains:tinygo_toolchain.bzl", "tinygo_toolchain_repository")
load("//toolchains:wasi_sdk_toolchain.bzl", "wasi_sdk_repository")
load("//toolchains:wasm_toolchain.bzl", "wasm_toolchain_repository")
load("//toolchains:wasmtime_toolchain.bzl", "wasmtime_repository")
load("//toolchains:wizer_toolchain.bzl", "wizer_toolchain_repository")
load("//toolchains:wkg_toolchain.bzl", "wkg_toolchain_repository")
load("//wit:wasi_deps.bzl", "wasi_wit_dependencies")

# =============================================================================
# UNIFIED BUNDLE CONFIGURATION
# =============================================================================
# Use wasm_component_bundle.configure() to set up all toolchains from a
# pre-validated version bundle. This is the recommended approach.
#
# Example usage in MODULE.bazel:
#   wasm_bundle = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_component_bundle")
#   wasm_bundle.configure(bundle = "stable-2025-12")
#   use_repo(wasm_bundle, "wasm_tools_toolchains", "wasmtime_toolchain", ...)
# =============================================================================

def _wasm_component_bundle_impl(module_ctx):
    """Implementation of unified bundle configuration extension.

    This sets up all toolchains using versions from a pre-validated bundle,
    ensuring compatibility between tools.
    """
    bundle_name = ""

    # Get bundle configuration from tags
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            if tag.bundle:
                bundle_name = tag.bundle

    # Create all toolchain repositories with bundle parameter
    # The bundle parameter tells each repository to read versions from
    # checksums/toolchain_bundles.json instead of using hardcoded defaults

    # Core WASM tools (wasm-tools, wac, wit-bindgen)
    wasm_toolchain_repository(
        name = "wasm_tools_toolchains",
        bundle = bundle_name,
        strategy = "download",
    )

    # Wasmtime runtime
    wasmtime_repository(
        name = "wasmtime_toolchain",
        bundle = bundle_name,
        strategy = "download",
    )

    # Wizer pre-initialization
    wizer_toolchain_repository(
        name = "wizer_toolchain",
        bundle = bundle_name,
        strategy = "download",
    )

    # WKG package manager
    wkg_toolchain_repository(
        name = "wkg_toolchain",
        bundle = bundle_name,
        strategy = "download",
    )

    # TinyGo for Go components
    tinygo_toolchain_repository(
        name = "tinygo_toolchain",
        bundle = bundle_name,
    )

    # WASI SDK for C/C++ components
    wasi_sdk_repository(
        name = "wasi_sdk",
        bundle = bundle_name,
        strategy = "download",
    )

    # C/C++ component toolchain
    cpp_component_toolchain_repository(
        name = "cpp_component_toolchain",
        bundle = bundle_name,
        strategy = "download",
    )

    # JCO for JavaScript components
    jco_toolchain_repository(
        name = "jco_toolchain",
        bundle = bundle_name,
    )

    # WASI WIT definitions
    wasi_wit_dependencies()

# Unified bundle configuration extension
wasm_component_bundle = module_extension(
    implementation = _wasm_component_bundle_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "bundle": attr.string(
                    doc = """Toolchain bundle name from checksums/toolchain_bundles.json.

Available bundles:
- stable-2025-12: Full toolchain with all languages (default)
- minimal: Just wasm-tools, wit-bindgen, wasmtime for Rust-only builds
- composition: Tools for component composition workflows (adds wac, wkg)

Using a bundle ensures all tool versions are compatible with each other.""",
                    default = "stable-2025-12",
                ),
            },
        ),
    },
    doc = """Unified WebAssembly toolchain configuration using version bundles.

This extension sets up all WASM toolchains using pre-validated version
combinations from checksums/toolchain_bundles.json.

Example:
    wasm_bundle = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_component_bundle")
    wasm_bundle.configure(bundle = "stable-2025-12")
    use_repo(wasm_bundle, "wasm_tools_toolchains", "wasmtime_toolchain", "wizer_toolchain", ...)
""",
)

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
            strategy = "download",
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
                    doc = "Tool acquisition strategy: 'download' (prebuilt binaries from GitHub releases)",
                    default = "download",
                    values = ["download"],
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
        )

    # If no registrations, create default system SDK
    if not registrations:
        wasi_sdk_repository(
            name = "wasi_sdk",
            strategy = "download",
            version = "27",
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
                    doc = "SDK acquisition strategy: 'download'",
                    default = "download",
                    values = ["download"],
                ),
                "version": attr.string(
                    doc = "Version to use (for download strategy)",
                    default = "27",
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
            strategy = "download",
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
                    doc = "Tool acquisition strategy: 'download' (prebuilt binaries from GitHub releases)",
                    default = "download",
                    values = ["download"],
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
            version = registration.version,
            node_version = getattr(registration, "node_version", "20.18.0"),
        )

    # If no registrations, create default toolchain
    if not registrations:
        jco_toolchain_repository(
            name = "jco_toolchain",
            version = "1.4.0",
            node_version = "20.18.0",
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
                "version": attr.string(
                    doc = "jco version to use",
                    default = "1.4.0",
                ),
                "node_version": attr.string(
                    doc = "Node.js version for hermetic strategy",
                    default = "20.18.0",
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
            strategy = "download",
            wasi_sdk_version = "27",
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
                    doc = "Tool acquisition strategy: 'download' or 'build'",
                    default = "download",
                    values = ["download", "build"],
                ),
                "wasi_sdk_version": attr.string(
                    doc = "WASI SDK version to use",
                    default = "27",
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
            strategy = "download",
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
                    doc = "Installation strategy: 'download' (download prebuilt binary from GitHub releases)",
                    default = "download",
                    values = ["download"],
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
                    doc = "Installation strategy: 'download' (download binary)",
                    default = "download",
                    values = ["download"],
                ),
            },
        ),
    },
)

def _wasi_wit_extension_impl(module_ctx):
    """Implementation of WASI WIT dependencies module extension"""

    # Load WASI WIT interface definitions for all modules that request them
    load_wasi = False
    for mod in module_ctx.modules:
        if mod.tags.init:
            load_wasi = True
            break

    if load_wasi:
        wasi_wit_dependencies()

# Module extension for WASI WIT interface definitions
wasi_wit = module_extension(
    implementation = _wasi_wit_extension_impl,
    tag_classes = {
        "init": tag_class(
            attrs = {},
            doc = "Initialize WASI WIT interface definitions",
        ),
    },
)
