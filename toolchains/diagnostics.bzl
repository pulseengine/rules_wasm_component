"""Enhanced error handling and diagnostics for WASM toolchains"""

# Diagnostic error codes for structured error reporting
DIAGNOSTIC_CODES = {
    "E001": "Platform not supported",
    "E002": "Tool version not found", 
    "E003": "Download failed",
    "E004": "Checksum validation failed",
    "E005": "Build from source failed",
    "E006": "System tool not found",
    "E007": "Tool validation failed",
    "E008": "Version compatibility warning",
    "E009": "Network connectivity issue",
    "E010": "Permission denied",
}

def format_diagnostic_error(code, context, suggestion = None):
    """Format a structured diagnostic error message"""
    
    if code not in DIAGNOSTIC_CODES:
        fail("Unknown diagnostic code: {}".format(code))
    
    message_parts = [
        "Error {}: {}".format(code, DIAGNOSTIC_CODES[code]),
        "Context: {}".format(context),
    ]
    
    if suggestion:
        message_parts.append("Suggestion: {}".format(suggestion))
    
    # Add troubleshooting URL
    message_parts.append(
        "For more help, see: https://github.com/rules-wasm-component/docs/troubleshooting#{}".format(code.lower())
    )
    
    return "\n".join(message_parts)

def get_platform_error_suggestion(platform):
    """Get platform-specific error suggestions"""
    
    suggestions = {
        "darwin_amd64": "Try using Rosetta 2 compatibility mode or switch to arm64 binaries",
        "darwin_arm64": "Ensure you're using Apple Silicon compatible binaries",
        "linux_amd64": "Check if your distribution supports the required glibc version",
        "linux_arm64": "Consider using musl-based binaries for better compatibility",
        "windows_amd64": "Ensure Windows Subsystem for Linux (WSL) is properly configured",
    }
    
    return suggestions.get(platform, "Check platform compatibility and binary availability")

def get_download_error_suggestion(url, return_code):
    """Get download-specific error suggestions"""
    
    if return_code == 404:
        return "The requested file was not found. Check if the version and platform are correct."
    elif return_code == 403:
        return "Access denied. Check if authentication is required for this registry."
    elif return_code == 500:
        return "Server error. Try again later or use a different mirror."
    elif return_code in [0, None]:
        return "Network connectivity issue. Check your internet connection and proxy settings."
    else:
        return "HTTP error code {}. Check network connectivity and URL validity.".format(return_code)

def get_build_error_suggestion(tool_name, error_output):
    """Get build-specific error suggestions"""
    
    common_suggestions = {
        "cargo": [
            "Ensure Rust toolchain is installed and up to date",
            "Check if required system dependencies are available",
            "Try clearing cargo cache with 'cargo clean'",
        ],
        "git": [
            "Verify git is installed and accessible",
            "Check network connectivity for repository access",
            "Ensure SSH keys are configured if using SSH URLs",
        ],
        "compile": [
            "Install required development tools (build-essential, gcc, etc.)",
            "Check if all system dependencies are satisfied",
            "Try building with more verbose output for detailed errors",
        ],
    }
    
    # Analyze error output for specific patterns
    error_lower = error_output.lower() if error_output else ""
    
    suggestions = []
    if "cargo" in error_lower or "rust" in error_lower:
        suggestions.extend(common_suggestions["cargo"])
    if "git" in error_lower or "clone" in error_lower:
        suggestions.extend(common_suggestions["git"])
    if "compile" in error_lower or "gcc" in error_lower or "clang" in error_lower:
        suggestions.extend(common_suggestions["compile"])
    
    if not suggestions:
        suggestions = [
            "Check build logs for specific error details",
            "Ensure all required dependencies are installed",
            "Try building with a different strategy (download vs build)",
        ]
    
    return suggestions

def validate_system_tool(ctx, tool_name, expected_version = None):
    """Validate a system-installed tool with comprehensive checking"""
    
    # Check if tool exists using Bazel-native function
    tool_path = ctx.which(tool_name)
    if not tool_path:
        return {
            "valid": False,
            "error": format_diagnostic_error(
                "E006",
                "Tool '{}' not found in system PATH".format(tool_name),
                "Install {} using your system package manager or use download/build strategy".format(tool_name)
            ),
        }
    
    # Check if tool is accessible using Bazel-native path operations
    if not ctx.path(tool_path).exists:
        return {
            "valid": False,
            "error": format_diagnostic_error(
                "E010",
                "Tool '{}' found at '{}' but not executable".format(tool_name, tool_path),
                "Check file permissions: chmod +x {}".format(tool_path)
            ),
        }
    
    # Check version if expected version provided
    if expected_version:
        result = ctx.execute([tool_name, "--version"])
        if result.return_code == 0:
            actual_version = _extract_version_from_output(result.stdout)
            if actual_version and actual_version != expected_version:
                return {
                    "valid": True,
                    "warning": format_diagnostic_error(
                        "E008",
                        "Tool '{}' version mismatch: expected {}, found {}".format(
                            tool_name, expected_version, actual_version
                        ),
                        "Consider updating to the expected version or adjust configuration"
                    ),
                }
    
    return {"valid": True, "path": tool_path}

def _extract_version_from_output(output):
    """Extract version number from tool version output"""
    
    # Simple version extraction using string operations (Starlark compatible)
    # Look for patterns like "1.2.3", "version 1.2.3", "v1.2.3"
    
    lines = output.split("\n")
    for line in lines:
        # Remove common prefixes
        line = line.replace("version ", "").replace("v", "").strip()
        
        # Look for X.Y.Z pattern
        parts = line.split(".")
        if len(parts) >= 3:
            # Check if first three parts are numbers
            first_part = parts[0].split()[-1]  # Get last word in case of "tool name 1.2.3"
            if first_part.isdigit() and parts[1].isdigit() and parts[2].split()[0].isdigit():
                return "{}.{}.{}".format(first_part, parts[1], parts[2].split()[0])
    
    return None

def create_retry_wrapper(ctx, operation_name, max_retries = 3, base_delay = 1):
    """Create a retry wrapper for network operations"""
    
    def retry_operation(operation_func, *args):
        """Execute operation with simple retry (Starlark compatible)"""
        
        last_error = None
        for attempt in range(max_retries + 1):
            result = operation_func(*args)
            if hasattr(result, 'return_code') and result.return_code == 0:
                return result
            elif not hasattr(result, 'return_code'):
                return result
            else:
                last_error = result
            
            if attempt < max_retries:
                # Simple exponential backoff calculation (Starlark compatible)
                delay = base_delay * (2 * 2 * attempt)  # Simplified power calculation
                print("Warning: {} failed (attempt {}/{}), retrying...".format(
                    operation_name, attempt + 1, max_retries + 1
                ))
                # Note: Bazel repository rules don't support sleep, so this is conceptual
                # In practice, we would need to implement this differently
        
        # All attempts failed
        if hasattr(last_error, 'stderr'):
            error_detail = last_error.stderr
        else:
            error_detail = str(last_error)
        
        fail(format_diagnostic_error(
            "E003" if "download" in operation_name.lower() else "E005",
            "{} failed after {} attempts: {}".format(operation_name, max_retries + 1, error_detail),
            "Check network connectivity and try again later"
        ))
    
    return retry_operation

def log_diagnostic_info(ctx, tool_name, platform, version, strategy):
    """Log diagnostic information for debugging"""
    
    info_lines = [
        "=== WASM Toolchain Diagnostic Info ===",
        "Tool: {}".format(tool_name),
        "Platform: {}".format(platform),
        "Version: {}".format(version),
        "Strategy: {}".format(strategy),
        "Bazel version: {}".format(ctx.os.name),
        "Repository: {}".format(ctx.name),
        "====================================="
    ]
    
    # Write diagnostic info to a file for debugging
    ctx.file("diagnostic_info.txt", "\n".join(info_lines))
    
    return info_lines