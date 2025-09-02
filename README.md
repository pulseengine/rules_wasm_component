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

## Known Limitations

### Go WIT Components (Temporary)
- **Issue**: WIT-enabled Go components currently fail due to upstream TinyGo limitations
- **Tracking**: [GitHub Issue #82](https://github.com/pulseengine/rules_wasm_component/issues/82)
- **Status**: Excluded from CI until [TinyGo PR #4934](https://github.com/tinygo-org/tinygo/pull/4934) lands
- **Workaround**: Basic Go components (without WIT) work perfectly

### C++ Exception Handling
- **Design**: WASI disables C++ exceptions by default for size/performance
- **Solution**: Components use error codes instead of exceptions ([Issue #83](https://github.com/pulseengine/rules_wasm_component/issues/83))
- **Override**: Use `enable_exceptions = True` for components that require exceptions

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
