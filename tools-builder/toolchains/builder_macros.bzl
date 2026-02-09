"""Macros for building WebAssembly tools across multiple platforms"""

load("@rules_rust//rust:defs.bzl", "rust_binary")
load("//tools-builder/platforms:defs.bzl", "PLATFORM_MAPPINGS")

def wasm_tool_suite(name, platforms, tools):
    """Build a suite of WebAssembly tools for multiple platforms

    Args:
        name: Name of the target group
        platforms: List of platform targets to build for
        tools: List of tool names to build
    """

    all_targets = []

    for tool in tools:
        for platform in platforms:
            platform_info = PLATFORM_MAPPINGS[platform]
            target_name = "{}_{}_{}_{}".format(
                name,
                tool.replace("-", "_"),
                platform_info["os"],
                platform_info["arch"],
            )

            if tool == "wasm-tools":
                _build_wasm_tools(
                    name = target_name,
                    platform = platform,
                    rust_target = platform_info["rust_target"],
                    suffix = platform_info["suffix"],
                )
            elif tool == "wit-bindgen":
                _build_wit_bindgen(
                    name = target_name,
                    platform = platform,
                    rust_target = platform_info["rust_target"],
                    suffix = platform_info["suffix"],
                )
                # Note: wizer removed - now part of wasmtime v39.0.0+

            elif tool == "wac":
                _build_wac(
                    name = target_name,
                    platform = platform,
                    rust_target = platform_info["rust_target"],
                    suffix = platform_info["suffix"],
                )
            elif tool == "wasmtime":
                _build_wasmtime(
                    name = target_name,
                    platform = platform,
                    rust_target = platform_info["rust_target"],
                    suffix = platform_info["suffix"],
                )

            all_targets.append(target_name)

    # Create filegroup collecting all built targets
    native.filegroup(
        name = name,
        srcs = all_targets,
    )

def _build_wasm_tools(name, platform, rust_target, suffix):
    """Build wasm-tools for a specific platform"""
    rust_binary(
        name = name,
        srcs = ["@wasm_tools_src//:src/main.rs"],
        deps = ["@wasm_tools_src//:wasm_tools_lib"],
        platform = platform,
        crate_name = "wasm_tools",
        edition = "2021",
    )

def _build_wit_bindgen(name, platform, rust_target, suffix):
    """Build wit-bindgen for a specific platform"""
    rust_binary(
        name = name,
        srcs = ["@wit_bindgen_src//:crates/wit-bindgen-cli/src/main.rs"],
        deps = ["@wit_bindgen_src//:wit_bindgen_cli_lib"],
        platform = platform,
        crate_name = "wit_bindgen",
        edition = "2021",
    )

def _build_wac(name, platform, rust_target, suffix):
    """Build wac for a specific platform"""
    rust_binary(
        name = name,
        srcs = ["@wac_src//:src/main.rs"],
        deps = ["@wac_src//:wac_lib"],
        platform = platform,
        crate_name = "wac",
        edition = "2021",
    )

def _build_wasmtime(name, platform, rust_target, suffix):
    """Build wasmtime for a specific platform"""
    rust_binary(
        name = name,
        srcs = ["@wasmtime_src//:src/main.rs"],
        deps = ["@wasmtime_src//:wasmtime_lib"],
        platform = platform,
        crate_name = "wasmtime",
        edition = "2021",
    )
