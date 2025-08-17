---
title: Installation
description: Complete installation guide for rules_wasm_component
---

## Why Choose WebAssembly Components?

Before diving into installation, let's understand what makes WebAssembly components compelling for modern software development.

**Real-world use cases:**

- **Microservices without containers** - Deploy lightweight, fast-starting services
- **Plugin architectures** - Safely run third-party code in your applications
- **Edge computing** - Run the same code on CDN edges, servers, and IoT devices
- **Multi-language projects** - Use the best language for each problem domain
- **Legacy modernization** - Gradually migrate existing systems with component wrappers

**Benefits over traditional approaches:**

- **Faster than containers** - Sub-millisecond startup times vs seconds for containers
- **Smaller than binaries** - Typical components are 1-5MB vs 50-500MB container images
- **More secure than shared libraries** - Complete isolation with explicit interfaces
- **More portable than native code** - Write once, run on any architecture

**Perfect for teams that want:**

- Language diversity without operational complexity
- High performance without sacrificing security
- True portability across environments
- Easy testing and composition of services

## Installation Guide

Set up WebAssembly Component Model rules in your Bazel project.

## Prerequisites

Before installing rules_wasm_component, ensure you have:

- **Bazelisk** (recommended) - Automatically manages Bazel versions
- **Git** - For repository management
- **Internet connection** - For downloading toolchains

### Installing Bazelisk (Recommended)

Bazelisk automatically downloads and uses the correct Bazel version for your project. It reads the `.bazelversion` file in your project root to determine which Bazel version to use:

```bash
# macOS (Homebrew)
brew install bazelisk

# macOS/Linux (Manual)
curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-darwin-amd64 -o /usr/local/bin/bazel
chmod +x /usr/local/bin/bazel

# Windows (Chocolatey)
choco install bazelisk

# NPM (Cross-platform)
npm install -g @bazel/bazelisk

# Go install
go install github.com/bazelbuild/bazelisk@latest
```

**Why Bazelisk is Better:**

- **Automatic version management** - No manual Bazel updates needed
- **Project-specific versions** - Each project can use its required Bazel version
- **Team consistency** - Everyone uses the same Bazel version automatically
- **CI/CD friendly** - Consistent builds across environments

**Setting up .bazelversion:**
Create a `.bazelversion` file in your project root:

```text title=".bazelversion"
8.3.1
```

Bazelisk will automatically download and use this exact version.

### Alternative: Direct Bazel Installation

If you prefer to install Bazel directly:

- **Bazel 8.0 or later** - [Install Bazel](https://bazel.build/install)
- **Recommended version: 8.3.1** - Current version used by this project

The following tools will be automatically downloaded and managed by Bazel:

- **wasm-tools** - WebAssembly toolchain
- **wit-bindgen** - Interface binding generator
- **Language-specific toolchains** (Rust, TinyGo, WASI SDK, jco)

## Basic Installation

### 1. Add Dependency to MODULE.bazel

Add the following to your `MODULE.bazel` file:

```python title="MODULE.bazel"
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

### 2. Configure Toolchains (Optional)

You can optionally configure specific versions of the WebAssembly toolchains:

```python title="MODULE.bazel"
# Configure WASM tools version
wasm_toolchain = use_extension(
    "@rules_wasm_component//wasm:extensions.bzl",
    "wasm_toolchain",
)
wasm_toolchain.register(
    name = "wasm_tools",
    strategy = "download",  # Default: hermetic builds
    version = "1.235.0",    # Pin specific version
)
```

> **💡 Need advanced configuration?** See the [Toolchain Configuration Guide](/guides/toolchain-configuration/) for strategies, version management, CI/CD setup, and corporate environments.

## Language-Specific Setup

### Rust Configuration

For Rust WebAssembly components, add rules_rust and configure dependencies:

```python title="MODULE.bazel"
bazel_dep(name = "rules_rust", version = "0.62.0")

# Git override for WASI Preview 2 support
git_override(
    module_name = "rules_rust",
    commit = "7d7d3ac00ad013c94e7a9d0db0732c20ffe8eab7",
    remote = "https://github.com/bazelbuild/rules_rust.git",
)

# Configure Rust crate dependencies
crate = use_extension("@rules_rust//crate_universe:extension.bzl", "crate")
crate.from_cargo(
    name = "crates",
    cargo_lockfile = "//:Cargo.lock",
    manifests = ["//:Cargo.toml"],
)
use_repo(crate, "crates")
```

Create a `Cargo.toml` file in your project root:

```toml title="Cargo.toml"
[package]
name = "my-wasm-components"
version = "0.1.0"
edition = "2021"

[dependencies]
wit-bindgen = { version = "0.30.0", default-features = false, features = ["realloc"] }
```

Generate the lockfile:

```bash
cargo generate-lockfile
```

### Go Configuration

For Go components using TinyGo:

```python title="MODULE.bazel"
# Configure TinyGo toolchain
tinygo = use_extension("@rules_wasm_component//wasm:extensions.bzl", "tinygo")
tinygo.register(
    name = "tinygo",
    tinygo_version = "0.38.0",  # Optional, defaults to 0.38.0
)
```

### C++ Configuration

For C++ components using WASI SDK:

```python title="MODULE.bazel"
# Configure WASI SDK toolchain
wasi_sdk = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasi_sdk")
wasi_sdk.register(
    name = "wasi_sdk",
    version = "25",  # Optional, defaults to latest stable
)
```

### JavaScript Configuration

For JavaScript/TypeScript components:

```python title="MODULE.bazel"
# Configure jco (JavaScript Component Tools)
jco = use_extension("@rules_wasm_component//wasm:extensions.bzl", "jco")
jco.register(
    strategy = "npm",  # or "download"
    version = "1.4.0",  # Optional for npm/download strategies
)
```

## Complete Example MODULE.bazel

Here's a complete example that sets up all language support:

```python title="MODULE.bazel"
module(
    name = "my_wasm_project",
    version = "1.0.0",
)

# Core dependencies
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
bazel_dep(name = "rules_rust", version = "0.62.0")

# Git override for WASI Preview 2 support
git_override(
    module_name = "rules_rust",
    commit = "7d7d3ac00ad013c94e7a9d0db0732c20ffe8eab7",
    remote = "https://github.com/bazelbuild/rules_rust.git",
)

# WebAssembly toolchain configuration
wasm_toolchain = use_extension(
    "@rules_wasm_component//wasm:extensions.bzl",
    "wasm_toolchain",
)
wasm_toolchain.register(
    name = "wasm_tools",
    version = "1.0.60",
)
wasm_toolchain.register(
    name = "wit_bindgen",
    version = "0.30.0",
)

# TinyGo for Go components
tinygo = use_extension("@rules_wasm_component//wasm:extensions.bzl", "tinygo")
tinygo.register(
    name = "tinygo",
    tinygo_version = "0.38.0",
)

# WASI SDK for C++ components
wasi_sdk = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasi_sdk")
wasi_sdk.register(
    name = "wasi_sdk",
    version = "25",
)

# jco for JavaScript components
jco = use_extension("@rules_wasm_component//wasm:extensions.bzl", "jco")
jco.register(
    strategy = "npm",
    version = "1.4.0",
)

# Rust crate dependencies
crate = use_extension("@rules_rust//crate_universe:extension.bzl", "crate")
crate.from_cargo(
    name = "crates",
    cargo_lockfile = "//:Cargo.lock",
    manifests = ["//:Cargo.toml"],
)
use_repo(crate, "crates")
```

## Verification

After installation, verify everything is working:

### 1. Test Toolchain Setup

```bash
# Verify Bazel can load the rules
bazel query '@rules_wasm_component//...' >/dev/null

# Check toolchain availability
bazel build @wasm_tools//:all --dry_run
bazel build @wit_bindgen//:all --dry_run
```

### 2. Create a Test Component

Create a simple test to verify installation:

```python title="test/BUILD.bazel"
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "test_interfaces",
    srcs = ["test.wit"],
    package_name = "test:example@1.0.0",
)
```

```wit title="test/test.wit"
package test:example@1.0.0;

world test {
    export test: func() -> string;
}
```

```bash
# Build the test
bazel build //test:test_interfaces
```

### 3. Run Examples

Test with the provided examples:

```bash
# Build basic example
bazel build @rules_wasm_component//examples/basic:basic_component

# Run tests
bazel test @rules_wasm_component//test/...
```

## Troubleshooting

### Common Issues

**Bazel version too old:**

```bash
# Check Bazel version
bazel --version

# Should be 7.0 or later
# Upgrade if necessary: https://bazel.build/install
```

**Network connectivity issues:**

```bash
# Test with verbose output
bazel build //... --verbose_failures

# Check proxy settings if behind corporate firewall
bazel build //... --experimental_repository_cache_urls_as_default_canonical_id
```

**Platform not supported:**

```bash
# Check current platform
bazel info

# Verify platform constraints
bazel query '@platforms//...'
```

**Memory issues during build:**

```bash
# Increase Bazel memory limits
bazel build //... --local_ram_resources=8192
```

### Getting Help

If you encounter issues:

1. **Check logs**: Use `--verbose_failures` for detailed error messages
2. **Search issues**: Look at [GitHub Issues](https://github.com/pulseengine/rules_wasm_component/issues)
3. **Ask questions**: Use [GitHub Discussions](https://github.com/pulseengine/rules_wasm_component/discussions)
4. **Update rules**: Ensure you're using the latest version

## Next Steps

With rules_wasm_component installed, you're ready to:

1. **[Create your first component](/first-component/)** - Build a simple WebAssembly component
2. **[Choose your language](/languages/rust/)** - Pick from Rust, Go, C++, or JavaScript
3. **[Explore examples](/examples/basic/)** - See working examples in action
4. **[Learn composition](/composition/wac/)** - Build multi-component systems

## Version Compatibility

| rules_wasm_component | Bazel | wasm-tools | wit-bindgen |
|---------------------|-------|------------|-------------|
| 1.0.x               | 7.0+  | 1.0.60+    | 0.30.0+     |
| 0.9.x               | 6.0+  | 1.0.50+    | 0.25.0+     |
| 0.8.x               | 6.0+  | 1.0.40+    | 0.20.0+     |

Always use the latest stable version for the best experience and newest features.
