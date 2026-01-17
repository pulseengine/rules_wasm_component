"""Language-specific WebAssembly toolchain extensions.

This module provides lazy toolchain loading - only download what you need.

Usage in MODULE.bazel:

    # Rust-only (minimal, ~50MB download):
    rust_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "rust_wasm")
    rust_wasm.configure()
    use_repo(rust_wasm, "wasm_tools_toolchains", "wasmtime_toolchain", "wkg_toolchain")
    register_toolchains(
        "@wasm_tools_toolchains//:wasm_tools_toolchain",
        "@wasmtime_toolchain//:wasmtime_toolchain",
        "@wkg_toolchain//:wkg_toolchain_def",
    )

    # Add Go support (+500MB for TinyGo):
    go_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "go_wasm")
    go_wasm.configure()
    use_repo(go_wasm, "tinygo_toolchain")
    register_toolchains("@tinygo_toolchain//:tinygo_toolchain_def")

    # Add C++ support (+300MB for WASI SDK):
    cpp_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "cpp_wasm")
    cpp_wasm.configure()
    use_repo(cpp_wasm, "wasi_sdk", "cpp_toolchain")
    register_toolchains(
        "@wasi_sdk//:wasi_sdk_toolchain",
        "@wasi_sdk//:cc_toolchain",
        "@cpp_toolchain//:cpp_component_toolchain",
    )

    # Add JavaScript support (+100MB for Node.js/JCO):
    js_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "js_wasm")
    js_wasm.configure()
    use_repo(js_wasm, "jco_toolchain")
    register_toolchains("@jco_toolchain//:jco_toolchain")

    # Add Python support (+25MB for componentize-py):
    python_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "python_wasm")
    python_wasm.configure()
    use_repo(python_wasm, "componentize_py_toolchain")
    register_toolchains("@componentize_py_toolchain//:componentize_py_toolchain")

    # Add MoonBit support (requires rules_moonbit):
    # MoonBit compiler is provided by rules_moonbit, wasm-tools by rust_wasm.
    # No additional repositories needed - just use the rules!
    # See //moonbit:defs.bzl for moonbit_wasm_component and moonbit_wasm_binary.

Download sizes (approximate):
- rust_wasm: ~50MB (wasm-tools, wasmtime, wkg)
- go_wasm: +500MB (TinyGo with LLVM)
- cpp_wasm: +300MB (WASI SDK with Clang)
- js_wasm: +100MB (Node.js, JCO)
- python_wasm: +25MB (componentize-py)
- moonbit_wasm: ~0MB (uses rules_moonbit, needs rust_wasm for wasm-tools)
"""

load("//toolchains:componentize_py_toolchain.bzl", "componentize_py_toolchain_repository")
load("//toolchains:cpp_component_toolchain.bzl", "cpp_component_toolchain_repository")
load("//toolchains:jco_toolchain.bzl", "jco_toolchain_repository")
load("//toolchains:tinygo_toolchain.bzl", "tinygo_toolchain_repository")
load("//toolchains:wasi_sdk_toolchain.bzl", "wasi_sdk_repository")
load("//toolchains:wasm_toolchain.bzl", "wasm_toolchain_repository")
load("//toolchains:wasmtime_toolchain.bzl", "wasmtime_repository")
load("//toolchains:wkg_toolchain.bzl", "wkg_toolchain_repository")
load("//wit:defs.bzl", "wasi_wit_dependencies")

# =============================================================================
# DEFAULT VERSIONS
# =============================================================================
# These are the default versions used when not specified.
# For guaranteed compatibility, use version bundles from checksums/toolchain_bundles.json

_DEFAULT_VERSIONS = {
    "wasm_tools": "1.243.0",
    "wasmtime": "39.0.1",
    "wkg": "0.13.0",
    "tinygo": "0.40.1",
    "wasi_sdk": "29",
    "jco": "1.4.0",
    "node": "20.18.0",
    "componentize_py": "canary",
}

# =============================================================================
# RUST WASM EXTENSION (Core - Always Needed)
# =============================================================================
# Provides: wasm-tools, wasmtime, wkg, WASI WIT definitions
# Download size: ~50MB
# Required for: All WebAssembly component builds

def _rust_wasm_impl(module_ctx):
    """Implementation of Rust WebAssembly toolchain extension.

    This is the minimal toolchain for Rust WebAssembly components.
    It includes core tools needed by all languages.
    """
    config = None
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            config = tag
            break
        if config:
            break

    # Use configured versions or defaults
    wasm_tools_version = config.wasm_tools_version if config else _DEFAULT_VERSIONS["wasm_tools"]
    wasmtime_version = config.wasmtime_version if config else _DEFAULT_VERSIONS["wasmtime"]
    wkg_version = config.wkg_version if config else _DEFAULT_VERSIONS["wkg"]

    # Core WASM tools (wasm-tools, wac, wit-bindgen)
    wasm_toolchain_repository(
        name = "wasm_tools_toolchains",
        strategy = "download",
        version = wasm_tools_version,
    )

    # Wasmtime runtime (includes wizer as of v39.0.0)
    wasmtime_repository(
        name = "wasmtime_toolchain",
        strategy = "download",
        version = wasmtime_version,
    )

    # WKG package manager
    wkg_toolchain_repository(
        name = "wkg_toolchain",
        strategy = "download",
        version = wkg_version,
    )

    # WASI WIT definitions (always needed)
    wasi_wit_dependencies()

rust_wasm = module_extension(
    implementation = _rust_wasm_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "wasm_tools_version": attr.string(
                    doc = "wasm-tools version",
                    default = _DEFAULT_VERSIONS["wasm_tools"],
                ),
                "wasmtime_version": attr.string(
                    doc = "Wasmtime version",
                    default = _DEFAULT_VERSIONS["wasmtime"],
                ),
                "wkg_version": attr.string(
                    doc = "wkg version",
                    default = _DEFAULT_VERSIONS["wkg"],
                ),
            },
        ),
    },
    doc = """Minimal WebAssembly toolchain for Rust components.

Includes:
- wasm-tools (component manipulation)
- wasmtime (runtime with wizer)
- wkg (package management)
- WASI WIT definitions

Download size: ~50MB

Example:
    rust_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "rust_wasm")
    rust_wasm.configure()
    use_repo(rust_wasm, "wasm_tools_toolchains", "wasmtime_toolchain", "wkg_toolchain")
""",
)

# =============================================================================
# GO WASM EXTENSION
# =============================================================================
# Provides: TinyGo compiler
# Download size: ~500MB (includes LLVM)
# Required for: Go WebAssembly components

def _go_wasm_impl(module_ctx):
    """Implementation of Go WebAssembly toolchain extension."""
    config = None
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            config = tag
            break
        if config:
            break

    tinygo_version = config.tinygo_version if config else _DEFAULT_VERSIONS["tinygo"]

    # TinyGo compiler for WASI Preview 2
    tinygo_toolchain_repository(
        name = "tinygo_toolchain",
        tinygo_version = tinygo_version,
    )

go_wasm = module_extension(
    implementation = _go_wasm_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "tinygo_version": attr.string(
                    doc = "TinyGo version",
                    default = _DEFAULT_VERSIONS["tinygo"],
                ),
            },
        ),
    },
    doc = """Go WebAssembly toolchain using TinyGo.

Includes:
- TinyGo compiler with WASI Preview 2 support

Download size: ~500MB (includes LLVM)

Example:
    go_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "go_wasm")
    go_wasm.configure()
    use_repo(go_wasm, "tinygo_toolchain")
    register_toolchains("@tinygo_toolchain//:tinygo_toolchain_def")
""",
)

# =============================================================================
# C++ WASM EXTENSION
# =============================================================================
# Provides: WASI SDK (Clang for WASM), C++ component toolchain
# Download size: ~300MB
# Required for: C/C++ WebAssembly components

def _cpp_wasm_impl(module_ctx):
    """Implementation of C++ WebAssembly toolchain extension."""
    config = None
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            config = tag
            break
        if config:
            break

    wasi_sdk_version = config.wasi_sdk_version if config else _DEFAULT_VERSIONS["wasi_sdk"]

    # WASI SDK (Clang for WASM target)
    wasi_sdk_repository(
        name = "wasi_sdk",
        strategy = "download",
        version = wasi_sdk_version,
    )

    # C++ component toolchain
    cpp_component_toolchain_repository(
        name = "cpp_toolchain",
        strategy = "download",
        wasi_sdk_version = wasi_sdk_version,
    )

cpp_wasm = module_extension(
    implementation = _cpp_wasm_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "wasi_sdk_version": attr.string(
                    doc = "WASI SDK version",
                    default = _DEFAULT_VERSIONS["wasi_sdk"],
                ),
            },
        ),
    },
    doc = """C++ WebAssembly toolchain using WASI SDK.

Includes:
- WASI SDK (Clang with WASM target)
- C++ component toolchain

Download size: ~300MB

Example:
    cpp_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "cpp_wasm")
    cpp_wasm.configure()
    use_repo(cpp_wasm, "wasi_sdk", "cpp_toolchain")
    register_toolchains(
        "@wasi_sdk//:wasi_sdk_toolchain",
        "@cpp_toolchain//:cpp_component_toolchain",
    )
""",
)

# =============================================================================
# JAVASCRIPT WASM EXTENSION
# =============================================================================
# Provides: JCO (JavaScript Component Tools), hermetic Node.js
# Download size: ~100MB
# Required for: JavaScript/TypeScript WebAssembly components

def _js_wasm_impl(module_ctx):
    """Implementation of JavaScript WebAssembly toolchain extension."""
    config = None
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            config = tag
            break
        if config:
            break

    jco_version = config.jco_version if config else _DEFAULT_VERSIONS["jco"]
    node_version = config.node_version if config else _DEFAULT_VERSIONS["node"]

    # JCO (JavaScript Component Tools)
    jco_toolchain_repository(
        name = "jco_toolchain",
        version = jco_version,
        node_version = node_version,
    )

js_wasm = module_extension(
    implementation = _js_wasm_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "jco_version": attr.string(
                    doc = "JCO version",
                    default = _DEFAULT_VERSIONS["jco"],
                ),
                "node_version": attr.string(
                    doc = "Node.js version",
                    default = _DEFAULT_VERSIONS["node"],
                ),
            },
        ),
    },
    doc = """JavaScript WebAssembly toolchain using JCO.

Includes:
- JCO (JavaScript Component Tools)
- Hermetic Node.js runtime

Download size: ~100MB

Example:
    js_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "js_wasm")
    js_wasm.configure()
    use_repo(js_wasm, "jco_toolchain")
    register_toolchains("@jco_toolchain//:jco_toolchain")
""",
)

# =============================================================================
# PYTHON WASM EXTENSION
# =============================================================================
# Provides: componentize-py (Bytecode Alliance tool for Python WASM components)
# Download size: ~25MB
# Required for: Python WebAssembly components

def _python_wasm_impl(module_ctx):
    """Implementation of Python WebAssembly toolchain extension."""
    config = None
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            config = tag
            break
        if config:
            break

    componentize_py_version = config.componentize_py_version if config else _DEFAULT_VERSIONS["componentize_py"]

    # componentize-py toolchain
    componentize_py_toolchain_repository(
        name = "componentize_py_toolchain",
        version = componentize_py_version,
    )

python_wasm = module_extension(
    implementation = _python_wasm_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "componentize_py_version": attr.string(
                    doc = "componentize-py version",
                    default = _DEFAULT_VERSIONS["componentize_py"],
                ),
            },
        ),
    },
    doc = """Python WebAssembly toolchain using componentize-py.

Includes:
- componentize-py (Bytecode Alliance tool for Python WASM components)

Download size: ~25MB

Note: componentize-py bundles a Python interpreter in the WASM component,
resulting in larger component sizes (~25MB overhead). Best suited for
business logic and glue code.

Example:
    python_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "python_wasm")
    python_wasm.configure()
    use_repo(python_wasm, "componentize_py_toolchain")
    register_toolchains("@componentize_py_toolchain//:componentize_py_toolchain")
""",
)

# =============================================================================
# MOONBIT WASM EXTENSION
# =============================================================================
# Provides: Documentation and API consistency for MoonBit support
# Download size: ~0MB (MoonBit compiler from rules_moonbit, wasm-tools from rust_wasm)
# Required for: MoonBit WebAssembly components
#
# Unlike other languages, MoonBit's toolchain comes from rules_moonbit (external dep).
# This extension exists for API consistency and documentation.

def _moonbit_wasm_impl(module_ctx):
    """Implementation of MoonBit WebAssembly extension.

    MoonBit is unique among the supported languages:
    - The MoonBit compiler is provided by rules_moonbit (external dependency)
    - Component wrapping uses wasm-tools from rust_wasm extension

    This extension doesn't register new repositories - it exists for:
    1. API consistency with other language extensions
    2. Clear documentation of MoonBit requirements
    3. Future extensibility if MoonBit-specific tooling is added
    """

    # MoonBit toolchain comes from rules_moonbit (bazel_dep)
    # wasm-tools comes from rust_wasm extension
    # Nothing additional to register here
    pass

moonbit_wasm = module_extension(
    implementation = _moonbit_wasm_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {},
        ),
    },
    doc = """MoonBit WebAssembly component support.

MoonBit is a WASM-native language with 25x faster compilation than Rust.
Unlike other languages, the MoonBit compiler comes from rules_moonbit.

Requirements:
- bazel_dep(name = "rules_moonbit") in MODULE.bazel
- rust_wasm extension for wasm-tools (or any extension providing wasm_tools_toolchain)

Download size: ~0MB additional (MoonBit toolchain from rules_moonbit)

Rules provided (in //moonbit:defs.bzl):
- moonbit_wasm_component: Library component with custom WIT exports
- moonbit_wasm_binary: CLI executable targeting wasi:cli/command

Example MODULE.bazel:
    bazel_dep(name = "rules_moonbit", version = "0.1.0")

    rust_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "rust_wasm")
    rust_wasm.configure()
    use_repo(rust_wasm, "wasm_tools_toolchains")
    register_toolchains("@wasm_tools_toolchains//:wasm_tools_toolchain")

Example BUILD.bazel:
    load("@rules_moonbit//moonbit:defs.bzl", "moonbit_wasm")
    load("@rules_wasm_component//moonbit:defs.bzl", "moonbit_wasm_component")

    moonbit_wasm(
        name = "calculator_core",
        srcs = ["calculator.mbt"],
    )

    moonbit_wasm_component(
        name = "calculator",
        lib = ":calculator_core",
        wit = "calculator.wit",
        world = "calculator",
    )
""",
)

# =============================================================================
# ALL LANGUAGES EXTENSION (Full Toolchain)
# =============================================================================
# Provides: Everything
# Download size: ~900MB total
# Use this for multi-language projects or when you need all languages

def _all_wasm_impl(module_ctx):
    """Implementation of full WebAssembly toolchain extension."""
    config = None
    for mod in module_ctx.modules:
        for tag in mod.tags.configure:
            config = tag
            break
        if config:
            break

    # Core tools
    wasm_tools_version = config.wasm_tools_version if config else _DEFAULT_VERSIONS["wasm_tools"]
    wasmtime_version = config.wasmtime_version if config else _DEFAULT_VERSIONS["wasmtime"]
    wkg_version = config.wkg_version if config else _DEFAULT_VERSIONS["wkg"]

    # Language-specific
    tinygo_version = config.tinygo_version if config else _DEFAULT_VERSIONS["tinygo"]
    wasi_sdk_version = config.wasi_sdk_version if config else _DEFAULT_VERSIONS["wasi_sdk"]
    jco_version = config.jco_version if config else _DEFAULT_VERSIONS["jco"]
    node_version = config.node_version if config else _DEFAULT_VERSIONS["node"]
    componentize_py_version = config.componentize_py_version if config else _DEFAULT_VERSIONS["componentize_py"]

    # === Core (always needed) ===
    wasm_toolchain_repository(
        name = "wasm_tools_toolchains",
        strategy = "download",
        version = wasm_tools_version,
    )

    wasmtime_repository(
        name = "wasmtime_toolchain",
        strategy = "download",
        version = wasmtime_version,
    )

    wkg_toolchain_repository(
        name = "wkg_toolchain",
        strategy = "download",
        version = wkg_version,
    )

    wasi_wit_dependencies()

    # === Go ===
    tinygo_toolchain_repository(
        name = "tinygo_toolchain",
        tinygo_version = tinygo_version,
    )

    # === C++ ===
    wasi_sdk_repository(
        name = "wasi_sdk",
        strategy = "download",
        version = wasi_sdk_version,
    )

    cpp_component_toolchain_repository(
        name = "cpp_toolchain",
        strategy = "download",
        wasi_sdk_version = wasi_sdk_version,
    )

    # === JavaScript ===
    jco_toolchain_repository(
        name = "jco_toolchain",
        version = jco_version,
        node_version = node_version,
    )

    # === Python ===
    componentize_py_toolchain_repository(
        name = "componentize_py_toolchain",
        version = componentize_py_version,
    )

all_wasm = module_extension(
    implementation = _all_wasm_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "wasm_tools_version": attr.string(default = _DEFAULT_VERSIONS["wasm_tools"]),
                "wasmtime_version": attr.string(default = _DEFAULT_VERSIONS["wasmtime"]),
                "wkg_version": attr.string(default = _DEFAULT_VERSIONS["wkg"]),
                "tinygo_version": attr.string(default = _DEFAULT_VERSIONS["tinygo"]),
                "wasi_sdk_version": attr.string(default = _DEFAULT_VERSIONS["wasi_sdk"]),
                "jco_version": attr.string(default = _DEFAULT_VERSIONS["jco"]),
                "node_version": attr.string(default = _DEFAULT_VERSIONS["node"]),
                "componentize_py_version": attr.string(default = _DEFAULT_VERSIONS["componentize_py"]),
            },
        ),
    },
    doc = """Full WebAssembly toolchain for all languages.

Includes:
- Core: wasm-tools, wasmtime, wkg, WASI WIT
- Go: TinyGo
- C++: WASI SDK
- JavaScript: JCO, Node.js
- Python: componentize-py

Download size: ~925MB total

Use language-specific extensions if you only need one language.

Example:
    all_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "all_wasm")
    all_wasm.configure()
    use_repo(all_wasm,
        "wasm_tools_toolchains", "wasmtime_toolchain", "wkg_toolchain",
        "tinygo_toolchain", "wasi_sdk", "cpp_toolchain", "jco_toolchain",
        "componentize_py_toolchain",
    )
""",
)
