"""WebAssembly toolchain definitions"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

WASM_TOOLS_PLATFORMS = {
    "darwin_amd64": struct(
        sha256 = "1234567890abcdef",  # TODO: Add real checksums
        url_suffix = "x86_64-macos.tar.gz",
    ),
    "darwin_arm64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "aarch64-macos.tar.gz", 
    ),
    "linux_amd64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "x86_64-linux.tar.gz",
    ),
    "linux_arm64": struct(
        sha256 = "1234567890abcdef", 
        url_suffix = "aarch64-linux.tar.gz",
    ),
    "windows_amd64": struct(
        sha256 = "1234567890abcdef",
        url_suffix = "x86_64-windows.tar.gz",
    ),
}

def _wasm_tools_toolchain_impl(ctx):
    """Implementation of wasm_tools_toolchain rule"""
    
    # Create toolchain info
    toolchain_info = platform_common.ToolchainInfo(
        wasm_tools = ctx.file.wasm_tools,
        wac = ctx.file.wac,
        wit_bindgen = ctx.file.wit_bindgen,
    )
    
    return [toolchain_info]

wasm_tools_toolchain = rule(
    implementation = _wasm_tools_toolchain_impl,
    attrs = {
        "wasm_tools": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wasm-tools binary",
        ),
        "wac": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wac (WebAssembly Composition) binary",
        ),
        "wit_bindgen": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "wit-bindgen binary",
        ),
    },
    doc = "Declares a WebAssembly toolchain",
)

def _detect_host_platform(repository_ctx):
    """Detect the host platform"""
    
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()
    
    if os_name == "mac os x":
        os_name = "darwin"
    
    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"
    
    return "{}_{}".format(os_name, arch)

def _wasm_toolchain_repository_impl(repository_ctx):
    """Create toolchain repository with downloaded tools"""
    
    platform = _detect_host_platform(repository_ctx)
    platform_info = WASM_TOOLS_PLATFORMS.get(platform)
    
    if not platform_info:
        fail("Unsupported platform: {}".format(platform))
    
    version = repository_ctx.attr.wasm_tools_version
    
    # Download wasm-tools
    repository_ctx.download_and_extract(
        url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v{}/wasm-tools-{}-{}".format(
            version,
            version,
            platform_info.url_suffix,
        ),
        sha256 = platform_info.sha256,
    )
    
    # Create BUILD file
    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:wasm_toolchain.bzl", "wasm_tools_toolchain")

package(default_visibility = ["//visibility:public"])

wasm_tools_toolchain(
    name = "wasm_tools_impl",
    wasm_tools = "@{name}//:wasm-tools",
    wac = "@{name}//:wac", 
    wit_bindgen = "@{name}//:wit-bindgen",
)

toolchain(
    name = "wasm_tools_toolchain",
    toolchain = ":wasm_tools_impl",
    toolchain_type = "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
    exec_compatible_with = [
        # TODO: Add platform constraints
    ],
    target_compatible_with = [
        "@platforms//cpu:wasm32",
    ],
)
""".format(name = repository_ctx.name))

wasm_toolchain_repository = repository_rule(
    implementation = _wasm_toolchain_repository_impl,
    attrs = {
        "wasm_tools_version": attr.string(
            doc = "Version of wasm-tools to download",
            default = "1.0.60",
        ),
    },
)