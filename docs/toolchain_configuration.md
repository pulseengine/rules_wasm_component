# Toolchain Configuration

The rules_wasm_component supports flexible toolchain configuration with three acquisition strategies: system tools, downloaded binaries, and building from source.

## Quick Reference

### Use System Tools (Default)
```starlark
# MODULE.bazel - Uses tools from PATH (CI-friendly)
bazel_dep(name = "rules_wasm_component", version = "0.1.0")
```

### Download Prebuilt Binaries
```starlark
# MODULE.bazel
bazel_dep(name = "rules_wasm_component", version = "0.1.0")

wasm_toolchain = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_toolchain")
wasm_toolchain.register(
    strategy = "download",
    version = "1.235.0",
)
```

### Build from Source
```starlark
# MODULE.bazel
bazel_dep(name = "rules_wasm_component", version = "0.1.0")

wasm_toolchain = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_toolchain")
wasm_toolchain.register(
    strategy = "build",
    git_commit = "v1.235.0",  # or "main" for latest
)
```

## Configuration Options

### Strategy: `"system"` (Default)
Uses tools installed on the system PATH. Perfect for:
- CI environments where tools are pre-installed
- Developer machines with `cargo install wasm-tools wac-cli wit-bindgen-cli`
- Consistent with existing CI setup

```starlark
wasm_toolchain.register(
    strategy = "system",
)
```

**Requirements:**
- `wasm-tools`, `wac`, and `wit-bindgen` must be in PATH
- No version control - uses whatever is installed

### Strategy: `"download"`
Downloads prebuilt binaries from GitHub releases:

```starlark
wasm_toolchain.register(
    strategy = "download",
    version = "1.235.0",
    
    # Optional: Custom URLs
    wasm_tools_url = "https://custom-mirror.com/wasm-tools.tar.gz",
    wac_url = "https://custom-mirror.com/wac.tar.gz", 
    wit_bindgen_url = "https://custom-mirror.com/wit-bindgen.tar.gz",
)
```

**Benefits:**
- Reproducible builds with pinned versions
- No Rust compilation required
- Works on any platform with prebuilt binaries

**Platforms supported:**
- Linux (x86_64, aarch64)
- macOS (x86_64, aarch64) 
- Windows (x86_64)

### Strategy: `"build"`
Builds tools from source code:

```starlark
wasm_toolchain.register(
    strategy = "build",
    git_commit = "v1.235.0",  # Git tag or branch
)
```

**Advanced options:**
```starlark
wasm_toolchain.register(
    strategy = "build",
    git_commit = "main",                    # Latest development
    # git_commit = "feature/new-feature",  # Specific branch
    # git_commit = "abc123def",            # Specific commit
)
```

**Benefits:**
- Always up-to-date with latest commits
- Can use unreleased features
- Full control over build configuration

**Requirements:**
- Rust toolchain available during build
- Git available for cloning
- Longer build times (tools compiled from scratch)

## Multiple Toolchains

You can register multiple toolchains for different purposes:

```starlark
# MODULE.bazel
wasm_toolchain = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm_toolchain")

# System tools for CI/development
wasm_toolchain.register(
    name = "system_tools",
    strategy = "system",
)

# Pinned version for production
wasm_toolchain.register(
    name = "production_tools", 
    strategy = "download",
    version = "1.235.0",
)

# Latest development for testing
wasm_toolchain.register(
    name = "dev_tools",
    strategy = "build", 
    git_commit = "main",
)
```

Then specify which to use:
```bash
# Use production toolchain
bazel build --extra_toolchains=@production_tools_toolchains//:wasm_tools_toolchain //...

# Use development toolchain  
bazel build --extra_toolchains=@dev_tools_toolchains//:wasm_tools_toolchain //...
```

## CI/CD Integration

### GitHub Actions (Recommended)
Uses system strategy with pre-installed tools:

```yaml
# .github/workflows/ci.yml
- name: Install WASM tools
  run: |
    cargo install wasm-tools wac-cli wit-bindgen-cli

- name: Build with Bazel
  run: bazel build //...  # Uses system tools automatically
```

### Docker Builds
Use download strategy for hermetic Docker builds:

```dockerfile
# Dockerfile
FROM ubuntu:22.04

# Install Bazel
RUN apt-get update && apt-get install -y bazel

# No need to install WASM tools - Bazel will download them
COPY . /workspace
WORKDIR /workspace

# MODULE.bazel configured with download strategy
RUN bazel build //...
```

### Corporate Environments
Use custom URLs for internal mirrors:

```starlark
# MODULE.bazel
wasm_toolchain.register(
    strategy = "download",
    version = "1.235.0",
    wasm_tools_url = "https://internal-mirror.corp.com/wasm-tools-1.235.0.tar.gz",
    wac_url = "https://internal-mirror.corp.com/wac-1.235.0.tar.gz",
    wit_bindgen_url = "https://internal-mirror.corp.com/wit-bindgen-1.235.0.tar.gz",
)
```

## Migration Examples

### From CI Script to System Strategy
**Before:**
```bash
# build.sh
cargo install wasm-tools wac-cli wit-bindgen-cli
./build-with-shell-scripts.sh
```

**After:**
```yaml
# .github/workflows/ci.yml
- run: cargo install wasm-tools wac-cli wit-bindgen-cli
- run: bazel build //...  # Automatically uses system tools
```

### From Fixed Version to Flexible Strategy
**Before:** Hard-coded tool versions in scripts

**After:** Configurable in MODULE.bazel:
```starlark
# Development: latest tools
wasm_toolchain.register(strategy = "build", git_commit = "main")

# Production: pinned stable version  
wasm_toolchain.register(strategy = "download", version = "1.235.0")
```

## Troubleshooting

### "Tool not found" with system strategy
```bash
# Install missing tools
cargo install wasm-tools wac-cli wit-bindgen-cli

# Or switch to download strategy
```

### "Download failed" with download strategy
```starlark
# Use custom URLs or switch to build strategy
wasm_toolchain.register(
    strategy = "build",
    git_commit = "main",
)
```

### "Build failed" with build strategy
```bash
# Ensure Rust toolchain is available
rustup install stable
rustup default stable

# Ensure git is available
which git
```

### Tool version mismatches
```starlark
# Pin specific versions for consistency
wasm_toolchain.register(
    strategy = "download", 
    version = "1.235.0",  # Everyone uses same version
)
```