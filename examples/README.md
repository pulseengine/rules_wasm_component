# WebAssembly Examples

This directory contains examples demonstrating different approaches to building WebAssembly modules and components.

## Examples Overview

### 1. `simple_module/` - Basic WASM Module
**Status: ✅ Working**

A simple Rust library compiled to a core WebAssembly module without component model features.

```bash
bazel build //examples/simple_module:simple_wasm --config=wasi
```

**Use this when:**
- You need a basic WASM module with simple numeric functions
- You don't need component model features like interface types
- You want to avoid complex WIT interface definitions
- You're targeting environments that don't support the component model yet

### 2. `basic/` - Component with WIT Bindings  
**Status: ⚠️ Partially Working (Rust toolchain issue)**

A WebAssembly component using WIT interfaces and generated bindings.

```bash
# WIT bindings generation works:
bazel build //examples/basic:hello_component_bindings --config=wasi

# Full component build blocked by Rust toolchain configuration issue
bazel build //examples/basic:hello_component --config=wasi  # Currently fails
```

**Use this when:**
- You need rich interface types (strings, records, enums)
- You want language-agnostic interfaces via WIT
- You need component composition and linking
- You're building for component model runtimes

### 3. `multi_profile/` - Advanced Component Composition
**Status: ⚠️ Manual (tags = ["manual"])**

Advanced example showing multi-profile builds and component composition.

## Rule Differences

### `rust_wasm_component` vs `rust_wasm_component_bindgen`

**`rust_wasm_component`:**
- Basic rule that compiles Rust to WASM and converts to component
- Requires manual WIT interface implementation
- More control but more setup required

**`rust_wasm_component_bindgen`:**
- High-level macro with automatic WIT binding generation
- Creates separate bindings library automatically
- Provides wit_bindgen runtime without external dependencies
- Recommended for component development

### `rust_shared_library` (Direct)
- Builds core WASM modules only
- No component model features
- Simpler and more reliable for basic use cases
- Works around current Rust toolchain configuration issues

## Current Status

### ✅ Working Examples
- **C++ toolchain**: Full path resolution fixed, builds successfully
- **Simple WASM modules**: Core Rust → WASM compilation works
- **WIT binding generation**: wit-bindgen command fixed, generates proper bindings

### ⚠️ Known Issues
- **Rust component builds**: Blocked by Rust toolchain trying to use WASI SDK tools without proper inputs
- **Full component pipeline**: WIT embedding works, but Rust compilation fails due to toolchain configuration

### 🔧 Recent Fixes
1. Fixed C++ toolchain path resolution issues
2. Fixed "decoding a component is not supported" by implementing proper WIT embedding
3. Fixed wit-bindgen CLI syntax (--world instead of --with)
4. Added working simple WASM module example

## Building Examples

Use the WASI configuration for all WebAssembly builds:

```bash
# Working examples:
bazel build //test/toolchain:test_cc --config=wasi                    # C++ → WASM  
bazel build //examples/simple_module:simple_wasm --config=wasi       # Rust → WASM module
bazel build //examples/basic:hello_component_bindings --config=wasi  # WIT bindings

# Currently blocked (Rust toolchain issue):
bazel build //examples/basic:hello_component --config=wasi           # Full component
```

The toolchain infrastructure is now solid - the remaining work is resolving the Rust toolchain configuration to properly include WASI SDK tools in Rust build actions.