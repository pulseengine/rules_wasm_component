# Bazel Rules for WebAssembly Component Model

Modern Bazel rules for building and composing WebAssembly components.

## Features

- 🚀 **Component Model Support**: Full support for WASM Component Model and WIT
- 🦀 **Rust Integration**: Seamless integration with rules_rust
- 🔧 **Toolchain Management**: Automatic wasm-tools and wit-bindgen setup
- 📦 **Composition**: WAC-based component composition
- 🎯 **Type Safety**: Strongly typed WIT interfaces
- ⚡ **Performance**: Optimized builds with proper caching

## Installation

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_wasm_component", version = "1.0.0")

# Optional: Configure WASM toolchain version
wasm_toolchain = use_extension(
    "@rules_wasm_component//wasm:extensions.bzl",
    "wasm_toolchain",
)
wasm_toolchain.register(
    name = "wasm_tools",
    version = "1.0.60",  # Optional, defaults to latest stable
)
```

## Quick Start

### 1. Define WIT Interfaces

```starlark
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "my_interfaces",
    srcs = ["my-interface.wit"],
    deps = ["//wit/deps:wasi-io"],
)
```

### 2. Build Rust WASM Component

```starlark
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component")

rust_wasm_component(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit_bindgen = ":my_interfaces",
    deps = [
        "//third_party/rust:wit_bindgen",
    ],
)
```

### 3. Compose Components

```starlark
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")

wac_compose(
    name = "my_system",
    components = {
        "frontend": ":frontend_component",
        "backend": ":backend_component",
    },
    composition = """
        let frontend = new frontend:component { ... };
        let backend = new backend:component { ... };
        
        connect frontend.request -> backend.handler;
        
        export frontend as main;
    """,
)
```

## Rules

### WIT Rules

- `wit_library` - Process WIT interface files
- `wit_bindgen` - Generate language bindings from WIT

### Rust Rules

- `rust_wasm_component` - Build Rust WASM components
- `rust_wasm_component_test` - Test WASM components

### Composition Rules

- `wac_compose` - Compose multiple components
- `wasm_component_new` - Convert modules to components

### Analysis Rules

- `wasm_validate` - Validate WASM components
- `wit_lint` - Lint WIT interfaces

## Examples

See the [`examples/`](examples/) directory for complete examples:

- [Basic Component](examples/basic/) - Simple component with WIT
- [Composition](examples/composition/) - Multi-component system
- [WASI Integration](examples/wasi/) - Using WASI interfaces
- [Testing](examples/testing/) - Component testing patterns

## Documentation

### For Developers
- [Rule Reference](docs/rules.md)
- [Migration Guide](docs/migration.md)
- [Best Practices](docs/best_practices.md)
- [Troubleshooting](docs/troubleshooting.md)

### For AI Agents
- [**AI Agent Guide**](docs/ai_agent_guide.md) - Structured documentation for AI coding assistants
- [**Rule Schemas**](docs/rule_schemas.json) - Machine-readable rule definitions
- [Examples](docs/examples/) - Progressive complexity examples:
  - [Basic](docs/examples/basic/) - Fundamental patterns
  - [Intermediate](docs/examples/intermediate/) - Cross-package dependencies  
  - [Advanced](docs/examples/advanced/) - Complex compositions and custom rules

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md).

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.