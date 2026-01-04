---
title: Lazy Toolchain Loading
description: Download only what you need - reduce first-build time from 10+ minutes to under 2 minutes
---

## The Problem

By default, rules_wasm_component downloads all toolchains for all supported languages. This means your first build downloads approximately **900MB** of toolchains:

- wasm-tools, wasmtime, wkg: ~50MB (always needed)
- TinyGo for Go: ~500MB
- WASI SDK for C++: ~300MB
- Node.js/JCO for JavaScript: ~100MB

**Result:** First build can take **10+ minutes** even for a simple Rust-only project.

## The Solution: Language-Specific Extensions

Use language-specific extensions to download only what you need:

| Extension | Downloads | Size | Use Case |
|-----------|-----------|------|----------|
| `rust_wasm` | Core tools only | ~50MB | Rust-only projects |
| `go_wasm` | + TinyGo | +500MB | Add Go support |
| `cpp_wasm` | + WASI SDK | +300MB | Add C++ support |
| `js_wasm` | + Node.js/JCO | +100MB | Add JavaScript support |
| `all_wasm` | Everything | ~900MB | Multi-language projects |

## Quick Start: Rust-Only Setup

Replace your current MODULE.bazel toolchain setup with:

```python title="MODULE.bazel"
module(
    name = "my_project",
    version = "1.0.0",
)

bazel_dep(name = "rules_wasm_component", version = "1.0.0")
bazel_dep(name = "rules_rust", version = "0.68.1")
bazel_dep(name = "bazel_skylib", version = "1.8.2")
bazel_dep(name = "platforms", version = "1.0.0")

# Rust toolchain (standard setup)
rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
rust.toolchain(
    edition = "2021",
    extra_target_triples = ["wasm32-wasip1", "wasm32-wasip2"],
    versions = ["1.91.1"],
)
use_repo(rust, "rust_toolchains")
register_toolchains("@rust_toolchains//:all")

# LAZY LOADING: Only core WASM tools (~50MB instead of ~900MB)
rust_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "rust_wasm",
)
rust_wasm.configure()
use_repo(
    rust_wasm,
    "wasm_tools_toolchains",
    "wasmtime_toolchain",
    "wkg_toolchain",
    # WASI WIT definitions
    "wasi_cli",
    "wasi_io",
)

register_toolchains(
    "@wasm_tools_toolchains//:wasm_tools_toolchain",
    "@wasmtime_toolchain//:wasmtime_toolchain",
    "@wkg_toolchain//:wkg_toolchain_def",
)
```

**Result:** First build completes in **under 2 minutes** instead of 10+.

## Adding Languages Incrementally

### Add Go Support

When you need Go components, add the `go_wasm` extension:

```python title="MODULE.bazel"
# Add rules_go dependency
bazel_dep(name = "rules_go", version = "0.59.0")

go_sdk = use_extension("@rules_go//go:extensions.bzl", "go_sdk")
go_sdk.download(version = "1.25.2")
use_repo(go_sdk, "go_toolchains")
register_toolchains("@go_toolchains//:all")

# Add TinyGo for WASM components (+500MB)
go_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "go_wasm",
)
go_wasm.configure()
use_repo(go_wasm, "tinygo_toolchain")
register_toolchains("@tinygo_toolchain//:tinygo_toolchain_def")
```

### Add C++ Support

When you need C++ components:

```python title="MODULE.bazel"
bazel_dep(name = "rules_cc", version = "0.2.14")

# Add WASI SDK for C++ WASM components (+300MB)
cpp_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "cpp_wasm",
)
cpp_wasm.configure()
use_repo(cpp_wasm, "wasi_sdk", "cpp_toolchain")
register_toolchains(
    "@wasi_sdk//:wasi_sdk_toolchain",
    "@wasi_sdk//:cc_toolchain",
    "@cpp_toolchain//:cpp_component_toolchain",
)
```

### Add JavaScript Support

When you need JavaScript/TypeScript components:

```python title="MODULE.bazel"
bazel_dep(name = "rules_nodejs", version = "6.5.0")

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node")
node.toolchain(node_version = "20.18.0")
use_repo(node, "nodejs_toolchains")
register_toolchains("@nodejs_toolchains//:all")

# Add JCO for JavaScript WASM components (+100MB)
js_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "js_wasm",
)
js_wasm.configure()
use_repo(js_wasm, "jco_toolchain")
register_toolchains("@jco_toolchain//:jco_toolchain")
```

## Full Multi-Language Setup

If you need all languages, use the `all_wasm` extension for simplicity:

```python title="MODULE.bazel"
all_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "all_wasm",
)
all_wasm.configure()
use_repo(
    all_wasm,
    # Core
    "wasm_tools_toolchains",
    "wasmtime_toolchain",
    "wkg_toolchain",
    # Go
    "tinygo_toolchain",
    # C++
    "wasi_sdk",
    "cpp_toolchain",
    # JavaScript
    "jco_toolchain",
)
```

## Version Configuration

Each extension accepts optional version parameters:

```python title="MODULE.bazel"
rust_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "rust_wasm",
)
rust_wasm.configure(
    wasm_tools_version = "1.243.0",
    wasmtime_version = "39.0.1",
    wkg_version = "0.13.0",
)
```

```python title="MODULE.bazel"
go_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "go_wasm",
)
go_wasm.configure(
    tinygo_version = "0.40.1",
)
```

## Comparison: Before vs After

### Before (All Toolchains)

```
First build: 10+ minutes
Download: ~900MB
- wasm-tools: 30MB
- wasmtime: 15MB
- wkg: 10MB
- TinyGo: 500MB
- WASI SDK: 300MB
- Node.js: 60MB
- JCO: 40MB
```

### After (Rust-Only)

```
First build: < 2 minutes
Download: ~50MB
- wasm-tools: 30MB
- wasmtime: 15MB
- wkg: 10MB
```

**Savings:** 850MB download, 8+ minutes build time

## Migration Guide

### From Legacy Extensions

If you're using the old extension style:

```python title="Before (legacy)"
wasm_toolchain = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_toolchain")
wasi_sdk = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasi_sdk")
tinygo = use_extension("@rules_wasm_component//wasm:extensions.bzl", "tinygo")
jco = use_extension("@rules_wasm_component//wasm:extensions.bzl", "jco")
```

Replace with language-specific extensions:

```python title="After (lazy)"
rust_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "rust_wasm")
go_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "go_wasm")
cpp_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "cpp_wasm")
js_wasm = use_extension("@rules_wasm_component//wasm:language_extensions.bzl", "js_wasm")
```

## CI/CD Optimization

Lazy loading significantly improves CI build times:

```yaml title=".github/workflows/build.yml"
jobs:
  rust-components:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Rust components
        run: bazel build //rust/...
        # Only downloads ~50MB of toolchains

  go-components:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Go components
        run: bazel build //go/...
        # Downloads ~550MB (core + TinyGo)
```

## Troubleshooting

### "Repository not found" Errors

Make sure you've added all required repos to `use_repo()`:

```python
use_repo(
    rust_wasm,
    "wasm_tools_toolchains",  # Required
    "wasmtime_toolchain",     # Required
    "wkg_toolchain",          # Required
    # Add WASI WIT repos you need:
    "wasi_cli",
    "wasi_io",
)
```

### Missing Toolchain Errors

If you get "no matching toolchain" errors, ensure you've called `register_toolchains()`:

```python
register_toolchains(
    "@wasm_tools_toolchains//:wasm_tools_toolchain",
    "@wasmtime_toolchain//:wasmtime_toolchain",
    "@wkg_toolchain//:wkg_toolchain_def",
)
```

### Legacy Extension Conflicts

Don't mix legacy and lazy extensions. Choose one approach:

```python
# BAD: Mixing approaches
wasm_toolchain = use_extension("...extensions.bzl", "wasm_toolchain")  # Legacy
rust_wasm = use_extension("...language_extensions.bzl", "rust_wasm")   # New

# GOOD: One approach only
rust_wasm = use_extension("...language_extensions.bzl", "rust_wasm")
```

## Next Steps

- [First Component Tutorial](/first-component/) - Build your first component
- [Rust Language Guide](/languages/rust/) - Deep dive into Rust components
- [Toolchain Configuration](/guides/toolchain-configuration/) - Advanced configuration
