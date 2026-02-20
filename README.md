<div align="center">

# rules_wasm_component

<sup>Bazel rules for WebAssembly Component Model</sup>

&nbsp;

![Bazel](https://img.shields.io/badge/Bazel-43A047?style=flat-square&logo=bazel&logoColor=white&labelColor=1a1b27)
![WebAssembly](https://img.shields.io/badge/WebAssembly-654FF0?style=flat-square&logo=webassembly&logoColor=white&labelColor=1a1b27)
![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue?style=flat-square&labelColor=1a1b27)

</div>

&nbsp;

Production-ready Bazel rules for building WebAssembly components across multiple languages with native WASI Preview 2 support.

> [!NOTE]
> Part of the PulseEngine toolchain. Used across all PulseEngine projects for hermetic component builds.

## Why Use This?

- **Multi-language**: Build components from Rust, Go (TinyGo), C++, JavaScript/TypeScript
- **Production Ready**: OCI publishing, cryptographic signing, WAC composition, AOT compilation
- **Bazel Native**: Hermetic builds, aggressive caching, cross-platform (Windows/macOS/Linux)
- **Zero Shell Scripts**: Pure Bazel implementation for maximum portability

## Installation

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

## Quick Examples

### Rust Component

```starlark
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component")

rust_wasm_component(
    name = "my_service",
    srcs = ["src/lib.rs"],
    wit = ":service_wit",
    profiles = ["debug", "release"],
)
```

### Go Component (TinyGo 0.39.0+)

```starlark
load("@rules_wasm_component//go:defs.bzl", "go_wasm_component")

go_wasm_component(
    name = "calculator",
    srcs = ["main.go"],
    wit = ":calculator_wit",
    world = "calculator",
)
```

### C++ Component (WASI SDK 27+)

```starlark
load("@rules_wasm_component//cpp:defs.bzl", "cpp_component")

cpp_component(
    name = "calculator",
    srcs = ["calculator.cpp"],
    wit = ":calculator_wit",
    cxx_std = "c++20",
)
```

### WAC Composition

```starlark
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")

wac_compose(
    name = "full_system",
    components = {
        ":frontend": "app:frontend",
        ":backend": "app:backend",
    },
    composition = '''
        let frontend = new app:frontend { ... };
        let backend = new app:backend { ... };
        connect frontend.request -> backend.handler;
        export frontend as main;
    ''',
)
```

## Features

### Language Support
- **Rust** (1.90.0+): Multi-profile builds, Clippy integration, Wizer pre-initialization
- **Go** (TinyGo 0.39.0): Native WASI Preview 2, hermetic Go module resolution
- **C++** (WASI SDK 27): C++17/20/23, cross-package headers, LTO optimization
- **JavaScript/TypeScript** (jco 1.4.0, Node.js 20.18.0): NPM dependencies, componentize-js

### Production Features
- **WAC Composition**: Official WebAssembly Composition standard for multi-component systems
- **OCI Publishing**: Push components to Docker/OCI registries
- **Cryptographic Signing**: wasmsign2 integration for supply chain security
- **AOT Compilation**: Wasmtime precompilation for 87% size reduction and faster startup
- **Wizer Pre-initialization**: 1.35-6x startup improvement for Rust components
- **Multi-Profile Builds**: Debug, release, and custom optimization profiles

### Developer Experience
- **Hermetic Toolchains**: All tools downloaded automatically, no system dependencies
- **Cross-Platform**: Native Windows/macOS/Linux support without WSL
- **Comprehensive Examples**: 20+ working examples from basic to advanced patterns

## Toolchain Versions

**See [MODULE.bazel](MODULE.bazel) for current versions** — the single source of truth.

All toolchains are hermetically downloaded and version-pinned for reproducible builds.

## Documentation

**[Complete Rule Reference](docs/rules.md)** — All rules, attributes, and providers

**Guides:**
- [Toolchain Configuration](docs/toolchain_configuration.md)
- [Multi-Profile Builds](docs/multi_profile.md)
- [Development Guidelines](CLAUDE.md)

**Examples:**
- [Basic Component](examples/basic/)
- [Multi-Language Composition](examples/multi_language_composition/)
- [Wizer Pre-initialization](examples/wizer_example/)
- [OCI Publishing](examples/oci_publishing/)
- [See all examples](examples/)

## Known Limitations

### Go WIT Components (Temporary)
- WIT-enabled Go components currently fail due to upstream TinyGo limitations
- Tracking: [Issue #82](https://github.com/pulseengine/rules_wasm_component/issues/82)
- Basic Go components (without WIT) work perfectly

### C++ Exception Handling
- WASI disables C++ exceptions by default for size/performance
- Use `enable_exceptions = True` for components that require exceptions ([Issue #83](https://github.com/pulseengine/rules_wasm_component/issues/83))

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Apache-2.0 &mdash; see [LICENSE](LICENSE).

---

<div align="center">

<sub>Part of <a href="https://github.com/pulseengine">PulseEngine</a> &mdash; formally verified WebAssembly toolchain for safety-critical systems</sub>

</div>
