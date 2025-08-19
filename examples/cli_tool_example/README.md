# CLI Tool Example: When to Use `rust_wasm_component` vs `rust_wasm_component_bindgen`

This example demonstrates the **key differences** between the two Rust WebAssembly component rules and when to use each one.

## Rule Comparison

### `rust_wasm_component` (Lower-Level Rule)

**Use for**: CLI tools, utilities, WASI-only components

```starlark
rust_wasm_component(
    name = "file_processor_cli",
    srcs = ["src/cli_tool.rs"],
    deps = ["@crates//:clap", "@crates//:anyhow"],
    # No 'wit' attribute - uses WASI only
    rustc_flags = ["-C", "opt-level=3"],  # Custom optimization
)
```

### `rust_wasm_component_bindgen` (High-Level Rule)

**Use for**: Components with custom interfaces, inter-component communication

```starlark
rust_wasm_component_bindgen(
    name = "file_processor_component",
    srcs = ["src/component_lib.rs"],
    wit = ":processor_interfaces",  # Custom WIT interfaces
    profiles = ["release"],         # Simplified configuration
)
```

## When to Use Each

### Use `rust_wasm_component` when

1. **CLI Tools & Utilities**
   - Command-line applications run by users
   - Tools that process files, manipulate data, etc.
   - Applications that use WASI but don't export custom functions

2. **WASI-Only Components**
   - Components that only import WASI capabilities (filesystem, stdio, etc.)
   - No custom interfaces to export to other components
   - Simple input/output processing

3. **Legacy WASM Module Conversion**
   - Converting existing `.wasm` modules to component format
   - Wrapping external tools for component compatibility
   - Migration of existing WebAssembly applications

4. **Custom Build Requirements**
   - Need specific rustc flags or optimization settings
   - Complex compilation pipelines
   - Performance-critical components requiring fine-tuned compilation

### Use `rust_wasm_component_bindgen` when

1. **Custom Component Interfaces**
   - Exporting functions for other components to call
   - Defining custom WIT interfaces and types
   - Building reusable component libraries

2. **Inter-Component Communication**
   - Components designed to be composed with others
   - Microservices architectures using WAC
   - Plugin systems and modular applications

3. **Standard Component Development**
   - Most typical component development workflows
   - Following component model best practices
   - Leveraging automatic binding generation

4. **Simplified Development Experience**
   - Want automatic WIT binding generation
   - Prefer conventional configuration over custom flags
   - Building components for consumption by others

## Examples in This Directory

### CLI Tool (`file_processor_cli`)

- **File**: `src/cli_tool.rs`
- **Use case**: Command-line file processing utility
- **Interfaces**: WASI only (filesystem, stdio)
- **Usage**: `wasmtime run file_processor_cli.wasm -- upper -i input.txt -o output.txt`

### Component Library (`file_processor_component`)

- **File**: `src/component_lib.rs` + `wit/processor.wit`
- **Use case**: Reusable file processing functions for other components
- **Interfaces**: Custom WIT interfaces + WASI
- **Usage**: Called by other components via WIT interfaces

## Building and Testing

```bash
# Build both examples
bazel build //examples/cli_tool_example:file_processor_cli
bazel build //examples/cli_tool_example:file_processor_component

# Compare component sizes and characteristics
bazel build //examples/cli_tool_example:component_comparison
cat bazel-bin/examples/cli_tool_example/comparison.txt

# Test the CLI tool
echo "hello world" > test.txt
wasmtime run bazel-bin/examples/cli_tool_example/file_processor_cli.wasm -- upper -i test.txt -o upper.txt
cat upper.txt  # Should show "HELLO WORLD"

# Inspect the component library
wasm-tools component wit bazel-bin/examples/cli_tool_example/file_processor_component.wasm
```

## Key Takeaways

- **`rust_wasm_component`**: Lower-level, more control, CLI tools, WASI-only
- **`rust_wasm_component_bindgen`**: Higher-level, automatic bindings, custom interfaces
- **Choose based on use case**: CLI utilities vs component libraries
- **Both are valid**: Different tools for different jobs in the WebAssembly ecosystem

Most developers should start with `rust_wasm_component_bindgen` for typical component development, and use `rust_wasm_component` when they need the specific capabilities it provides.
