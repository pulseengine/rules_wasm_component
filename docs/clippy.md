# Clippy Support

This project includes built-in support for running [Clippy](https://github.com/rust-lang/rust-clippy), the Rust linter, on all Rust WASM components.

## Running Clippy

### On All Targets

To run clippy on all Rust targets in the project:

```bash
bazel build --config=clippy //...
```

Or use the provided script:

```bash
./scripts/clippy.sh
```

### On Specific Targets

To run clippy on a specific target, you can use the `rust_wasm_component_clippy` rule:

```starlark
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component", "rust_wasm_component_clippy")

rust_wasm_component(
    name = "my_component",
    srcs = ["src/lib.rs"],
    # ...
)

rust_wasm_component_clippy(
    name = "my_component_clippy",
    target = ":my_component",
)
```

Then run:

```bash
bazel test //path/to:my_component_clippy
```

## Configuration

### Default Lints

By default, clippy is configured with the following lints as errors:

- `warnings` - All compiler warnings
- `clippy::all` - All default clippy lints
- `clippy::correctness` - Code that is likely incorrect or useless
- `clippy::style` - Code that should be written in a more idiomatic way
- `clippy::complexity` - Code that does something simple but in a complex way
- `clippy::perf` - Code that can be written more efficiently

### Custom Configuration

You can customize clippy behavior by modifying `.bazelrc`:

```bash
# Add custom clippy flags
build:clippy --@rules_rust//:clippy_flags=-D,warnings,-W,clippy::pedantic
```

### Per-Target Configuration

You can also configure clippy on a per-target basis:

```starlark
rust_wasm_component_clippy(
    name = "my_component_clippy",
    target = ":my_component",
    tags = ["manual"],  # Don't run with //...
)
```

## CI Integration

Clippy is automatically run in CI for all pull requests. To ensure your code passes CI:

1. Run clippy locally before pushing: `bazel build --config=clippy //...`
2. Fix any issues reported by clippy
3. Commit your changes

## Suppressing Lints

If you need to suppress a specific lint:

```rust
// Suppress for entire file
#![allow(clippy::specific_lint)]

// Suppress for specific code block
#[allow(clippy::specific_lint)]
fn my_function() {
    // ...
}
```

However, please use suppressions sparingly and document why they're necessary.
