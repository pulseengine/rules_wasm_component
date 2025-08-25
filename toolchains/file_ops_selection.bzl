"""File Operations Component Selection System

This module provides user-friendly macros and configuration options for selecting
between TinyGo and Rust implementations of the File Operations Component.

Usage Examples:
    # In your MODULE.bazel or WORKSPACE
    load("@rules_wasm_component//toolchains:file_ops_selection.bzl", "configure_file_ops")
    
    # Auto-selection (recommended for most users)
    configure_file_ops()
    
    # Security-focused configuration (prefer TinyGo)
    configure_file_ops(strategy = "security")
    
    # Performance-focused configuration (prefer Rust)
    configure_file_ops(strategy = "performance")
    
    # Manual selection
    configure_file_ops(
        implementation = "rust",
        fallback = "tinygo"
    )
"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("//toolchains:dual_file_ops_toolchain.bzl", "register_dual_file_ops_toolchains")

def configure_file_ops(
    name = "file_ops_config",
    strategy = "auto",
    implementation = None,
    fallback = None,
    enable_tinygo = True,
    enable_rust = True,
    register_toolchains = True):
    """Configure File Operations Component selection strategy
    
    This macro provides a user-friendly way to configure file operations components
    with intelligent defaults and clear selection strategies.
    
    Args:
        name: Configuration name (used for repository naming)
        strategy: Selection strategy - one of:
            - "auto": Intelligent selection based on platform and requirements
            - "security": Prefer TinyGo for maximum security and minimal attack surface
            - "performance": Prefer Rust for maximum performance and advanced features
            - "minimal": Prefer TinyGo for smallest binary size
        implementation: Direct implementation selection ("tinygo" or "rust")
            Takes precedence over strategy if specified
        fallback: Fallback implementation if primary choice is unavailable
        enable_tinygo: Whether to enable TinyGo implementation
        enable_rust: Whether to enable Rust implementation  
        register_toolchains: Whether to automatically register toolchains
    """
    
    # Determine implementation preference based on strategy or direct selection
    if implementation:
        # Direct implementation selection
        preference = implementation
    elif strategy == "security" or strategy == "minimal":
        preference = "tinygo"
    elif strategy == "performance":
        preference = "rust"
    else:  # auto or unknown strategy
        preference = "auto"
    
    # Register the dual implementation toolchains
    if register_toolchains:
        register_dual_file_ops_toolchains(
            name = name,
            implementation_preference = preference,
            enable_tinygo = enable_tinygo,
            enable_rust = enable_rust,
        )

def file_ops_build_setting():
    """Create build settings for runtime file operations selection"""
    
    # Define string flag for implementation selection
    native.config_setting(
        name = "file_ops_use_tinygo",
        flag_values = {
            "//toolchains:file_ops_implementation": "tinygo",
        },
    )
    
    native.config_setting(
        name = "file_ops_use_rust", 
        flag_values = {
            "//toolchains:file_ops_implementation": "rust",
        },
    )
    
    native.config_setting(
        name = "file_ops_auto_select",
        flag_values = {
            "//toolchains:file_ops_implementation": "auto",
        },
    )

def select_file_ops_component(tinygo_target, rust_target, auto_target = None):
    """Select file operations component based on configuration
    
    This function provides a select() statement for choosing between implementations
    at build time based on command-line flags or .bazelrc configuration.
    
    Args:
        tinygo_target: Target to use when TinyGo implementation is selected
        rust_target: Target to use when Rust implementation is selected  
        auto_target: Target to use for auto-selection (defaults to rust_target)
        
    Returns:
        A select() statement for build-time component selection
    """
    
    if not auto_target:
        auto_target = rust_target
    
    return select({
        "//toolchains:file_ops_use_tinygo": tinygo_target,
        "//toolchains:file_ops_use_rust": rust_target,
        "//toolchains:file_ops_auto_select": auto_target,
        "//conditions:default": auto_target,
    })

# Pre-defined configurations for common use cases
FILE_OPS_CONFIGURATIONS = {
    "default": {
        "strategy": "auto", 
        "description": "Intelligent auto-selection based on platform and requirements",
        "use_case": "General purpose development and production"
    },
    "security": {
        "strategy": "security",
        "description": "Prefer TinyGo for maximum security and minimal attack surface", 
        "use_case": "High-security environments, sandboxed execution"
    },
    "performance": {
        "strategy": "performance",
        "description": "Prefer Rust for maximum performance and advanced features",
        "use_case": "High-throughput file processing, batch operations"
    },
    "minimal": {
        "strategy": "minimal", 
        "description": "Prefer TinyGo for smallest binary size",
        "use_case": "Edge computing, embedded systems, size-constrained environments"
    },
    "development": {
        "strategy": "auto",
        "enable_tinygo": True,
        "enable_rust": True,
        "description": "Development configuration with both implementations available",
        "use_case": "Development and testing environments"
    },
}

def configure_file_ops_preset(preset_name, **kwargs):
    """Configure file operations using a preset configuration
    
    Args:
        preset_name: Name of preset configuration from FILE_OPS_CONFIGURATIONS
        **kwargs: Additional configuration options to override preset defaults
    """
    
    if preset_name not in FILE_OPS_CONFIGURATIONS:
        fail("Unknown file operations preset: {}. Available presets: {}".format(
            preset_name, 
            list(FILE_OPS_CONFIGURATIONS.keys())
        ))
    
    preset_config = FILE_OPS_CONFIGURATIONS[preset_name]
    
    # Merge preset configuration with user overrides
    config = {}
    config.update(preset_config)
    config.update(kwargs)
    
    # Remove description and use_case from final config
    config.pop("description", None)
    config.pop("use_case", None)
    
    configure_file_ops(**config)

def get_file_ops_info():
    """Get information about available file operations configurations"""
    
    info = []
    for name, config in FILE_OPS_CONFIGURATIONS.items():
        info.append("""
Configuration: {name}
Strategy: {strategy} 
Description: {description}
Use Case: {use_case}
""".format(
            name = name,
            strategy = config.get("strategy", "unknown"),
            description = config.get("description", "No description"),
            use_case = config.get("use_case", "General purpose")
        ))
    
    return "\n".join(info)

# Helper macros for specific scenarios
def configure_file_ops_for_security(**kwargs):
    """Configure file operations optimized for security scenarios"""
    configure_file_ops(strategy = "security", **kwargs)

def configure_file_ops_for_performance(**kwargs):
    """Configure file operations optimized for performance scenarios"""
    configure_file_ops(strategy = "performance", **kwargs)

def configure_file_ops_for_development(**kwargs):
    """Configure file operations for development with both implementations"""
    configure_file_ops(
        strategy = "auto",
        enable_tinygo = True,
        enable_rust = True,
        **kwargs
    )