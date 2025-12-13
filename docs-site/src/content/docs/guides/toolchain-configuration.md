---
title: Toolchain Configuration Guide
description: Complete guide to configuring WebAssembly toolchains for your project needs
---

# Toolchain Configuration Guide

Learn how to configure toolchain strategies, versions, and settings for optimal builds in different environments.

## Quick Configuration Reference

### Hermetic Builds (Default - Recommended)

```python title="MODULE.bazel"
# Downloads specific versions for reproducible builds
wasm_toolchain = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_toolchain")
wasm_toolchain.register(
    strategy = "download",  # Default - downloads prebuilt binaries
    version = "1.235.0",    # Pin specific version
)
```

### Latest Development

```python title="MODULE.bazel"
# Builds from source for bleeding-edge features
wasm_toolchain.register(
    strategy = "build",
    git_commit = "main",    # or specific commit/tag
)
```

### Hybrid Approach (Best Performance)

```python title="MODULE.bazel"
# Bazel-native builds with git repositories
wasm_toolchain.register(
    strategy = "hybrid",    # Combines benefits of build + download
    version = "1.235.0",
)
```

### Corporate/Air-gapped Environments

```python title="MODULE.bazel"
# Custom mirrors for restricted networks
wasm_toolchain.register(
    strategy = "download",
    version = "1.235.0",
    wasm_tools_url = "https://internal-mirror.corp.com/wasm-tools-1.235.0.tar.gz",
    wac_url = "https://internal-mirror.corp.com/wac-0.7.0.tar.gz",
    wit_bindgen_url = "https://internal-mirror.corp.com/wit-bindgen-0.43.0.tar.gz",
)
```

## Strategy Selection Guide

### Available Strategies by Toolchain

| Toolchain       | download | build | hybrid | npm | cargo |
| --------------- | -------- | ----- | ------ | --- | ----- |
| wasm_toolchain  | ✅       | ✅    | ✅     | ❌  | ❌    |
| wasi_sdk        | ✅       | ❌    | ❌     | ❌  | ❌    |
| wkg_toolchain   | ✅       | ✅    | ❌     | ❌  | ❌    |
| jco_toolchain   | ✅       | ❌    | ❌     | ✅  | ❌    |
| cpp_component   | ✅       | ✅    | ❌     | ❌  | ❌    |
| wasmtime        | ✅       | ❌    | ❌     | ❌  | ❌    |

> **Note:** Wizer functionality is now included in wasmtime v39.0.0+ via the `wasmtime wizer` subcommand.
> No separate wizer_toolchain is required.

### When to Use Each Strategy

#### `"download"` (Default) - Hermetic & Fast

**Best for:** Production builds, CI/CD, team consistency

```python title="MODULE.bazel"
wasm_toolchain.register(
    strategy = "download",
    version = "1.235.0",  # Pinned version for reproducibility
)
```

**Pros:**

- **Fast builds** - No compilation required
- ✅ **Reproducible** - Same binaries across all environments
- 🔒 **Hermetic** - No system dependencies
- **Cross-platform** - Works on all supported platforms

**Cons:**

- **Limited versions** - Only published releases available
- **Network dependency** - Initial download required

#### `"build"` - Latest Features

**Best for:** Development, unreleased features, custom patches

```python title="MODULE.bazel"
wasm_toolchain.register(
    strategy = "build",
    git_commit = "main",           # Latest development
    # git_commit = "v1.235.0",     # Specific release
    # git_commit = "abc123def",    # Specific commit
)
```

**Pros:**

- **Latest features** - Access to unreleased functionality
- **Customizable** - Can apply patches or modifications
- **Up-to-date** - Always current with upstream

**Cons:**

- **Slow builds** - Requires Rust compilation
- ⚠️ **Less stable** - Development versions may have issues
- **Build dependencies** - Requires Rust toolchain

#### `"hybrid"` - Best of Both Worlds

**Best for:** Projects wanting fast builds with Bazel-native approach

```python title="MODULE.bazel"
wasm_toolchain.register(
    strategy = "hybrid",
    version = "1.235.0",
)
```

**Pros:**

- **Fast** - Combines git repositories with genrules
- ✅ **Bazel-native** - Uses repository rules properly
- **Balanced** - Good performance and flexibility

**Cons:**

- **Complex** - More sophisticated build process
- **Limited toolchains** - Only available for wasm_toolchain

#### `"npm"` - JavaScript Ecosystem

**Best for:** Projects already using Node.js/npm

```python title="MODULE.bazel"
jco = use_extension("@rules_wasm_component//wasm:extensions.bzl", "jco")
jco.register(
    strategy = "npm",      # Uses npm install
    version = "1.4.0",     # npm package version
)
```

**Pros:**

- **Node.js integration** - Natural for JS projects
- **npm ecosystem** - Standard package management
- **Version control** - npm's semantic versioning

**Cons:**

- **Node.js required** - System dependency
- **JCO only** - Limited to JavaScript Component Tools

#### `"cargo"` - Rust Ecosystem

**Best for:** Rust-heavy projects building from source

```python title="MODULE.bazel"
# Example: building wasm-tools from source via cargo
wasm_toolchain = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_toolchain")
wasm_toolchain.register(
    strategy = "cargo",    # Uses cargo install
    version = "1.243.0",
)
```

**Pros:**

- **Rust native** - Uses cargo install
- **Flexible** - Can install with specific features
- **Version pinning** - Exact version control

**Cons:**

- **Rust required** - System dependency
- **Compilation time** - Builds from source
- **Limited toolchains** - Not all toolchains support cargo strategy

> **Note:** The standalone wizer toolchain has been removed. Wizer is now part of wasmtime v39.0.0+ and available via the `wasmtime wizer` subcommand.

## Performance Comparison

| Strategy | Initial Build | Incremental | Disk Usage | Network     | Use Case          |
| -------- | ------------- | ----------- | ---------- | ----------- | ----------------- |
| download | Fast (30s)    | Fast        | Small      | One-time    | **Production**    |
| build    | Slow (5-10m)  | Medium      | Large      | One-time    | **Development**   |
| hybrid   | Medium (2m)   | Fast        | Medium     | One-time    | **Best balance**  |
| npm      | Fast (1m)     | Fast        | Small      | Per package | **JS projects**   |
| cargo    | Slow (3-5m)   | Medium      | Large      | One-time    | **Rust projects** |

## Version Management

### Pinning Strategy Versions

Always pin versions in production environments for reproducible builds:

```python title="MODULE.bazel - Production"
# Pin all toolchain versions
wasm_toolchain.register(name = "wasm_tools", strategy = "download", version = "1.235.0")
wasi_sdk.register(name = "wasi_sdk", strategy = "download", version = "25")
wkg.register(name = "wkg", strategy = "download", version = "0.11.0")
jco.register(name = "jco", strategy = "npm", version = "1.4.0")
tinygo.register(name = "tinygo", tinygo_version = "0.38.0")
```

### Development vs Production

Use different configurations for different environments:

```python title="MODULE.bazel - Development"
# Development: latest features
wasm_toolchain.register(
    name = "dev_tools",
    strategy = "build",
    git_commit = "main",
)

# Production: stable releases
wasm_toolchain.register(
    name = "prod_tools",
    strategy = "download",
    version = "1.235.0",
)
```

Then select the appropriate toolchain:

```bash
# Development builds
bazel build --extra_toolchains=@dev_tools_toolchains//:wasm_tools_toolchain //...

# Production builds
bazel build --extra_toolchains=@prod_tools_toolchains//:wasm_tools_toolchain //...
```

### Version Compatibility Matrix

Always check compatibility when upgrading:

| rules_wasm_component | wasm-tools | wit-bindgen | wac    | TinyGo | WASI SDK |
| -------------------- | ---------- | ----------- | ------ | ------ | -------- |
| 1.0.x                | 1.235.0+   | 0.43.0+     | 0.7.0+ | 0.38.0 | 25+      |
| 0.9.x                | 1.220.0+   | 0.40.0+     | 0.6.0+ | 0.37.0 | 24+      |
| 0.8.x                | 1.200.0+   | 0.35.0+     | 0.5.0+ | 0.36.0 | 23+      |

## Environment-Specific Configuration

### CI/CD Environments

#### GitHub Actions (Recommended)

```yaml title=".github/workflows/ci.yml"
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build with Bazel
        run: |
          # Uses download strategy by default - no tool installation needed
          bazel build //...
          bazel test //...
```

```python title="MODULE.bazel - CI"
# CI configuration - fast, hermetic builds
wasm_toolchain.register(strategy = "download", version = "1.235.0")
wasi_sdk.register(strategy = "download", version = "25")
```

#### GitLab CI

```yaml title=".gitlab-ci.yml"
image: gcr.io/bazel-public/bazel:latest

build:
  script:
    - bazel build //...
    - bazel test //...
  cache:
    paths:
      - ~/.cache/bazel
```

#### Jenkins

```groovy title="Jenkinsfile"
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'bazel build //...'
                sh 'bazel test //...'
            }
        }
    }
}
```

### Docker Builds

For containerized builds, use download strategy for hermetic builds:

```dockerfile title="Dockerfile"
FROM ubuntu:22.04

# Install Bazelisk
RUN apt-get update && apt-get install -y curl
RUN curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 -o /usr/local/bin/bazel
RUN chmod +x /usr/local/bin/bazel

# Copy source
COPY . /workspace
WORKDIR /workspace

# Build (tools downloaded automatically)
RUN bazel build //...
```

```python title="MODULE.bazel - Docker"
# Docker-optimized configuration
wasm_toolchain.register(strategy = "download", version = "1.235.0")
# No system dependencies required
```

### Corporate/Air-gapped Environments

#### Option 1: Internal Mirrors

```python title="MODULE.bazel - Corporate"
wasm_toolchain.register(
    strategy = "download",
    version = "1.235.0",
    wasm_tools_url = "https://artifacts.corp.com/wasm-tools/1.235.0/wasm-tools.tar.gz",
    wac_url = "https://artifacts.corp.com/wac/0.7.0/wac.tar.gz",
    wit_bindgen_url = "https://artifacts.corp.com/wit-bindgen/0.43.0/wit-bindgen.tar.gz",
)
```

#### Option 2: Vendored Dependencies

```python title="MODULE.bazel - Vendored"
# Use local copies for air-gapped environments
http_archive(
    name = "wasm_tools_vendor",
    urls = ["file:///path/to/vendored/wasm-tools.tar.gz"],
    sha256 = "...",
)
```

### macOS Development

```python title="MODULE.bazel - macOS"
# Optimized for macOS development
wasm_toolchain.register(
    strategy = "hybrid",    # Best performance on macOS
    version = "1.235.0",
)

tinygo.register(
    name = "tinygo",
    tinygo_version = "0.38.0",
)
```

### Windows Development

```python title="MODULE.bazel - Windows"
# Windows-specific configuration
wasm_toolchain.register(
    strategy = "download",  # Most reliable on Windows
    version = "1.235.0",
)

# Note: Build strategy may require additional setup on Windows
```

## Advanced Configuration

### Custom Tool Versions

Mix and match tool versions for specific needs:

```python title="MODULE.bazel - Custom"
wasm_toolchain = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_toolchain")

# Use latest wasm-tools but older wit-bindgen for compatibility
wasm_toolchain.register(
    name = "custom_tools",
    strategy = "download",
    version = "1.235.0",           # Latest wasm-tools
    wit_bindgen_commit = "v0.40.0", # Older wit-bindgen
)
```

### Performance Optimization

#### Build Caching

```bash
# Enable remote caching for faster builds
bazel build //... --remote_cache=grpc://build-cache.company.com:9092
```

#### Parallel Downloads

```bash
# Increase parallelism for faster tool downloads
bazel build //... --jobs=auto --local_ram_resources=8192
```

#### Wizer Pre-initialization

For faster component startup, use wasmtime's built-in wizer functionality (v39.0.0+):

```python title="MODULE.bazel - Performance"
# Wizer is included in wasmtime v39.0.0+
# No separate wizer toolchain required - uses `wasmtime wizer` subcommand
wasmtime = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasmtime")
wasmtime.register(
    strategy = "download",
    version = "39.0.1",  # Includes wizer functionality
)
```

> **Note:** The init function name has changed from `wizer.initialize` to `wizer-initialize` in wasmtime's wizer.

## Troubleshooting

### Common Issues

#### "Download failed" Errors

**Problem:** Tool downloads failing due to network issues

**Solutions:**

1. **Check connectivity:**

   ```bash
   # Test download manually
   curl -I https://github.com/bytecodealliance/wasm-tools/releases/download/v1.235.0/wasm-tools-1.235.0-x86_64-linux.tar.gz
   ```

2. **Use custom URLs:**

   ```python title="MODULE.bazel"
   wasm_toolchain.register(
       strategy = "download",
       wasm_tools_url = "https://internal-mirror.com/wasm-tools.tar.gz",
   )
   ```

3. **Switch to build strategy:**

   ```python title="MODULE.bazel"
   wasm_toolchain.register(strategy = "build", git_commit = "v1.235.0")
   ```

#### "Platform not supported" Errors

**Problem:** Tool not available for your platform

**Solutions:**

1. **Check supported platforms:**

   ```bash
   bazel query '@wasm_tools_toolchains//...' --output=build
   ```

2. **Use build strategy:**

   ```python title="MODULE.bazel"
   # Build from source works on all platforms
   wasm_toolchain.register(strategy = "build", git_commit = "main")
   ```

#### Version Conflicts

**Problem:** Tool versions incompatible with each other

**Solutions:**

1. **Check compatibility matrix** (see above)
2. **Pin compatible versions:**

   ```python title="MODULE.bazel"
   # Known working combination
   wasm_toolchain.register(strategy = "download", version = "1.235.0")
   # wit-bindgen 0.43.0 is compatible with wasm-tools 1.235.0
   ```

#### Build Strategy Failures

**Problem:** Build from source failing

**Solutions:**

1. **Check Rust installation:**

   ```bash
   rustc --version  # Should be 1.70+
   cargo --version
   ```

2. **Increase build resources:**

   ```bash
   bazel build //... --local_ram_resources=8192 --jobs=4
   ```

3. **Switch to download strategy:**

   ```python title="MODULE.bazel"
   wasm_toolchain.register(strategy = "download", version = "1.235.0")
   ```

### Debug Commands

```bash
# Check toolchain resolution
bazel query '@wasm_tools_toolchains//...'

# Verbose build output
bazel build //... --verbose_failures --subcommands

# Check tool versions
bazel run @wasm_tools_toolchains//:wasm_tools -- --version
bazel run @wit_bindgen_toolchains//:wit_bindgen -- --version

# Clean and rebuild toolchains
bazel clean --expunge
bazel sync
bazel build //...
```

## Migration Guide

### From System Tools to Hermetic

**Before:**

```bash
# Manual tool installation
cargo install wasm-tools wac-cli wit-bindgen-cli
```

**After:**

```python title="MODULE.bazel"
# Automatic tool management
wasm_toolchain.register(strategy = "download", version = "1.235.0")
```

### Upgrading Tool Versions

1. **Check changelog** for breaking changes
2. **Update gradually:**

   ```python title="MODULE.bazel"
   # Test new version
   wasm_toolchain.register(name = "test_tools", strategy = "download", version = "1.240.0")
   wasm_toolchain.register(name = "stable_tools", strategy = "download", version = "1.235.0")
   ```

3. **Validate with tests:**

   ```bash
   bazel test //... --extra_toolchains=@test_tools_toolchains//:wasm_tools_toolchain
   ```

4. **Update default** once validated

## Best Practices

### General Guidelines

1. **Always pin versions** in production
2. **Use download strategy** for CI/CD
3. **Test before upgrading** tool versions
4. **Document your configuration** for team members
5. **Keep toolchains updated** regularly but carefully

### Team Configuration

```python title="MODULE.bazel - Team Standard"
# Team-wide standard configuration
# Last updated: 2024-01-15
# Compatible with rules_wasm_component 1.0.x

wasm_toolchain.register(strategy = "download", version = "1.235.0")  # Stable
wasi_sdk.register(strategy = "download", version = "25")             # Latest
tinygo.register(tinygo_version = "0.38.0")                          # WASI P2 support
jco.register(strategy = "npm", version = "1.4.0")                   # Latest stable
```

### Version Update Schedule

- **Monthly:** Check for new stable releases
- **Quarterly:** Update to latest stable versions after testing
- **As needed:** Update for security fixes or critical bugs
- **Major versions:** Plan migration with full regression testing

## WIT Dependencies Configuration

For projects using external WIT (WebAssembly Interface Types) dependencies:

### Quick Setup

```python title="MODULE.bazel"
# Enable WASI WIT interfaces
wasi_wit_ext = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasi_wit")
wasi_wit_ext.init()
use_repo(wasi_wit_ext, "wasi_io")  # Add more as needed
```

### Available WASI Packages

| Package              | Repository      | Usage                       |
| -------------------- | --------------- | --------------------------- |
| `@wasi_io//:streams` | `wasi:io@0.2.3` | I/O streams, error handling |

### Using in WIT Files

```wit title="component.wit"
package example:my-component@1.0.0;

world my-world {
    import wasi:io/streams@0.2.3;  // Use external interface
    export my-api;
}
```

### Using in BUILD Files

```starlark title="BUILD.bazel"
wit_library(
    name = "my_component_wit",
    srcs = ["component.wit"],
    deps = ["@wasi_io//:streams"],  # Reference external dependency
)
```

> **📖 Complete Guide:** See [External WIT Dependencies](/guides/external-wit-dependencies/) for detailed setup instructions including custom external dependencies.

This configuration ensures your WebAssembly component builds are fast, reliable, and maintainable across different environments and team setups.
