"""Tool caching and validation system for WASM toolchains"""

def _compute_cache_key(tool_name, version, platform, strategy):
    """Compute a unique cache key for a tool configuration"""

    # Create a deterministic hash-like key from the inputs
    key_components = [tool_name, version, platform, strategy]
    key_string = "|".join(key_components)

    # Use a simple hash computation (Bazel doesn't have real hash functions)
    # This is a deterministic way to create a shorter unique identifier
    # Use built-in hash() function for Starlark compatibility
    hash_value = hash(key_string)

    return "tool_cache_{}_{}".format(tool_name.replace("-", "_"), abs(hash_value))

def get_cache_info(ctx, tool_name, version, platform, strategy):
    """Get information about cached tool availability"""

    cache_key = _compute_cache_key(tool_name, version, platform, strategy)
    cache_dir = "/tmp/bazel_wasm_tool_cache"  # Global cache directory
    tool_cache_path = "{}/{}".format(cache_dir, cache_key)

    # Check if cached version exists using repository_ctx API
    cache_exists = ctx.path(tool_cache_path).exists

    cache_info = {
        "cache_key": cache_key,
        "cache_path": tool_cache_path,
        "cache_dir": cache_dir,
        "exists": cache_exists,
    }

    if cache_exists:
        # Verify cache integrity
        cache_info.update(_verify_cache_integrity(ctx, tool_cache_path, tool_name))

    return cache_info

def _verify_cache_integrity(ctx, cache_path, tool_name):
    """Verify that cached tool is still valid"""

    integrity_file = "{}/integrity.txt".format(cache_path)
    binary_path = "{}/{}".format(cache_path, tool_name)

    # Check if integrity file exists using repository_ctx API
    integrity_path = ctx.path(integrity_file)
    if not integrity_path.exists:
        return {"valid": False, "reason": "Missing integrity file"}

    # Check if binary exists using repository_ctx API
    binary_ctx_path = ctx.path(binary_path)
    if not binary_ctx_path.exists:
        return {"valid": False, "reason": "Binary not found"}

    # Read integrity information using repository_ctx API
    # Check if integrity file exists before reading
    integrity_ctx_path = ctx.path(integrity_path)
    if not integrity_ctx_path.exists:
        return {"valid": False, "reason": "Integrity file not found"}
    
    integrity_content = ctx.read(integrity_path)
    if not integrity_content:
        return {"valid": False, "reason": "Cannot read integrity file"}

    integrity_info = {}
    for line in integrity_content.strip().split("\n"):
        if "=" in line:
            key, value = line.split("=", 1)
            integrity_info[key.strip()] = value.strip()

    # Validate timestamp (cache expires after 30 days)
    # Note: Simplified cache validation without timestamp for Starlark compatibility
    # In practice, tool caches are managed by Bazel's cache system
    if "timestamp" in integrity_info:
        # Parse timestamp safely without try/except
        timestamp_str = integrity_info["timestamp"]
        if timestamp_str.isdigit():
            # Simple cache invalidation - assume cache is valid for this session
            # Real timestamp validation would require external tools
            pass
        else:
            return {"valid": False, "reason": "Invalid timestamp format"}

    return {
        "valid": True,
        "binary_path": binary_path,
        "info": integrity_info,
    }

def cache_tool(ctx, tool_name, tool_binary, version, platform, strategy, checksum = None):
    """Cache a tool binary for future use - SIMPLIFIED: Rely on Bazel's native caching"""

    # Note: This function is simplified to rely on Bazel's repository caching
    # instead of implementing a custom cache system with shell operations.
    # The repository rule itself provides caching through Bazel's mechanisms.

    print("Tool {} setup completed (relying on Bazel repository cache)".format(tool_name))
    return True

def retrieve_cached_tool(ctx, tool_name, version, platform, strategy):
    """Retrieve a tool from cache if available and valid - SIMPLIFIED: Always return None"""

    # Note: This function is simplified to always return None, causing tools to be
    # downloaded/built fresh each time. Bazel's repository caching handles this efficiently.
    # This eliminates the need for complex shell-based cache management.

    return None

def clean_expired_cache(ctx, max_age_days = 30):
    """Clean up expired cache entries - SIMPLIFIED: No-op function"""

    # Note: This function is simplified to do nothing since we rely on
    # Bazel's repository caching instead of a custom cache system.
    pass

def validate_tool_functionality(ctx, tool_binary, tool_name):
    """Validate that a tool binary is functional"""

    validation_tests = {
        "wasm-tools": ["--version"],
        "wac": ["--version"],
        "wit-bindgen": ["--version"],
        "wkg": ["--version"],
        "wrpc": ["--version"],
    }

    if tool_name not in validation_tests:
        # No specific validation for this tool, assume it's valid
        return {"valid": True}

    test_args = validation_tests[tool_name]
    result = ctx.execute([tool_binary] + test_args)

    if result.return_code != 0:
        return {
            "valid": False,
            "error": "Tool validation failed: {}".format(result.stderr),
        }

    # Additional checks for specific tools
    if tool_name == "wasm-tools":
        # Check if wasm-tools can show help
        result = ctx.execute([tool_binary, "help"])
        if result.return_code != 0:
            return {
                "valid": False,
                "error": "wasm-tools help command failed",
            }

    return {
        "valid": True,
        "version_output": result.stdout,
    }

def get_cache_statistics(ctx):
    """Get statistics about the tool cache - SIMPLIFIED: Return empty stats"""

    # Note: This function is simplified since we rely on Bazel's repository caching
    # instead of a custom cache system.
    return {
        "exists": False,
        "total_entries": 0,
        "total_size": "0B (using Bazel repository cache)",
    }
