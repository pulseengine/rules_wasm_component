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
    
    # Check if cached version exists
    result = ctx.execute(["test", "-d", tool_cache_path])
    cache_exists = result.return_code == 0
    
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
    
    # Check if integrity file exists
    result = ctx.execute(["test", "-f", integrity_file])
    if result.return_code != 0:
        return {"valid": False, "reason": "Missing integrity file"}
    
    # Check if binary exists and is executable
    result = ctx.execute(["test", "-x", binary_path])
    if result.return_code != 0:
        return {"valid": False, "reason": "Binary not found or not executable"}
    
    # Read integrity information
    result = ctx.execute(["cat", integrity_file])
    if result.return_code != 0:
        return {"valid": False, "reason": "Cannot read integrity file"}
    
    integrity_info = {}
    for line in result.stdout.strip().split("\n"):
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
    """Cache a tool binary for future use"""
    
    cache_info = get_cache_info(ctx, tool_name, version, platform, strategy)
    cache_path = cache_info["cache_path"]
    cache_dir = cache_info["cache_dir"]
    
    # Create cache directory
    ctx.execute(["mkdir", "-p", cache_dir])
    ctx.execute(["mkdir", "-p", cache_path])
    
    # Copy tool binary to cache
    cached_binary = "{}/{}".format(cache_path, tool_name)
    result = ctx.execute(["cp", str(tool_binary), cached_binary])
    if result.return_code != 0:
        # Cache operation failed, but don't fail the build
        print("Warning: Failed to cache tool {}: {}".format(tool_name, result.stderr))
        return False
    
    # Make cached binary executable
    ctx.execute(["chmod", "+x", cached_binary])
    
    # Create integrity file
    # Use a simple timestamp placeholder since Starlark doesn't have time module
    integrity_info = [
        "tool_name={}".format(tool_name),
        "version={}".format(version),
        "platform={}".format(platform),
        "strategy={}".format(strategy),
        "timestamp={}".format(hash(tool_name + version + platform)),  # Simple deterministic value
    ]
    
    if checksum:
        integrity_info.append("checksum={}".format(checksum))
    
    integrity_file = "{}/integrity.txt".format(cache_path)
    ctx.file(integrity_file, "\n".join(integrity_info))
    
    print("Tool {} cached successfully at {}".format(tool_name, cache_path))
    return True

def retrieve_cached_tool(ctx, tool_name, version, platform, strategy):
    """Retrieve a tool from cache if available and valid"""
    
    cache_info = get_cache_info(ctx, tool_name, version, platform, strategy)
    
    if not cache_info["exists"]:
        return None
    
    integrity_result = _verify_cache_integrity(ctx, cache_info["cache_path"], tool_name)
    if not integrity_result["valid"]:
        print("Warning: Cached tool {} is invalid ({}), will re-download".format(
            tool_name, integrity_result["reason"]
        ))
        # Clean up invalid cache
        ctx.execute(["rm", "-rf", cache_info["cache_path"]])
        return None
    
    # Copy from cache to current repository
    cached_binary = integrity_result["binary_path"]
    local_binary = tool_name
    
    result = ctx.execute(["cp", cached_binary, local_binary])
    if result.return_code != 0:
        print("Warning: Failed to retrieve cached tool {}: {}".format(tool_name, result.stderr))
        return None
    
    # Make local copy executable
    ctx.execute(["chmod", "+x", local_binary])
    
    print("Retrieved {} from cache ({})".format(tool_name, cache_info["cache_key"]))
    return local_binary

def clean_expired_cache(ctx, max_age_days = 30):
    """Clean up expired cache entries"""
    
    cache_dir = "/tmp/bazel_wasm_tool_cache"
    
    # Check if cache directory exists
    result = ctx.execute(["test", "-d", cache_dir])
    if result.return_code != 0:
        return  # No cache directory exists
    
    # Find and clean expired entries
    # Use a simple cache management approach for Starlark compatibility
    # In practice, external cleanup tools would manage cache expiration
    cleanup_threshold = max_age_days  # Simplified threshold
    
    # List cache entries
    result = ctx.execute(["find", cache_dir, "-maxdepth", "1", "-type", "d", "-name", "tool_cache_*"])
    if result.return_code != 0:
        return
    
    cache_entries = result.stdout.strip().split("\n") if result.stdout.strip() else []
    cleaned_count = 0
    
    for entry_path in cache_entries:
        if not entry_path:
            continue
        
        integrity_file = "{}/integrity.txt".format(entry_path)
        result = ctx.execute(["test", "-f", integrity_file])
        if result.return_code != 0:
            # No integrity file, remove entry
            ctx.execute(["rm", "-rf", entry_path])
            cleaned_count += 1
            continue
        
        # Check timestamp with Starlark-compatible validation
        result = ctx.execute(["grep", "timestamp=", integrity_file])
        if result.return_code == 0:
            timestamp_line = result.stdout.strip()
            if "=" in timestamp_line:
                timestamp_str = timestamp_line.split("=")[1]
                # Simple validation - if timestamp is numeric, consider it valid
                # More sophisticated cache management would use external tools
                if timestamp_str.isdigit():
                    # For now, keep all timestamped entries (simplified cache management)
                    pass
                else:
                    # Invalid timestamp format, remove entry
                    ctx.execute(["rm", "-rf", entry_path])
                    cleaned_count += 1
    
    if cleaned_count > 0:
        print("Cleaned {} expired cache entries".format(cleaned_count))

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
    """Get statistics about the tool cache"""
    
    cache_dir = "/tmp/bazel_wasm_tool_cache"
    
    # Check if cache directory exists
    result = ctx.execute(["test", "-d", cache_dir])
    if result.return_code != 0:
        return {
            "exists": False,
            "total_entries": 0,
            "total_size": "0B",
        }
    
    # Count entries
    result = ctx.execute(["find", cache_dir, "-maxdepth", "1", "-type", "d", "-name", "tool_cache_*"])
    entries = result.stdout.strip().split("\n") if result.stdout.strip() else []
    entry_count = len([e for e in entries if e])
    
    # Calculate total size
    result = ctx.execute(["du", "-sh", cache_dir])
    total_size = "unknown"
    if result.return_code == 0:
        size_line = result.stdout.strip()
        if size_line:
            total_size = size_line.split()[0]
    
    return {
        "exists": True,
        "total_entries": entry_count,
        "total_size": total_size,
        "cache_dir": cache_dir,
    }