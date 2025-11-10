"""Template for adding all Stardoc documentation targets.

Copy these targets into docs/BUILD.bazel to enable documentation generation.
Adjust deps as needed based on external dependencies.
"""

# Add to docs/BUILD.bazel:
# load("@stardoc//stardoc:stardoc.bzl", "stardoc")

# Phase 1: Core Language Rules (HIGH PRIORITY)

# C++ Component Rules
stardoc(
    name = "cpp_component_stardoc",
    input = "//cpp:defs.bzl",
    out = "api/cpp_component.md",
    deps = [
        "//cpp:defs",
        # Add external deps if needed (e.g., @rules_cc)
    ],
)

# Go Component Rules
stardoc(
    name = "go_component_stardoc",
    input = "//go:defs.bzl",
    out = "api/go_component.md",
    deps = [
        "//go:defs",
        # Note: May need @rules_go//go:bzl_lib or similar
    ],
)

# JavaScript Component Rules
stardoc(
    name = "js_component_stardoc",
    input = "//js:defs.bzl",
    out = "api/js_component.md",
    deps = [
        "//js:defs",
        # Note: May need @rules_nodejs deps
    ],
)

# WIT Interface Rules
stardoc(
    name = "wit_library_stardoc",
    input = "//wit:defs.bzl",
    out = "api/wit_library.md",
    deps = ["//wit:defs"],
)

# WIT Bindgen (Advanced)
stardoc(
    name = "wit_bindgen_stardoc",
    input = "//wit:wit_bindgen.bzl",
    out = "api/wit_bindgen.md",
    deps = ["//wit:wit_bindgen"],
)

# Symmetric WIT Bindgen (Advanced)
stardoc(
    name = "symmetric_wit_bindgen_stardoc",
    input = "//wit:symmetric_wit_bindgen.bzl",
    out = "api/symmetric_wit_bindgen.md",
    deps = ["//wit:symmetric_wit_bindgen"],
)

# Phase 2: Composition and Packaging

# WAC Composition
stardoc(
    name = "wac_compose_stardoc",
    input = "//wac:defs.bzl",
    out = "api/wac_compose.md",
    deps = ["//wac:defs"],
)

# WAC Plug Pattern
stardoc(
    name = "wac_plug_stardoc",
    input = "//wac:wac_plug.bzl",
    out = "api/wac_plug.md",
    deps = ["//wac:wac_plug"],
)

# WKG Packaging
stardoc(
    name = "wkg_package_stardoc",
    input = "//wkg:defs.bzl",
    out = "api/wkg_package.md",
    deps = ["//wkg:defs"],
)

# Phase 3: WASM Operations

# WASM Operations (Main)
stardoc(
    name = "wasm_operations_stardoc",
    input = "//wasm:defs.bzl",
    out = "api/wasm_operations.md",
    deps = ["//wasm:defs"],
)

# WASM Precompilation (AOT)
stardoc(
    name = "wasm_precompile_stardoc",
    input = "//wasm:wasm_precompile.bzl",
    out = "api/wasm_precompile.md",
    deps = ["//wasm:wasm_precompile"],
)

# WASM Validation
stardoc(
    name = "wasm_validate_stardoc",
    input = "//wasm:wasm_validate.bzl",
    out = "api/wasm_validate.md",
    deps = ["//wasm:wasm_validate"],
)

# WASM Signing
stardoc(
    name = "wasm_signing_stardoc",
    input = "//wasm:wasm_signing.bzl",
    out = "api/wasm_signing.md",
    deps = ["//wasm:wasm_signing"],
)

# Wizer Pre-initialization (Advanced)
stardoc(
    name = "wasm_wizer_stardoc",
    input = "//wasm:wasm_component_wizer.bzl",
    out = "api/wasm_wizer.md",
    deps = ["//wasm:wasm_component_wizer"],
)

# Phase 4: Supporting Infrastructure

# Providers
stardoc(
    name = "providers_stardoc",
    input = "//providers:providers.bzl",
    out = "api/providers.md",
    deps = ["//providers:providers"],
)

# Common Utilities
stardoc(
    name = "common_stardoc",
    input = "//common:common.bzl",
    out = "api/common.md",
    deps = ["//common:common"],
)

# Convenience target: Build all API documentation
filegroup(
    name = "all_api_docs",
    srcs = [
        ":cpp_component_stardoc",
        ":go_component_stardoc",
        ":js_component_stardoc",
        ":wit_library_stardoc",
        ":wit_bindgen_stardoc",
        ":symmetric_wit_bindgen_stardoc",
        ":wac_compose_stardoc",
        ":wac_plug_stardoc",
        ":wkg_package_stardoc",
        ":wasm_operations_stardoc",
        ":wasm_precompile_stardoc",
        ":wasm_validate_stardoc",
        ":wasm_signing_stardoc",
        ":wasm_wizer_stardoc",
        ":providers_stardoc",
        ":common_stardoc",
    ],
)

# Usage:
# bazel build //docs:all_api_docs        # Build everything
# bazel build //docs:cpp_component_stardoc  # Build one
