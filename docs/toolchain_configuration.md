# Toolchain Configuration

The rules_wasm_component provides hermetic, cross-platform toolchains for WebAssembly component development. All toolchains use the **download strategy** by default for reproducible builds.

## Quick Start

```starlark
# MODULE.bazel - Default configuration (downloads all tools automatically)
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

That's it! All toolchains are pre-configured with current stable versions and will download automatically.

## Current Toolchain Versions

**See [MODULE.bazel](../MODULE.bazel) for current versions** - the single source of truth.

Version numbers change frequently. MODULE.bazel specifies the exact versions for:
- **wasm-tools**, **wit-bindgen** - Core WASM tooling
- **TinyGo**, **WASI SDK** - Language toolchains
- **Wasmtime**, **Wizer** - Runtime and optimization
- **wkg**, **jco**, **Node.js** - Package management and JavaScript
- **Rust**, **Go** - Language SDKs

## Platform Support

All toolchains support:
- **Linux**: x86_64, aarch64
- **macOS**: x86_64 (Intel), aarch64 (Apple Silicon)
- **Windows**: x86_64

No WSL required on Windows - all toolchains work natively.

## Toolchain Configuration

### WebAssembly Tools (wasm-tools, wit-bindgen, wac)

Default configuration (recommended):
```starlark
# MODULE.bazel - Uses current stable version
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

Custom version:
```starlark
wasm_toolchain = use_extension("//wasm:extensions.bzl", "wasm_toolchain")
wasm_toolchain.register(
    name = "wasm_tools",
    strategy = "download",
    version = "1.240.0",  # Or any other version
)
use_repo(wasm_toolchain, "wasm_tools_toolchains")
register_toolchains("@wasm_tools_toolchains//:wasm_tools_toolchain")
```

### TinyGo Toolchain

Default configuration (recommended):
```starlark
# MODULE.bazel - Included by default
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

Custom version:
```starlark
tinygo = use_extension("//wasm:extensions.bzl", "tinygo")
tinygo.register(
    name = "tinygo",
    tinygo_version = "0.39.0",  # Or any other version
)
use_repo(tinygo, "tinygo_toolchain")
register_toolchains("@tinygo_toolchain//:tinygo_toolchain_def")
```

**Features:**
- Native WASI Preview 2 support (`--target=wasip2`)
- Hermetic Go SDK (no system Go required for module resolution)
- wit-bindgen-go for interface bindings
- Binaryen (wasm-opt) for optimization

### WASI SDK Toolchain

Default configuration (recommended):
```starlark
# MODULE.bazel - Included by default
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

Custom version:
```starlark
wasi_sdk = use_extension("//wasm:extensions.bzl", "wasi_sdk")
wasi_sdk.register(
    name = "wasi",
    strategy = "download",
    version = "27",  # Or "26", "25", etc.
)
use_repo(wasi_sdk, "wasi_sdk")
register_toolchains(
    "@wasi_sdk//:wasi_sdk_toolchain",
    "@wasi_sdk//:cc_toolchain",
)
```

**Features:**
- C/C++ compilation to wasm32-wasip2
- LTO (Link-Time Optimization) support
- C++17/20/23 support
- clang, llvm-ar, wasm-ld toolchain

### Wasmtime Toolchain

Default configuration (recommended):
```starlark
# MODULE.bazel - Included by default
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

Custom version:
```starlark
wasmtime = use_extension("//wasm:extensions.bzl", "wasmtime")
wasmtime.register(
    name = "wasmtime",
    strategy = "download",
    version = "37.0.2",  # Or any other version
)
use_repo(wasmtime, "wasmtime_toolchain")
register_toolchains("@wasmtime_toolchain//:wasmtime_toolchain")
```

**Features:**
- WASM component runtime
- AOT compilation (`wasmtime compile`)
- Testing infrastructure (`wasm_test`, `wasm_run`)
- WASI Preview 2 support

### Wizer (Pre-initialization)

> **Note:** As of wasmtime v39.0.0 (November 2025), Wizer has been integrated into wasmtime
> and is available as the `wasmtime wizer` subcommand. No separate wizer toolchain is required.

Wizer pre-initialization is automatically available through the wasmtime toolchain:
```starlark
# MODULE.bazel - wasmtime toolchain includes wizer functionality
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

**Features:**
- Pre-initialization for 1.35-6x startup improvement
- Component model support
- WASI imports during initialization
- Uses `wasmtime wizer` subcommand (not standalone wizer binary)

### wkg Toolchain

Default configuration (recommended):
```starlark
# MODULE.bazel - Included by default
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

Custom version:
```starlark
wkg = use_extension("//wasm:extensions.bzl", "wkg")
wkg.register(
    name = "wkg",
    strategy = "download",
    version = "0.12.0",  # Or any other version
)
use_repo(wkg, "wkg_toolchain")
register_toolchains("@wkg_toolchain//:wkg_toolchain_def")
```

**Features:**
- WebAssembly package management
- OCI registry publishing
- Dependency resolution

### JavaScript/TypeScript Toolchain (jco)

Default configuration (recommended):
```starlark
# MODULE.bazel - Included by default
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
```

Custom version:
```starlark
jco = use_extension("//wasm:extensions.bzl", "jco")
jco.register(
    name = "jco",
    node_version = "20.18.0",  # Node.js version
    version = "1.4.0",         # jco version
)
use_repo(jco, "jco_toolchain")
register_toolchains("@jco_toolchain//:jco_toolchain")
```

**Features:**
- Hermetic Node.js runtime
- jco (JavaScript Component Compiler)
- componentize-js for building components
- NPM dependency management

## Download Strategy (Default)

All toolchains use the **download strategy** by default:

**Benefits:**
- ✅ Hermetic builds - no system dependencies
- ✅ Version-pinned reproducibility
- ✅ Fast - no compilation required
- ✅ Works on all supported platforms
- ✅ Corporate-friendly with custom URLs

**How it works:**
1. Tools are downloaded from GitHub releases or configured URLs
2. Checksums verified using JSON registry in `checksums/tools/`
3. Cached in Bazel's repository cache
4. Platform-specific binaries selected automatically

## Build from Source Strategy

For advanced users needing bleeding-edge features:

```starlark
wasm_toolchain.register(
    strategy = "build",
    git_commit = "main",  # Or specific tag/commit
)
```

**Requirements:**
- Rust toolchain for compilation
- Git for cloning
- Longer build times

**Not recommended** for most users - download strategy provides better reproducibility.

## Security and Checksums

All downloads are verified with SHA256 checksums stored in `checksums/tools/*.json`:

```json
{
  "tool_name": "wasm-tools",
  "latest_version": "1.240.0",
  "versions": {
    "1.240.0": {
      "platforms": {
        "darwin_arm64": {
          "sha256": "8959eb9f494af13868af9e13e74e4fa0fa6c9306b492a9ce80f0e576eb10c0c6",
          "url_suffix": "aarch64-macos.tar.gz"
        }
      }
    }
  }
}
```

This provides:
- Central security auditing
- Tamper detection
- Version tracking
- Platform-specific verification

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/ci.yml
- name: Build Components
  run: bazel build //...  # Downloads tools automatically
```

### Docker Builds

```dockerfile
FROM ubuntu:22.04

# Install Bazel
RUN apt-get update && apt-get install -y bazel

# No need to install WASM tools - downloaded hermetically
COPY . /workspace
WORKDIR /workspace
RUN bazel build //...
```

### Corporate Environments

Use custom URLs for internal mirrors:

```starlark
wasm_toolchain.register(
    strategy = "download",
    version = "1.240.0",
    # Point to internal mirror
    wasm_tools_url = "https://artifacts.corp.com/wasm-tools-1.240.0.tar.gz",
)
```

## Multiple Toolchains

Register multiple toolchains for different environments:

```starlark
wasm_toolchain = use_extension("//wasm:extensions.bzl", "wasm_toolchain")

# Stable for production
wasm_toolchain.register(
    name = "stable",
    strategy = "download",
    version = "1.240.0",
)

# Beta for testing
wasm_toolchain.register(
    name = "beta",
    strategy = "download",
    version = "1.241.0-pre1",
)
```

Select with:
```bash
bazel build --extra_toolchains=@stable_toolchains//:wasm_tools_toolchain //...
```

## Troubleshooting

### Download Failures

**Issue**: Network connectivity or firewall blocking downloads

**Solution**: Use custom URLs pointing to internal mirrors

```starlark
wasm_toolchain.register(
    strategy = "download",
    version = "1.240.0",
    wasm_tools_url = "https://internal-mirror.corp.com/wasm-tools.tar.gz",
)
```

### Checksum Mismatches

**Issue**: Downloaded file doesn't match expected checksum

**Solution**: Checksum may be outdated or file corrupted

1. Verify file integrity manually
2. Update checksums in `checksums/tools/*.json`
3. Report issue if checksums are incorrect

### Platform Not Supported

**Issue**: Tool not available for your platform

**Solution**: Use build strategy (requires Rust toolchain)

```starlark
wasm_toolchain.register(
    strategy = "build",
    git_commit = "v1.240.0",
)
```

### Version Conflicts

**Issue**: Different components require different tool versions

**Solution**: Use multiple toolchains with explicit selection

## Hermetic Builds

All toolchains support hermetic builds:

- ✅ **No system dependencies** - All tools downloaded
- ✅ **Reproducible** - Same inputs = same outputs
- ✅ **Cacheable** - Tools cached across builds
- ✅ **Offline-friendly** - Works with Bazel's download cache

This ensures builds work the same on:
- Developer laptops
- CI servers
- Docker containers
- Air-gapped environments (with pre-populated cache)

## See Also

- [Rule Reference](rules.md) - All available rules
- [Multi-Profile Builds](multi_profile.md) - Debug/release configurations
- [CLAUDE.md](../CLAUDE.md) - Development guidelines
- [Checksums Registry](../checksums/) - Tool checksums and versions
