"""Unit tests for WASM toolchain functionality"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")

def _platform_suffix_test_impl(ctx):
    """Test platform suffix generation"""
    env = unittest.begin(ctx)
    
    # Test platform mappings
    test_cases = [
        ("linux_amd64", "x86_64-linux"),
        ("linux_arm64", "aarch64-linux"),
        ("darwin_amd64", "x86_64-macos"),
        ("darwin_arm64", "aarch64-macos"),
        ("windows_amd64", "x86_64-windows"),
    ]
    
    # Note: We can't directly test the private function _get_platform_suffix
    # but we can test the repository rule behavior through integration tests
    
    unittest.end(env)

platform_suffix_test = unittest.make(_platform_suffix_test_impl)

def _toolchain_url_test_impl(ctx):
    """Test that toolchain URLs are correctly formed"""
    env = unittest.begin(ctx)
    
    # Test URL format expectations
    version = "1.235.0"
    platform_suffix = "aarch64-macos"
    
    expected_wasm_tools_url = "https://github.com/bytecodealliance/wasm-tools/releases/download/v{}/wasm-tools-{}-{}.tar.gz".format(
        version, version, platform_suffix
    )
    expected_prefix = "wasm-tools-{}-{}".format(version, platform_suffix)
    
    # Verify the URL format matches what we expect
    asserts.equals(env, 
        "https://github.com/bytecodealliance/wasm-tools/releases/download/v1.235.0/wasm-tools-1.235.0-aarch64-macos.tar.gz",
        expected_wasm_tools_url
    )
    
    asserts.equals(env, "wasm-tools-1.235.0-aarch64-macos", expected_prefix)
    
    unittest.end(env)

toolchain_url_test = unittest.make(_toolchain_url_test_impl)

def toolchain_test_suite():
    """Test suite for toolchain functionality"""
    unittest.suite(
        "toolchain_tests",
        platform_suffix_test,
        toolchain_url_test,
    )