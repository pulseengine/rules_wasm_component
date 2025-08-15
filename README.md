# Bazel Rules for WebAssembly Component Model

Modern Bazel rules for building and composing WebAssembly components.

## Features

- 🚀 **Component Model Support**: Full support for WASM Component Model and WIT
- 🦀 **Rust Integration**: Seamless integration with rules_rust
- 🐹 **Go Integration**: TinyGo v0.38.0 with WASI Preview 2 component support
- 🔧 **Toolchain Management**: Automatic wasm-tools and wit-bindgen setup
- 📦 **Composition**: WAC-based component composition with OCI registry support
- 🐳 **OCI Publishing**: Publish and distribute components via container registries
- 🔐 **Digital Signing**: Component signing with wasmsign2 and verification
- 🏗️ **Enterprise Architecture**: Multi-registry microservices with security policies
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

# Optional: Configure TinyGo toolchain version
tinygo = use_extension("//wasm:extensions.bzl", "tinygo")
tinygo.register(
    name = "tinygo",
    tinygo_version = "0.38.0"  # Optional, defaults to 0.38.0
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

### 2b. Build Go WASM Component

```starlark
load("@rules_wasm_component//go:defs.bzl", "go_wasm_component")

go_wasm_component(
    name = "my_go_component",
    srcs = ["main.go", "logic.go"],
    wit = "my-interface.wit",
    world = "my-world",
    go_mod = "go.mod",
    adapter = "//wasm/adapters:wasi_snapshot_preview1",
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

### Go Rules

- `go_wasm_component` - Build Go WASM components with TinyGo
- `go_wit_bindgen` - Generate Go bindings from WIT interfaces

### Composition Rules

- `wac_compose` - Compose multiple components
- `wac_compose_with_oci` - Compose local and OCI registry components
- `wac_microservices_app` - Microservices composition pattern
- `wac_distributed_system` - Distributed system composition pattern
- `wasm_component_new` - Convert modules to components

### OCI Publishing Rules

- `wasm_component_oci_image` - Prepare OCI images for components
- `wasm_component_publish` - Publish components to registries
- `wasm_component_from_oci` - Pull components from OCI registries
- `wkg_registry_config` - Configure registry authentication
- `wkg_multi_registry_publish` - Publish to multiple registries

### Security Rules

- `wasm_keygen` - Generate signing key pairs
- `wasm_sign` - Sign WebAssembly components
- `wasm_security_policy` - Define security policies
- `wasm_component_secure_publish` - Policy-enforced publishing

### Analysis Rules

- `wasm_validate` - Validate WASM components
- `wit_lint` - Lint WIT interfaces

## Examples

See the [`examples/`](examples/) directory for complete examples:

### Core Examples

- [Basic Component](examples/basic/) - Simple component with WIT
- [Go Component](examples/go_component/) - TinyGo WASM components
- [JavaScript Component](examples/js_component/) - JS components with ComponentizeJS
- [C++ Component](examples/cpp_component/) - Native C++ component development

### Composition and Architecture

- [WAC Remote Compose](examples/wac_remote_compose/) - Remote component composition
- [WAC + OCI Composition](examples/wac_oci_composition/) - OCI registry integration
- [Microservices Architecture](examples/microservices_architecture/) - Production-ready microservices
- [Multi-Language Composition](examples/multi_language_composition/) - Polyglot component systems

### OCI and Distribution

- [OCI Publishing](examples/oci_publishing/) - Container registry publishing
- [Component Signing](examples/wasm_signing/) - Digital signatures with wasmsign2

### Advanced Features

- [Wizer Pre-initialization](examples/wizer_example/) - Startup optimization
- [Wasmtime Runtime](examples/wasmtime_runtime/) - Custom runtime integration
- [Multi-Profile Components](examples/multi_profile/) - Development vs production builds

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

### Development Setup

This project uses pre-commit hooks for code quality:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install
pre-commit install --hook-type commit-msg

# Test setup
pre-commit run --all-files
```

See [Pre-commit Instructions](.pre-commit-instructions.md) for detailed setup.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
