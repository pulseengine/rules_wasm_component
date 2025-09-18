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
    checksum = get_tool_checksum("wasm-tools", "1.235.0", "darwin_amd64")
    asserts.equals(env, "154e9ea5f5477aa57466cfb10e44bc62ef537e32bf13d1c35ceb4fedd9921510", checksum)

    # Test wizer checksum (our new addition)
    wizer_checksum = get_tool_checksum("wizer", "9.0.0", "linux_amd64")
    asserts.equals(env, "d1d85703bc40f18535e673992bef723dc3f84e074bcd1e05b57f24d5adb4f058", wizer_checksum)

    # Test invalid tool
    invalid_checksum = get_tool_checksum("nonexistent-tool", "1.0.0", "linux_amd64")
    asserts.equals(env, None, invalid_checksum)

    # Test invalid version
    invalid_version = get_tool_checksum("wasm-tools", "999.0.0", "linux_amd64")
    asserts.equals(env, None, invalid_version)

    # Test invalid platform
    invalid_platform = get_tool_checksum("wasm-tools", "1.235.0", "invalid_platform")
    asserts.equals(env, None, invalid_platform)

    return unittest.end(env)

def _test_get_tool_info(ctx):
    """Test get_tool_info function"""
    env = unittest.begin(ctx)

    # Test valid tool info
    info = get_tool_info("wasm-tools", "1.235.0", "darwin_amd64")
    asserts.true(env, info != None)
    asserts.equals(env, "154e9ea5f5477aa57466cfb10e44bc62ef537e32bf13d1c35ceb4fedd9921510", info["sha256"])
    asserts.equals(env, "x86_64-macos.tar.gz", info["url_suffix"])

    # Test wizer info
    wizer_info = get_tool_info("wizer", "9.0.0", "windows_amd64")
    asserts.true(env, wizer_info != None)
    asserts.equals(env, "d9cc5ed028ca873f40adcac513812970d34dd08cec4397ffc5a47d4acee8e782", wizer_info["sha256"])
    asserts.equals(env, "x86_64-windows.zip", wizer_info["url_suffix"])

    return unittest.end(env)

def _test_get_latest_version(ctx):
    """Test get_latest_version function"""
    env = unittest.begin(ctx)

    # Test known tools
    asserts.equals(env, "1.239.0", get_latest_version("wasm-tools"))
    asserts.equals(env, "0.46.0", get_latest_version("wit-bindgen"))
    asserts.equals(env, "9.0.0", get_latest_version("wizer"))

    # Test invalid tool
    asserts.equals(env, None, get_latest_version("nonexistent-tool"))

    return unittest.end(env)

def _test_list_supported_platforms(ctx):
    """Test list_supported_platforms function"""
    env = unittest.begin(ctx)

    # Test wasm-tools platforms
    platforms = list_supported_platforms("wasm-tools", "1.235.0")
    asserts.true(env, "darwin_amd64" in platforms)
    asserts.true(env, "linux_amd64" in platforms)
    asserts.true(env, "windows_amd64" in platforms)

    # Test wizer platforms
    wizer_platforms = list_supported_platforms("wizer", "9.0.0")
    asserts.true(env, "darwin_amd64" in wizer_platforms)
    asserts.true(env, "linux_amd64" in wizer_platforms)
    asserts.true(env, "windows_amd64" in wizer_platforms)
    asserts.equals(env, 5, len(wizer_platforms))  # Should have 5 platforms

    return unittest.end(env)

def _test_get_github_repo(ctx):
    """Test get_github_repo function"""
    env = unittest.begin(ctx)

    # Test known repos
    asserts.equals(env, "bytecodealliance/wasm-tools", get_github_repo("wasm-tools"))
    asserts.equals(env, "bytecodealliance/wit-bindgen", get_github_repo("wit-bindgen"))
    asserts.equals(env, "bytecodealliance/wizer", get_github_repo("wizer"))

    # Test invalid tool
    asserts.equals(env, None, get_github_repo("nonexistent-tool"))

    return unittest.end(env)

def _test_validate_tool_exists(ctx):
    """Test validate_tool_exists function"""
    env = unittest.begin(ctx)

    # Test valid combinations
    asserts.true(env, validate_tool_exists("wasm-tools", "1.235.0", "darwin_amd64"))
    asserts.true(env, validate_tool_exists("wizer", "9.0.0", "linux_amd64"))

    # Test invalid combinations
    asserts.false(env, validate_tool_exists("nonexistent-tool", "1.0.0", "linux_amd64"))
    asserts.false(env, validate_tool_exists("wasm-tools", "999.0.0", "linux_amd64"))
    asserts.false(env, validate_tool_exists("wasm-tools", "1.235.0", "invalid_platform"))

    return unittest.end(env)

def _test_list_available_tools(ctx):
    """Test list_available_tools function"""
    env = unittest.begin(ctx)

    tools = list_available_tools()
    asserts.true(env, "wasm-tools" in tools)
    asserts.true(env, "wit-bindgen" in tools)
    asserts.true(env, "wizer" in tools)
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
