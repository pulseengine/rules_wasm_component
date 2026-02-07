"""Unit tests for the checksum registry API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//checksums:registry.bzl",
    "get_github_repo",
    "get_latest_version",
    "get_tool_checksum",
    "get_tool_info",
    "list_available_tools",
    "list_supported_platforms",
    "validate_tool_exists",
)

def _test_get_tool_checksum(ctx):
    """Test get_tool_checksum function"""
    env = unittest.begin(ctx)

    # Test valid tool/version/platform
    checksum = get_tool_checksum("wasm-tools", "1.243.0", "darwin_amd64")
    asserts.equals(env, "3d03bc02fed63998e0ee8d88eb86d90bdb8e32e7cadc77d2f9e792b9dff8433a", checksum)

    # Test wasmtime checksum (wizer functionality now included in wasmtime v39.0.0+)
    wasmtime_checksum = get_tool_checksum("wasmtime", "39.0.1", "linux_amd64")
    asserts.equals(env, "b90a36125387b75db59a67a1c402f2ed9d120fa43670d218a559571e2423d925", wasmtime_checksum)

    # Test invalid tool
    invalid_checksum = get_tool_checksum("nonexistent-tool", "1.0.0", "linux_amd64")
    asserts.equals(env, None, invalid_checksum)

    # Test invalid version
    invalid_version = get_tool_checksum("wasm-tools", "999.0.0", "linux_amd64")
    asserts.equals(env, None, invalid_version)

    # Test invalid platform
    invalid_platform = get_tool_checksum("wasm-tools", "1.243.0", "invalid_platform")
    asserts.equals(env, None, invalid_platform)

    return unittest.end(env)

def _test_get_tool_info(ctx):
    """Test get_tool_info function"""
    env = unittest.begin(ctx)

    # Test valid tool info
    info = get_tool_info("wasm-tools", "1.243.0", "darwin_amd64")
    asserts.true(env, info != None)
    asserts.equals(env, "3d03bc02fed63998e0ee8d88eb86d90bdb8e32e7cadc77d2f9e792b9dff8433a", info["sha256"])
    asserts.equals(env, "x86_64-macos.tar.gz", info["url_suffix"])

    # Test wasmtime info (wizer functionality now included in wasmtime v39.0.0+)
    wasmtime_info = get_tool_info("wasmtime", "39.0.1", "windows_amd64")
    asserts.true(env, wasmtime_info != None)
    asserts.equals(env, "bccf64b4227d178c0d13f2856be68876eae3f2f657f3a85d46f076a5e1976198", wasmtime_info["sha256"])
    asserts.equals(env, "x86_64-windows.zip", wasmtime_info["url_suffix"])

    return unittest.end(env)

def _test_get_latest_version(ctx):
    """Test get_latest_version function"""
    env = unittest.begin(ctx)

    # Test known tools (core toolchain)
    asserts.equals(env, "1.244.0", get_latest_version("wasm-tools"))
    asserts.equals(env, "0.49.0", get_latest_version("wit-bindgen"))

    # Test invalid tool
    asserts.equals(env, None, get_latest_version("nonexistent-tool"))

    return unittest.end(env)

def _test_list_supported_platforms(ctx):
    """Test list_supported_platforms function"""
    env = unittest.begin(ctx)

    # Test wasm-tools platforms
    platforms = list_supported_platforms("wasm-tools", "1.243.0")
    asserts.true(env, "darwin_amd64" in platforms)
    asserts.true(env, "linux_amd64" in platforms)
    asserts.true(env, "windows_amd64" in platforms)

    # Test wasmtime platforms (wizer functionality now included in wasmtime v39.0.0+)
    wasmtime_platforms = list_supported_platforms("wasmtime", "39.0.1")
    asserts.true(env, "darwin_amd64" in wasmtime_platforms)
    asserts.true(env, "linux_amd64" in wasmtime_platforms)
    asserts.true(env, "windows_amd64" in wasmtime_platforms)
    asserts.equals(env, 5, len(wasmtime_platforms))  # Should have 5 platforms

    return unittest.end(env)

def _test_get_github_repo(ctx):
    """Test get_github_repo function"""
    env = unittest.begin(ctx)

    # Test known repos
    asserts.equals(env, "bytecodealliance/wasm-tools", get_github_repo("wasm-tools"))
    asserts.equals(env, "bytecodealliance/wit-bindgen", get_github_repo("wit-bindgen"))
    asserts.equals(env, "bytecodealliance/wasmtime", get_github_repo("wasmtime"))

    # Test invalid tool
    asserts.equals(env, None, get_github_repo("nonexistent-tool"))

    return unittest.end(env)

def _test_validate_tool_exists(ctx):
    """Test validate_tool_exists function"""
    env = unittest.begin(ctx)

    # Test valid combinations
    asserts.true(env, validate_tool_exists("wasm-tools", "1.243.0", "darwin_amd64"))
    asserts.true(env, validate_tool_exists("wasmtime", "39.0.1", "linux_amd64"))

    # Test invalid combinations
    asserts.false(env, validate_tool_exists("nonexistent-tool", "1.0.0", "linux_amd64"))
    asserts.false(env, validate_tool_exists("wasm-tools", "999.0.0", "linux_amd64"))
    asserts.false(env, validate_tool_exists("wasm-tools", "1.243.0", "invalid_platform"))

    return unittest.end(env)

def _test_list_available_tools(ctx):
    """Test list_available_tools function"""
    env = unittest.begin(ctx)

    tools = list_available_tools()
    asserts.true(env, "wasm-tools" in tools)
    asserts.true(env, "wit-bindgen" in tools)
    asserts.true(env, "wasmtime" in tools)  # wizer functionality now in wasmtime
    asserts.true(env, "wac" in tools)
    asserts.true(env, "wkg" in tools)

    return unittest.end(env)

# Define test rules
get_tool_checksum_test = unittest.make(_test_get_tool_checksum)
get_tool_info_test = unittest.make(_test_get_tool_info)
get_latest_version_test = unittest.make(_test_get_latest_version)
list_supported_platforms_test = unittest.make(_test_list_supported_platforms)
get_github_repo_test = unittest.make(_test_get_github_repo)
validate_tool_exists_test = unittest.make(_test_validate_tool_exists)
list_available_tools_test = unittest.make(_test_list_available_tools)

def registry_test_suite(name):
    """Test suite for registry API"""
    unittest.suite(
        name,
        get_tool_checksum_test,
        get_tool_info_test,
        get_latest_version_test,
        list_supported_platforms_test,
        get_github_repo_test,
        validate_tool_exists_test,
        list_available_tools_test,
    )
