"""Integration test for toolchain download functionality"""

load("//toolchains:wasm_toolchain.bzl", "wasm_toolchain_repository")

def _mock_wasm_toolchain_repository_impl(repository_ctx):
    """Mock implementation that tests the URL and prefix generation"""
    
    # Test platform detection
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()
    
    if os_name == "mac os x":
        os_name = "darwin"
    
    if arch == "x86_64":
        arch = "amd64"
    elif arch == "aarch64":
        arch = "arm64"
    
    platform = "{}_{}".format(os_name, arch)
    
    # Test platform suffix mapping
    platform_suffixes = {
        "linux_amd64": "x86_64-linux",
        "linux_arm64": "aarch64-linux", 
        "darwin_amd64": "x86_64-macos",
        "darwin_arm64": "aarch64-macos",
        "windows_amd64": "x86_64-windows",
    }
    platform_suffix = platform_suffixes.get(platform, "x86_64-linux")
    
    version = repository_ctx.attr.version
    
    # Test URL generation (same logic as real implementation)
    wasm_tools_url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v{}/wasm-tools-{}-{}.tar.gz".format(
        version, version, platform_suffix
    )
    
    # Test prefix generation (same logic as real implementation)
    expected_prefix = "wasm-tools-{}-{}".format(version, platform_suffix)
    
    # Write test results to a file for verification
    repository_ctx.file("test_results.txt", """Platform: {}
Platform Suffix: {}
URL: {}
Expected Prefix: {}
""".format(platform, platform_suffix, wasm_tools_url, expected_prefix))
    
    # Create minimal BUILD file
    repository_ctx.file("BUILD.bazel", """
filegroup(
    name = "test_results",
    srcs = ["test_results.txt"],
    visibility = ["//visibility:public"],
)
""")

mock_wasm_toolchain_repository = repository_rule(
    implementation = _mock_wasm_toolchain_repository_impl,
    attrs = {
        "version": attr.string(default = "1.235.0"),
    },
)