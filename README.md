# Bazel Rules for WebAssembly Component Model

Modern Bazel rules for building WebAssembly components across multiple languages.

## Why Use This?

- **Multi-language**: Build components from Rust, Go, C++, JavaScript
- **Production Ready**: OCI publishing, signing, composition, optimization  
- **Bazel Native**: Hermetic builds, caching, cross-platform support

## Installation

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

## Quick Example

```starlark
# Build a component from Rust
rust_wasm_component_bindgen(
    name = "hello_component", 
    srcs = ["src/lib.rs"],
    wit = ":hello_interfaces",
)
```

## Documentation

📚 **[Complete Documentation →](https://github.com/pulseengine/rules_wasm_component/tree/main/docs-site)**

- **[Zero to Component in 2 Minutes](/docs-site/src/content/docs/zero-to-component.mdx)** - Fastest way to get started
- **[Language Guides](/docs-site/src/content/docs/languages/)** - Rust, Go, C++, JavaScript tutorials  
- **[Production Deployment](/docs-site/src/content/docs/production/)** - OCI publishing, signing, optimization
- **[Examples](examples/)** - Working examples from basic to advanced

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
