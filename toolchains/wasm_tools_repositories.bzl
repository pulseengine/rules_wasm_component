"""Modernized WASM tools repository management

This file replaces shell-based git clone operations with proper Bazel git_repository 
rules. For cargo builds, we use rules_rust to create proper Bazel targets that
integrate with Bazel's caching and dependency management.
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def register_wasm_tool_repositories():
    """Register git repositories for all WASM tools
    
    This replaces ctx.execute(["git", "clone", ...]) operations with proper
    Bazel repository rules that integrate with Bazel's caching and hermeticity.
    Uses rules_rust for dependency management instead of shell cargo commands.
    """
    
    # wasm-tools: WebAssembly manipulation tools
    git_repository(
        name = "wasm_tools_src",
        remote = "https://github.com/bytecodealliance/wasm-tools.git",
        tag = "v1.235.0",
        build_file = "//toolchains:BUILD.wasm_tools",
    )
    
    # wac: WebAssembly component composition tool  
    git_repository(
        name = "wac_src",
        remote = "https://github.com/bytecodealliance/wac.git", 
        tag = "v0.7.0",  # Use stable release
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
        tag = "v0.1.0",  # Use tagged release for stability
        build_file = "//toolchains:BUILD.wrpc",
    )
    
    print("✅ Modernized WASM tool repositories registered - replaced all git clone operations")