# WebAssembly Tools Builder

This workspace provides a self-hosted solution for building WebAssembly toolchain components from source. It addresses the fundamental problem of cargo filesystem sandbox restrictions in Bazel Central Registry (BCR) testing while maintaining complete hermeticity.

## Architecture

### Problem Statement

The main rules_wasm_component workspace faces cargo sandbox issues when building Rust tools in CI:

- `error: failed to open cargo registry cache: Read-only file system (os error 30)`
- BCR tests fail because they require hermetic builds without external dependencies
- rules_rust has known limitations with sandboxed cargo builds (GitHub issues #1462, #1534, #2145)

### Solution: Self-Hosted Tool Builder

This workspace builds all required WebAssembly tools from source and publishes them as GitHub releases, which the main workspace consumes via http_archive with verified checksums.

## Workflow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ tools-builder/  │───▶│ GitHub Releases  │───▶│ main workspace │
│ (this workspace)│    │ (built binaries) │    │ (hermetic deps) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

1. **Build Phase**: This workspace cross-compiles tools for all platforms using rules_rust
2. **Publish Phase**: CI uploads built binaries to GitHub releases with verified checksums
3. **Consume Phase**: Main workspace downloads pre-built binaries via hermetic_extension.bzl

## Supported Tools

### Core Tools (have upstream releases)

- **wasm-tools**: WebAssembly binary toolkit
- **wit-bindgen**: WIT binding generator
- **wasmtime**: WebAssembly runtime
- **wac**: WebAssembly Composition tool
- **wkg**: WebAssembly Package tools

### Extended Tools (build-only, no upstream releases)

- **wizer**: WebAssembly pre-initialization (main driver for this solution)

## Platform Support

Cross-compilation for all major platforms:

- `x86_64-unknown-linux-gnu` (Linux x64)
- `aarch64-unknown-linux-gnu` (Linux ARM64)
- `x86_64-apple-darwin` (macOS x64)
- `aarch64-apple-darwin` (macOS ARM64/M1/M2)
- `x86_64-pc-windows-msvc` (Windows x64)

## Usage

### Building All Tools

```bash
# Build all tools for all platforms
bazel build //:all_tools

# Build core tools only
bazel build //:core_tools

# Build extended tools (including wizer)
bazel build //:extended_tools
```

### Building Specific Tools

```bash
# Build wizer for all platforms
bazel build //tools/wizer:wizer-linux-x86_64
bazel build //tools/wizer:wizer-macos-arm64
bazel build //tools/wizer:wizer-windows-x86_64

# Build wasm-tools for specific platform
bazel build //tools/wasm-tools:wasm-tools-linux-arm64
```

### Release Management

The built artifacts are packaged and uploaded to GitHub releases:

```bash
# Package release artifacts
bazel build //:release_artifacts

# Upload to GitHub (via CI)
gh release create v1.0.0 bazel-bin/release_artifacts/*
```

## Integration with Main Workspace

The main workspace consumes these tools via `toolchains/hermetic_extension.bzl`:

```starlark
http_archive(
    name = "wizer_hermetic",
    urls = ["https://github.com/rules-wasm-component/tools/releases/download/v1.0.0/wizer-1.0.0-x86_64-linux.tar.gz"],
    sha256 = "...",  # Verified checksum
)
```

## Benefits

1. **Complete Hermeticity**: No external cargo registry dependencies
2. **BCR Compatibility**: Passes all Bazel Central Registry tests
3. **Cross-Platform**: Supports all major development platforms
4. **Version Control**: Explicit tool versioning and checksum verification
5. **CI Efficiency**: Pre-built binaries eliminate build-time compilation
6. **No System Dependencies**: Pure Bazel solution without external requirements

## File Structure

```
tools-builder/
├── MODULE.bazel              # Workspace configuration with cross-compilation
├── BUILD.bazel               # Main orchestration targets
├── README.md                 # This documentation
├── platforms/
│   ├── BUILD.bazel           # Platform constraint definitions
│   └── defs.bzl              # Platform mappings and constants
├── toolchains/
│   ├── builder_extensions.bzl # Git repository management for tool sources
│   └── builder_macros.bzl     # Cross-platform build macros
└── tools/
    ├── wasm-tools/BUILD.bazel # wasm-tools build configuration
    ├── wizer/BUILD.bazel      # wizer build configuration
    └── ...                    # Other tool build files
```

## Comparison with Alternatives

| Approach | Hermeticity | BCR Compatible | Cross-Platform | Maintenance |
|----------|-------------|----------------|----------------|-------------|
| **Self-hosted builds** | ✅ Complete | ✅ Yes | ✅ Full | Medium |
| Pre-built binaries only | ✅ Complete | ✅ Yes | ⚠️ Limited | Low |
| Cargo in rules_rust | ❌ Registry deps | ❌ Sandbox issues | ✅ Full | High |
| rules_nixpkgs | ❌ Nix requirement | ❌ Not hermetic | ✅ Full | High |

## Development Workflow

1. **Add New Tool**: Create BUILD file in `tools/TOOL_NAME/`
2. **Update Versions**: Modify git repository tags in MODULE.bazel
3. **Test Builds**: Run platform-specific build tests
4. **Update Checksums**: Calculate and verify SHA256 hashes
5. **Release**: Tag and publish built artifacts

This approach ensures the main workspace remains completely hermetic while providing access to all required WebAssembly toolchain components.
