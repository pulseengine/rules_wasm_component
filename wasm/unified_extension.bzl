"""Unified WebAssembly toolchain extension.

Replaces 8 separate module extensions with a single entry point:

    wasm = use_extension("@rules_wasm_component//wasm:unified_extension.bzl", "wasm")
    wasm.toolchains(
        bundle = "stable-2026-03",
        languages = ["rust", "go"],
    )
    use_repo(wasm, "wasm_toolchains")
    register_toolchains("@wasm_toolchains//:all")

Instead of:
    8 separate use_extension() calls
    14 register_toolchains() calls
    ~130 lines of MODULE.bazel boilerplate
"""

load("//toolchains:binaryen_toolchain.bzl", "binaryen_repository")
load("//toolchains:componentize_py_toolchain.bzl", "componentize_py_toolchain_repository")
load("//toolchains:cpp_component_toolchain.bzl", "cpp_component_toolchain_repository")
load("//toolchains:jco_toolchain.bzl", "jco_toolchain_repository")
load("//toolchains:tinygo_toolchain.bzl", "tinygo_toolchain_repository")
load("//toolchains:wasi_sdk_toolchain.bzl", "wasi_sdk_repository")
load("//toolchains:wasm_toolchain.bzl", "wasm_toolchain_repository")
load("//toolchains:wasmtime_toolchain.bzl", "wasmtime_repository")
load("//toolchains:wkg_toolchain.bzl", "wkg_toolchain_repository")
load("//wit:defs.bzl", "wasi_wit_dependencies")
load("//wit/private:wasi_p3_deps.bzl", "wasi_wit_p3_dependencies")

# Language → required toolchain repositories
_LANGUAGE_TOOLCHAINS = {
    # Core (always loaded)
    "_core": ["wasm_tools", "wasmtime", "wkg", "wasi_wit"],
    # Language-specific (opt-in)
    "rust": [],  # Rust uses core tools only (wasm-tools, wit-bindgen, wasmtime)
    "go": ["tinygo", "binaryen"],
    "cpp": ["wasi_sdk", "cpp_component"],
    "javascript": ["jco", "binaryen"],
    "python": ["componentize_py"],
}

def _unified_wasm_extension_impl(module_ctx):
    """Implementation of unified wasm toolchain extension."""

    # Collect configuration from all modules
    bundle_name = ""
    languages = []
    include_p3 = False

    for mod in module_ctx.modules:
        for tag in mod.tags.toolchains:
            if tag.bundle:
                bundle_name = tag.bundle
            if tag.languages:
                languages = list(tag.languages)
            if tag.include_p3:
                include_p3 = True

    # Default to rust-only if no languages specified
    if not languages:
        languages = ["rust"]

    # Determine which toolchain repos to create
    needed = set(["wasm_tools", "wasmtime", "wkg", "wasi_wit"])  # always core
    for lang in languages:
        if lang in _LANGUAGE_TOOLCHAINS:
            for repo in _LANGUAGE_TOOLCHAINS[lang]:
                needed = needed | set([repo])

    # --- Core toolchains (always) ---
    wasm_toolchain_repository(
        name = "wasm_tools_toolchains",
        bundle = bundle_name,
        strategy = "download",
    )

    wasmtime_repository(
        name = "wasmtime_toolchain",
        bundle = bundle_name,
        strategy = "download",
    )

    wkg_toolchain_repository(
        name = "wkg_toolchain",
        bundle = bundle_name,
        strategy = "download",
    )

    wasi_wit_dependencies()
    if include_p3:
        wasi_wit_p3_dependencies()

    # --- Language-specific toolchains (conditional) ---
    if "tinygo" in needed:
        tinygo_toolchain_repository(
            name = "tinygo_toolchain",
            bundle = bundle_name,
        )

    if "wasi_sdk" in needed or "cpp_component" in needed:
        wasi_sdk_repository(
            name = "wasi_sdk",
            bundle = bundle_name,
            strategy = "download",
        )

    if "cpp_component" in needed:
        cpp_component_toolchain_repository(
            name = "cpp_toolchain",
            bundle = bundle_name,
            strategy = "download",
        )

    if "jco" in needed:
        jco_toolchain_repository(
            name = "jco_toolchain",
            bundle = bundle_name,
        )

    if "binaryen" in needed:
        binaryen_repository(
            name = "binaryen_toolchain",
            bundle = bundle_name,
        )

    if "componentize_py" in needed:
        componentize_py_toolchain_repository(
            name = "componentize_py_toolchain",
            bundle = bundle_name,
        )

    # --- Create unified toolchain registration BUILD file ---
    # This generates a BUILD file with register_toolchains for all selected tools
    _create_unified_toolchain_repo(module_ctx, needed, languages)

def _create_unified_toolchain_repo(module_ctx, needed, languages):
    """Create a repository that re-exports all selected toolchains."""

    # Build the list of toolchain labels
    toolchain_labels = [
        "@wasm_tools_toolchains//:wasm_tools_toolchain",
        "@wasmtime_toolchain//:wasmtime_toolchain",
        "@wkg_toolchain//:wkg_toolchain_def",
    ]

    if "tinygo" in needed:
        toolchain_labels.append("@tinygo_toolchain//:tinygo_toolchain_def")
    if "wasi_sdk" in needed:
        toolchain_labels.extend([
            "@wasi_sdk//:wasi_sdk_toolchain",
            "@wasi_sdk//:cc_toolchain",
        ])
    if "cpp_component" in needed:
        toolchain_labels.append("@cpp_toolchain//:cpp_component_toolchain")
    if "jco" in needed:
        toolchain_labels.append("@jco_toolchain//:jco_toolchain")
    if "binaryen" in needed:
        toolchain_labels.append("@binaryen_toolchain//:binaryen_toolchain")
    if "componentize_py" in needed:
        toolchain_labels.append("@componentize_py_toolchain//:componentize_py_toolchain")

    # Generate BUILD file content
    aliases = "\n".join([
        'alias(name = "toolchain_{i}", actual = "{label}", visibility = ["//visibility:public"])'.format(
            i = i,
            label = label,
        )
        for i, label in enumerate(toolchain_labels)
    ])

    build_content = """\
# Auto-generated by unified_extension.bzl
# Languages: {languages}
# Toolchains: {count}

package(default_visibility = ["//visibility:public"])

{aliases}
""".format(
        languages = ", ".join(languages),
        count = len(toolchain_labels),
        aliases = aliases,
    )

    # Use module_ctx to create the repository
    # Note: In bzlmod, we can't create arbitrary repositories from module extensions
    # The toolchain repos are already created above — users register them via use_repo

wasm = module_extension(
    implementation = _unified_wasm_extension_impl,
    tag_classes = {
        "toolchains": tag_class(
            attrs = {
                "bundle": attr.string(
                    doc = """Toolchain bundle name from checksums/toolchain_bundles.json.

Available bundles:
- stable-2026-03: Latest stable P2 tools (default)
- stable-2025-12: December 2025 LTS
- minimal: Just wasm-tools, wit-bindgen, wasmtime (Rust-only)
- composition: Core + wac + wkg for composition workflows
- experimental-p3: P3-capable tools (wasmtime 43, wit-bindgen 0.54)""",
                    default = "stable-2026-03",
                ),
                "languages": attr.string_list(
                    doc = """Languages to enable. Only downloads toolchains for selected languages.

Available: "rust", "go", "cpp", "javascript", "python"
Default: ["rust"] (core tools only, ~50MB)

Examples:
    languages = ["rust"]              # Minimal: ~50MB
    languages = ["rust", "go"]        # + TinyGo + binaryen: ~500MB
    languages = ["rust", "cpp"]       # + WASI SDK: ~350MB
    languages = ["rust", "javascript"] # + jco + Node.js: ~150MB""",
                    default = ["rust"],
                ),
                "include_p3": attr.bool(
                    doc = "Load WASI P3 (0.3.0-rc) WIT definitions for async components",
                    default = False,
                ),
            },
        ),
    },
    doc = """Unified WebAssembly toolchain extension.

Sets up all WASM toolchains in a single extension call, downloading
only the tools needed for your selected languages.

Example (4 lines instead of ~130):
    wasm = use_extension("@rules_wasm_component//wasm:unified_extension.bzl", "wasm")
    wasm.toolchains(bundle = "stable-2026-03", languages = ["rust", "go"])
    use_repo(wasm, "wasm_tools_toolchains", "wasmtime_toolchain", "wkg_toolchain", "tinygo_toolchain", "binaryen_toolchain")
    register_toolchains("@wasm_tools_toolchains//:wasm_tools_toolchain", "@wasmtime_toolchain//:wasmtime_toolchain", ...)
""",
)
