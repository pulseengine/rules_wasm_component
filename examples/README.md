# WebAssembly Examples

This directory contains examples demonstrating different approaches to building WebAssembly modules and components with full support for multiple languages.

## Examples Overview

### 1. `basic/` - Simple Rust Component

**Status: ✅ Working**

A basic WebAssembly component using Rust with WIT interfaces and generated bindings.

```bash
bazel build //examples/basic:hello_component
bazel test //examples/basic:hello_component_test
```

**Use this when:**

- You need a simple component with WIT interfaces
- You want to learn the basic component model workflow
- You need rich interface types (strings, records, enums)

### 2. `go_component/` - TinyGo Components

**Status: ✅ Working**

Advanced Go WebAssembly components using TinyGo v0.38.0 with WASI Preview 2 support.

```bash
bazel build //examples/go_component:calculator_component
bazel build //examples/go_component:http_service_component
```

**Use this when:**

- You want to write components in Go
- You need WASI Preview 2 functionality
- You want automatic WIT binding generation for Go

### 3. `cpp_component/` - C++ Components

**Status: ✅ Working**

WebAssembly components written in C++ with WASI SDK toolchain.

```bash
bazel build //examples/cpp_component/calculator:calculator_component
bazel build //examples/cpp_component/http_service:http_service_component
```

**Use this when:**

- You have existing C++ code to port
- You need high performance components
- You want to leverage C++ ecosystem libraries

### 4. `js_component/` - JavaScript/TypeScript Components

**Status: ✅ Working**

WebAssembly components using ComponentizeJS for JavaScript/TypeScript.

```bash
bazel build //examples/js_component:calculator_component
```

**Use this when:**

- You want to write components in JavaScript/TypeScript
- You need rapid prototyping capabilities
- You want to leverage npm ecosystem

## Language Support

### Rust Components

- **Full WebAssembly Component Model support**
- **Advanced WIT binding generation**
- **Production-ready toolchain**
- **Optimized for size and performance**

### Go Components (TinyGo)

- **TinyGo v0.38.0 with WASI Preview 2**
- **Dual-step compilation (WASM module → Component)**
- **WASI Preview 1 adapter integration**
- **Full go.bytecodealliance.org support**

### C++ Components

- **WASI SDK toolchain**
- **C-style WIT bindings**
- **High performance native code**
- **Extensive C/C++ ecosystem support**

### JavaScript/TypeScript Components

- **ComponentizeJS integration**
- **Full npm ecosystem access**
- **TypeScript type safety**
- **Rapid development workflow**

## Key Features

### 🚀 **Multi-Language Support**

All major languages supported with first-class toolchain integration.

### 🎯 **WIT Interface Generation**

Automatic binding generation from WIT interface definitions for all languages.

### 📦 **Component Composition**

Full support for composing components across languages using WAC.

### ⚡ **Production Ready**

Optimized toolchains with proper caching, parallel builds, and platform constraints.

## Building All Examples

```bash
# Build all working examples
bazel build //examples/basic:hello_component
bazel build //examples/go_component:calculator_component
bazel build //examples/cpp_component/calculator:calculator_cpp_component
bazel build //examples/js_component:hello_js_component

# Run tests
bazel test //examples/basic:hello_component_test
bazel test //examples/go_component:...
```

All examples are **production ready** and demonstrate best practices for WebAssembly Component Model development! 🎉
