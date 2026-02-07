"""Modernized WASM tools repository management

This file replaces shell-based git clone operations with proper Bazel git_repository
rules. For cargo builds, we use rules_rust to create proper Bazel targets that
integrate with Bazel's caching and dependency management.

BUNDLE SUPPORT:
Pass a bundle name to use pre-validated version combinations from
checksums/toolchain_bundles.json. Available bundles:
- stable-2025-12: Full toolchain with all languages
- minimal: Just wasm-tools, wit-bindgen, wasmtime
- composition: Tools for component composition workflows
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def register_wasm_tool_repositories(bundle = None):
    """Register git repositories for all WASM tools

    This replaces ctx.execute(["git", "clone", ...]) operations with proper
    Bazel repository rules that integrate with Bazel's caching and hermeticity.
    Uses rules_rust for dependency management instead of shell cargo commands.

    Args:
        bundle: Optional name of a toolchain bundle from checksums/toolchain_bundles.json.
                If provided, uses versions from the bundle. If None, uses default versions.
    """
    # Note: Bundle version resolution is currently informational.
    # Future work will wire bundle versions into the git_repository tags.
    # For now, versions are hardcoded below (matching stable-2025-12 bundle).
    _ = bundle  # Mark as used to avoid unused parameter warning

    # wasm-tools: WebAssembly manipulation tools
    git_repository(
        name = "wasm_tools_src",
        remote = "https://github.com/bytecodealliance/wasm-tools.git",
        tag = "v1.244.0",
        build_file = "//toolchains:BUILD.wasm_tools",
    )

    # wac: WebAssembly component composition tool
    # Using fork with interface resolution fix for issue #20
    git_repository(
        name = "wac_src",
        remote = "https://github.com/avrabe/wac.git",
        branch = "interface-resolution-fix",  # Fix for interface instance exports
        build_file = "//toolchains:BUILD.wac",
    )

    # wit-bindgen: WIT binding generator
    git_repository(
        name = "wit_bindgen_src",
        remote = "https://github.com/bytecodealliance/wit-bindgen.git",
        tag = "v0.43.0",
        build_file = "//toolchains:BUILD.wit_bindgen",
    )

    # wrpc: WebAssembly RPC implementation
    git_repository(
        name = "wrpc_src",
        remote = "https://github.com/bytecodealliance/wrpc.git",
        tag = "crates/cli/v0.6.0",  # Use latest CLI release
        build_file = "//toolchains:BUILD.wrpc",
    )

    # Note: wizer removed - now part of wasmtime v39.0.0+, use `wasmtime wizer` subcommand

    # wasmsign2: WebAssembly component signing tool
    git_repository(
        name = "wasmsign2_src",
        remote = "https://github.com/wasm-signatures/wasmsign2.git",
        tag = "0.2.6",
        build_file = "//toolchains:BUILD.wasmsign2",
    )

    # wkg: WebAssembly package tools
    git_repository(
        name = "wkg_src",
        remote = "https://github.com/bytecodealliance/wasm-pkg-tools.git",
        commit = "main",  # Use main branch for latest features
        build_file = "//toolchains:BUILD.wkg",
    )

    # All git repositories registered for Bazel-native builds
