# Symmetric WIT Bindings Example

This example demonstrates the difference between traditional WIT bindings and symmetric bindings using cpetig's wit-bindgen fork.

## Overview

### Traditional Approach (Official wit-bindgen)

- **Guest bindings**: Used by WASM component implementations
- **Native-guest bindings**: Used by host applications to call WASM components
- **Separate code paths**: Different APIs for component and host sides
- **Runtime dependency**: Requires wasmtime or similar for component execution

### Symmetric Approach (cpetig's fork)

- **Unified bindings**: Same source code runs natively and as WASM component
- **Feature-based compilation**: Use cargo features to switch between modes
- **Direct execution**: Native mode runs without WASM overhead
- **Simplified development**: Single codebase for both execution modes

## Setup

To use symmetric bindings, you need to set up the symmetric wit-bindgen toolchain in your `MODULE.bazel`:

```starlark
# Add symmetric wit-bindgen repository
symmetric_wit_bindgen_repository = use_extension("@rules_wasm_component//toolchains:extensions.bzl", "symmetric_wit_bindgen_repository")
symmetric_wit_bindgen_repository(name = "symmetric_wit_bindgen")

# Register the symmetric toolchain
register_toolchains("@symmetric_wit_bindgen//:symmetric_wit_bindgen_toolchain")
```

## Files Structure

```
symmetric_example/
├── BUILD.bazel                 # Build configuration
├── README.md                   # This file
├── wit/
│   └── symmetric.wit          # WIT interface definition
└── src/
    ├── symmetric.rs           # Symmetric component implementation
    ├── traditional.rs         # Traditional component implementation
    ├── symmetric_host.rs      # Host using symmetric bindings
    └── traditional_host.rs    # Host using traditional bindings
```

## Building and Running

### Build all examples

```bash
bazel build //examples/symmetric_example:all
```

### Run traditional host

```bash
bazel run //examples/symmetric_example:traditional_host
```

### Run symmetric host

```bash
bazel run //examples/symmetric_example:symmetric_host
```

### Test compilation

```bash
bazel test //examples/symmetric_example:test_symmetric_compilation
```

## Key Differences

### Component Implementation

**Traditional (`traditional.rs`):**

```rust
#[cfg(target_arch = "wasm32")]
use traditional_component_bindings::exports::...;

#[cfg(target_arch = "wasm32")]
impl Guest for Calculator { ... }

#[cfg(target_arch = "wasm32")]
traditional_component_bindings::export!(Calculator with_types_in traditional_component_bindings);
```

**Symmetric (`symmetric.rs`):**

```rust
use symmetric_component_bindings::exports::...;

impl Guest for Calculator { ... }

// Works in both modes
symmetric_component_bindings::export!(Calculator with_types_in symmetric_component_bindings);

#[cfg(feature = "symmetric")]
pub fn main() {
    // Can run natively with symmetric feature
}
```

### Host Usage

**Traditional:**

- Requires wasmtime runtime
- Component loading and instantiation
- Indirect function calls through runtime

**Symmetric:**

- Direct function calls
- No runtime overhead
- Same API as component implementation

## Use Cases

### When to use Traditional

- Need strong isolation between host and component
- Multiple component instances
- Dynamic component loading
- Security boundaries important

### When to use Symmetric

- Performance-critical applications
- Unified development workflow
- Testing component logic without WASM overhead
- Gradual migration from native to component architecture

## Benefits of Symmetric Approach

1. **Simplified Development**: Write once, run anywhere (native or WASM)
2. **Easier Testing**: Test component logic directly without WASM runtime
3. **Performance**: Native execution without WASM overhead when appropriate
4. **Migration Path**: Gradual transition from native to component architecture
5. **Debugging**: Standard debugger support for native execution

## Requirements

- Bazel with rules_wasm_component
- Rust toolchain
- cpetig's wit-bindgen fork (automatically downloaded)
- For comparison: official wit-bindgen (automatically downloaded)
