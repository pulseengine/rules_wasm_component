# Dual Implementation File Operations Strategy

This document provides comprehensive examples of how to configure and use the dual implementation strategy for File Operations Components, allowing intelligent selection between TinyGo and Rust implementations.

## Quick Start

### 1. Basic Configuration (Recommended)

Add to your `MODULE.bazel`:

```starlark
# Auto-select best implementation (recommended)
load("@rules_wasm_component//toolchains:file_ops_selection.bzl", "configure_file_ops")

configure_file_ops()  # Intelligent auto-selection
```

### 2. Strategy-Based Configuration

```starlark
# Security-focused configuration (prefer TinyGo)
configure_file_ops(strategy = "security")

# Performance-focused configuration (prefer Rust)
configure_file_ops(strategy = "performance")

# Minimal binary size (prefer TinyGo)
configure_file_ops(strategy = "minimal")
```

### 3. Direct Implementation Selection

```starlark
# Force specific implementation
configure_file_ops(
    implementation = "rust",
    fallback = "tinygo"  # Use TinyGo if Rust unavailable
)

# Development setup (both implementations available)
configure_file_ops(
    strategy = "auto",
    enable_tinygo = True,
    enable_rust = True,
)
```

## Advanced Usage

### Preset Configurations

Use predefined configurations for common scenarios:

```starlark
load("@rules_wasm_component//toolchains:file_ops_selection.bzl", "configure_file_ops_preset")

# Production security setup
configure_file_ops_preset("security")

# High-performance batch processing
configure_file_ops_preset("performance")

# Edge computing / embedded
configure_file_ops_preset("minimal")

# Development environment
configure_file_ops_preset("development")
```

### Build-Time Selection

Control implementation selection with command-line flags:

```bash
# Use TinyGo implementation
bazel build //your:target --//toolchains:file_ops_implementation=tinygo

# Use Rust implementation
bazel build //your:target --//toolchains:file_ops_implementation=rust

# Use automatic selection (default)
bazel build //your:target --//toolchains:file_ops_implementation=auto
```

### .bazelrc Configuration

Add to your `.bazelrc` for persistent configuration:

```bash
# Default to Rust for performance
build --//toolchains:file_ops_implementation=rust

# Security builds use TinyGo
build:security --//toolchains:file_ops_implementation=tinygo

# Development with auto-selection
build:dev --//toolchains:file_ops_implementation=auto
```

## Implementation Comparison

| Feature                 | TinyGo                    | Rust                  | Use Case           |
| ----------------------- | ------------------------- | --------------------- | ------------------ |
| **Binary Size**         | ✅ Compact (~100KB)       | ⚠️ Larger (~500KB)    | Edge/Embedded      |
| **Security**            | ✅ Minimal Attack Surface | ✅ Memory Safe        | High Security      |
| **Performance**         | ⚠️ Standard               | ✅ Optimized          | Batch Processing   |
| **Streaming I/O**       | ❌ Basic                  | ✅ Advanced Buffering | Large Files        |
| **Parallel Processing** | ❌ Sequential             | ✅ Concurrent         | Multi-file Ops     |
| **WASI Preview 2**      | ✅ Native Support         | ✅ Full Support       | Modern Runtime     |
| **JSON Batch API**      | ✅ Compatible             | ✅ Enhanced           | Legacy Integration |

## Usage in Build Rules

### Using the Toolchain in Custom Rules

```starlark
def _my_rule_impl(ctx):
    # Get the file operations toolchain
    file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]

    # Access selected component and metadata
    component = file_ops_toolchain.file_ops_component
    implementation = file_ops_toolchain.selected_implementation
    capabilities = file_ops_toolchain.file_ops_info.capabilities

    # Use capabilities to optimize behavior
    if capabilities.streaming_io:
        # Use streaming operations for large files
        pass

    if capabilities.parallel_processing:
        # Process multiple files concurrently
        pass

    # Execute file operations
    ctx.actions.run(
        executable = component,
        arguments = ["copy_file", "--src", "input.txt", "--dest", "output.txt"],
        inputs = [ctx.file.input],
        outputs = [ctx.outputs.output],
        mnemonic = "FileOpsCopy",
    )

my_rule = rule(
    implementation = _my_rule_impl,
    toolchains = ["@rules_wasm_component//toolchains:file_ops_toolchain_type"],
    # ... other attributes
)
```

### Selecting Implementation Based on File Size

```starlark
load("@rules_wasm_component//toolchains:file_ops_selection.bzl", "select_file_ops_component")

# Different components for different file sizes
my_file_processor = select_file_ops_component(
    tinygo_target = "//my:small_file_processor",    # < 10MB files
    rust_target = "//my:large_file_processor",      # >= 10MB files
    auto_target = "//my:adaptive_processor",        # Auto-detect
)
```

## Configuration Examples by Use Case

### 1. High-Security Web Service

```starlark
# Prefer TinyGo for minimal attack surface
configure_file_ops(
    strategy = "security",
    enable_rust = False,  # Security-only deployment
)
```

### 2. Data Processing Pipeline

```starlark
# Prefer Rust for streaming I/O and performance
configure_file_ops(
    strategy = "performance",
    enable_tinygo = True,  # Keep TinyGo as fallback
)
```

### 3. Edge Computing Device

```starlark
# Minimize binary size for resource constraints
configure_file_ops(
    strategy = "minimal",
    enable_rust = False,  # Size-optimized deployment
)
```

### 4. Development Environment

```starlark
# Both implementations for testing and development
configure_file_ops(
    strategy = "auto",
    enable_tinygo = True,
    enable_rust = True,
)

# Helper functions for development
configure_file_ops_for_development()  # Same as above
```

### 5. CI/CD Pipeline

```starlark
# Different implementations for different stages
configure_file_ops(
    strategy = "auto",  # Let toolchain choose best for each platform
    enable_tinygo = True,
    enable_rust = True,
)
```

## Troubleshooting

### Implementation Not Available

If your preferred implementation isn't available:

```bash
# Check available implementations
bazel query @dual_file_ops//:*

# Force fallback to available implementation
bazel build --//toolchains:file_ops_implementation=auto
```

### Performance Issues

For performance debugging:

```bash
# Use Rust implementation for better performance
bazel build --//toolchains:file_ops_implementation=rust

# Enable performance-focused toolchain
bazel build --config=performance
```

### Binary Size Concerns

For size optimization:

```bash
# Use TinyGo implementation
bazel build --//toolchains:file_ops_implementation=tinygo

# Enable minimal configuration
bazel build --config=minimal
```

## Migration from Single Implementation

If you're migrating from a single implementation:

1. **Replace direct component references:**

   ```starlark
   # Old
   file_ops_component = "@rules_wasm_component//tools/file_ops:file_ops"

   # New
   file_ops_component = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"].file_ops_component
   ```

2. **Update toolchain declarations:**

   ```starlark
   my_rule = rule(
       # Add toolchain dependency
       toolchains = ["@rules_wasm_component//toolchains:file_ops_toolchain_type"],
       # ... other attributes
   )
   ```

3. **Configure preferred implementation:**

   ```starlark
   # In MODULE.bazel
   configure_file_ops(strategy = "performance")  # Or your preferred strategy
   ```

This dual implementation strategy provides the flexibility to choose the best file operations component for your specific use case while maintaining a consistent API and easy migration path.
