"""Dual Implementation Toolchain for File Operations Components

This toolchain provides intelligent selection between TinyGo and Rust implementations
of the File Operations Component based on configuration, platform, and performance requirements.

Selection Strategy:
- TinyGo: High security, smaller binary size, WASI Preview 2 native
- Rust: High performance, advanced features, comprehensive error handling
- Fallback: Automatic selection based on platform and availability
"""

load("@bazel_skylib//lib:selects.bzl", "selects")

# Implementation preference enumeration
FILE_OPS_IMPLEMENTATIONS = {
    "tinygo": "TinyGo implementation (high security, compact)",
    "rust": "Rust implementation (high performance, feature-rich)",
    "auto": "Automatic selection based on platform and requirements",
}

def _dual_file_ops_toolchain_impl(ctx):
    """Implementation of dual_file_ops_toolchain rule with intelligent selection"""

    # Get implementation preference from configuration
    implementation_preference = ctx.attr.implementation_preference

    # Select the appropriate component based on preference and availability
    selected_component = None
    selected_implementation = None

    if implementation_preference == "tinygo" and ctx.executable.tinygo_component:
        selected_component = ctx.executable.tinygo_component
        selected_implementation = "tinygo"
    elif implementation_preference == "rust" and ctx.executable.rust_component:
        selected_component = ctx.executable.rust_component
        selected_implementation = "rust"
    elif implementation_preference == "auto":
        # Auto-selection logic: prefer Rust for performance, fallback to TinyGo
        if ctx.executable.rust_component:
            selected_component = ctx.executable.rust_component
            selected_implementation = "rust"
        elif ctx.executable.tinygo_component:
            selected_component = ctx.executable.tinygo_component
            selected_implementation = "tinygo"

    # Fallback selection if preferred implementation is not available
    if not selected_component:
        if ctx.executable.rust_component:
            selected_component = ctx.executable.rust_component
            selected_implementation = "rust"
        elif ctx.executable.tinygo_component:
            selected_component = ctx.executable.tinygo_component
            selected_implementation = "tinygo"
        else:
            fail("No file operations component available. Ensure at least one of tinygo_component or rust_component is provided.")

    # Create toolchain info with selected component
    toolchain_info = platform_common.ToolchainInfo(
        file_ops_component = selected_component,
        selected_implementation = selected_implementation,
        implementation_preference = implementation_preference,
        available_implementations = struct(
            tinygo = ctx.executable.tinygo_component != None,
            rust = ctx.executable.rust_component != None,
        ),
        file_ops_info = struct(
            component = selected_component,
            implementation = selected_implementation,
            wit_files = ctx.files.wit_files,
            capabilities = _get_implementation_capabilities(selected_implementation),
        ),
    )

    return [toolchain_info]

def _get_implementation_capabilities(implementation):
    """Get the capabilities of the selected implementation"""
    if implementation == "tinygo":
        return struct(
            security_level = "high",
            performance_level = "standard",
            binary_size = "compact",
            wasi_preview = "2",
            streaming_io = False,
            parallel_processing = False,
            advanced_error_handling = False,
        )
    elif implementation == "rust":
        return struct(
            security_level = "high",
            performance_level = "optimized",
            binary_size = "standard",
            wasi_preview = "2",
            streaming_io = True,
            parallel_processing = True,
            advanced_error_handling = True,
        )
    else:
        return struct()

dual_file_ops_toolchain = rule(
    implementation = _dual_file_ops_toolchain_impl,
    attrs = {
        "tinygo_component": attr.label(
            executable = True,
            cfg = "exec",
            doc = "TinyGo File Operations Component executable",
        ),
        "rust_component": attr.label(
            executable = True,
            cfg = "exec",
            doc = "Rust File Operations Component executable",
        ),
        "implementation_preference": attr.string(
            default = "auto",
            values = ["tinygo", "rust", "auto"],
            doc = "Preferred implementation: tinygo (compact+secure), rust (fast+advanced), auto (intelligent selection)",
        ),
        "wit_files": attr.label_list(
            allow_files = [".wit"],
            doc = "WIT interface files for the components",
        ),
    },
    doc = "Defines a dual implementation file operations toolchain with intelligent selection",
)

def _dual_file_ops_toolchain_repository_impl(repository_ctx):
    """Implementation of dual_file_ops_toolchain_repository rule"""

    # Get configuration attributes
    implementation_preference = repository_ctx.attr.implementation_preference
    enable_tinygo = repository_ctx.attr.enable_tinygo
    enable_rust = repository_ctx.attr.enable_rust

    # Build the toolchain configuration
    tinygo_component = ""
    rust_component = ""

    if enable_tinygo:
        # Reference to external TinyGo component
        tinygo_component = '''tinygo_component = "@bazel_file_ops_component//tinygo:file_ops_tinygo",'''

    if enable_rust:
        # Reference to external Rust component
        rust_component = '''rust_component = "@bazel_file_ops_component//rust:file_ops_rust",'''

    # Create BUILD file with dual toolchain configuration
    repository_ctx.file("BUILD.bazel", """
load("@rules_wasm_component//toolchains:dual_file_ops_toolchain.bzl", "dual_file_ops_toolchain")

package(default_visibility = ["//visibility:public"])

# Dual Implementation File Operations Toolchain
dual_file_ops_toolchain(
    name = "dual_file_ops_toolchain_impl",
    {tinygo_component}
    {rust_component}
    implementation_preference = "{implementation_preference}",
    wit_files = [
        "@bazel_file_ops_component//wit:file_operations_wit",
    ],
)

# Toolchain for high-security scenarios (prefer TinyGo)
dual_file_ops_toolchain(
    name = "security_focused_toolchain_impl",
    {tinygo_component}
    {rust_component}
    implementation_preference = "tinygo",
    wit_files = [
        "@bazel_file_ops_component//wit:file_operations_wit",
    ],
)

# Toolchain for high-performance scenarios (prefer Rust)
dual_file_ops_toolchain(
    name = "performance_focused_toolchain_impl",
    {tinygo_component}
    {rust_component}
    implementation_preference = "rust",
    wit_files = [
        "@bazel_file_ops_component//wit:file_operations_wit",
    ],
)

# Universal toolchain (auto-selection)
toolchain(
    name = "dual_file_ops_toolchain",
    toolchain = ":dual_file_ops_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:file_ops_toolchain_type",
)

# Security-focused toolchain registration
toolchain(
    name = "security_focused_toolchain",
    toolchain = ":security_focused_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:file_ops_toolchain_type",
)

# Performance-focused toolchain registration
toolchain(
    name = "performance_focused_toolchain",
    toolchain = ":performance_focused_toolchain_impl",
    toolchain_type = "@rules_wasm_component//toolchains:file_ops_toolchain_type",
)
""".format(
        tinygo_component = tinygo_component,
        rust_component = rust_component,
        implementation_preference = implementation_preference,
    ))

dual_file_ops_toolchain_repository = repository_rule(
    implementation = _dual_file_ops_toolchain_repository_impl,
    attrs = {
        "implementation_preference": attr.string(
            default = "auto",
            values = ["tinygo", "rust", "auto"],
            doc = "Default implementation preference for the toolchain",
        ),
        "enable_tinygo": attr.bool(
            default = True,
            doc = "Enable TinyGo implementation in the toolchain",
        ),
        "enable_rust": attr.bool(
            default = True,
            doc = "Enable Rust implementation in the toolchain",
        ),
    },
    doc = "Creates a repository with dual implementation file operations toolchain",
)

def register_dual_file_ops_toolchains(
        name = "dual_file_ops",
        implementation_preference = "auto",
        enable_tinygo = True,
        enable_rust = True):
    """Register dual implementation file operations toolchains

    Args:
        name: Repository name prefix for toolchain repositories
        implementation_preference: Default implementation preference ("tinygo", "rust", "auto")
        enable_tinygo: Whether to enable TinyGo implementation
        enable_rust: Whether to enable Rust implementation
    """

    # Create the dual toolchain repository
    dual_file_ops_toolchain_repository(
        name = name,
        implementation_preference = implementation_preference,
        enable_tinygo = enable_tinygo,
        enable_rust = enable_rust,
    )

    # Register the toolchain
    native.register_toolchains(
        "@{}//:dual_file_ops_toolchain".format(name),
        "@{}//:security_focused_toolchain".format(name),
        "@{}//:performance_focused_toolchain".format(name),
    )
