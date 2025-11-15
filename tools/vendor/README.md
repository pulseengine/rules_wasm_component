# Toolchain Vendoring

**Pure Bazel toolchain vendoring using file-ops WASM component - ZERO shell scripts**

This module provides enterprise-grade toolchain vendoring for air-gap deployments without any shell script dependencies. All file operations are performed using the file-ops WASM component.

## Overview

The vendoring system supports two deployment modes:

1. **Corporate Mirror** (Phase 1 - Implemented in PR #209)
   - Use environment variables to point to corporate artifact mirrors
   - JFrog Artifactory, Sonatype Nexus, Harbor, etc.
   - No code changes, just configuration

2. **Offline/Air-Gap** (Phase 2 - This Module)
   - Pre-download all toolchains to `third_party/toolchains/`
   - Complete offline builds with no internet access
   - Bazel-native with file-ops WASM component

## Quick Start

### Step 1: Set Up Vendor Repository

Add to your `MODULE.bazel`:

```starlark
# Load vendoring infrastructure
load("//tools/vendor:vendor_toolchains.bzl", "vendor_all_toolchains")

# Create vendor repository for your platforms
vendor_all_toolchains(
    name = "vendored_toolchains",
    platforms = [
        "linux_amd64",
        "darwin_arm64",
    ],
)
```

### Step 2: Download Toolchains

On a machine with internet access:

```bash
# Fetch all toolchains to Bazel's repository cache
bazel fetch @vendored_toolchains//...

# Export to third_party/ directory
bazel run @vendored_toolchains//:export_to_third_party
```

This downloads ~554 MB of toolchain binaries and organizes them in:

```
third_party/toolchains/
├── wasm-tools/1.240.0/
│   ├── linux_amd64/
│   └── darwin_arm64/
├── nodejs/20.18.0/
│   ├── linux_amd64/
│   └── darwin_arm64/
└── ... (all other tools)
```

### Step 3: Build in Air-Gap Mode

On the air-gapped machine (after transferring the repository):

```bash
# Enable offline mode
export BAZEL_WASM_OFFLINE=1

# Build uses vendored files, no downloads
bazel build //examples/basic:hello_component
```

## Architecture

### No Shell Scripts - Pure Bazel

```
┌──────────────────────────────────────────────────────────┐
│  Bazel Repository Rule (vendor_all_toolchains)           │
│  ├─ Downloads to Bazel cache using secure_download       │
│  ├─ Verifies SHA256 checksums                            │
│  └─ Creates manifest of vendored items                   │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│  File-Ops WASM Component (export action)                 │
│  ├─ Copies files from Bazel cache to third_party/        │
│  ├─ Creates directory structure                          │
│  └─ Zero shell commands, pure WASM                       │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│  third_party/toolchains/ (vendored binaries)             │
│  ├─ Committed to git (optional)                          │
│  ├─ Or stored on network share                           │
│  └─ Used when BAZEL_WASM_OFFLINE=1                       │
└──────────────────────────────────────────────────────────┘
```

### Key Components

1. **vendor_toolchains.bzl**: Repository rule that downloads toolchains
2. **defs.bzl**: Export action using file-ops component
3. **secure_download.bzl**: Enhanced with offline mode support

## Usage Scenarios

### Scenario 1: Development (Internet Access)

```bash
# No configuration needed
bazel build //examples/basic:hello_component
# Downloads from public github.com, npmjs.org, etc.
```

### Scenario 2: Corporate Network (JFrog/Nexus)

```bash
# Configure corporate mirrors (from PR #209)
export BAZEL_WASM_GITHUB_MIRROR=https://jfrog.corp.com/github
export BAZEL_NPM_REGISTRY=https://npm.corp.com

bazel build //examples/basic:hello_component
# Downloads from corporate mirrors
```

### Scenario 3: Air-Gap (Vendored Toolchains)

```bash
# Step 1: On internet-connected machine
bazel fetch @vendored_toolchains//...
bazel run @vendored_toolchains//:export_to_third_party

# Step 2: Transfer repository to air-gapped machine

# Step 3: Build offline
export BAZEL_WASM_OFFLINE=1
bazel build //examples/basic:hello_component
# Uses third_party/, no downloads
```

### Scenario 4: Hybrid (Partial Vendoring)

```bash
# Vendor only specific platforms
vendor_all_toolchains(
    name = "vendored_linux_only",
    platforms = ["linux_amd64"],
)

# Use vendored for Linux, download for others
export BAZEL_WASM_OFFLINE=prefer  # Try vendored first, fallback to download
```

## Configuration

### Vendoring Specific Platforms

```starlark
vendor_all_toolchains(
    name = "vendored_toolchains",
    platforms = [
        "linux_amd64",      # Intel/AMD Linux
        "linux_arm64",      # ARM Linux (Raspberry Pi, AWS Graviton)
        "darwin_amd64",     # Intel Mac
        "darwin_arm64",     # Apple Silicon Mac (M1/M2/M3)
        "windows_amd64",    # Windows
    ],
)
```

### Storage Options

**Option 1: Commit to Git** (Small teams, few platforms)
```bash
# Add to git
git add third_party/toolchains/
git commit -m "vendor: toolchain binaries"

# Pros: Simple, works everywhere
# Cons: Large repo size (~554 MB), slow clone
```

**Option 2: Git LFS** (Better for large binaries)
```bash
# .gitattributes
third_party/toolchains/**/* filter=lfs diff=lfs merge=lfs -text

git lfs track "third_party/toolchains/**/*"
git add .gitattributes third_party/toolchains/
git commit -m "vendor: toolchains via Git LFS"

# Pros: Faster git operations
# Cons: Requires Git LFS setup
```

**Option 3: Network Share** (Enterprise standard)
```bash
# Don't commit to git, use shared storage
rsync -av third_party/toolchains/ /mnt/corp-distfiles/

# On build machines
ln -s /mnt/corp-distfiles third_party/toolchains

# Pros: No git bloat, centralized management
# Cons: Requires network infrastructure
```

**Option 4: Artifact Server** (Best for large organizations)
```bash
# Upload to artifact server
for dir in third_party/toolchains/*; do
    tool=$(basename $dir)
    curl -T "$dir" https://artifacts.corp.com/toolchains/$tool
done

# Download in CI/CD
curl -O https://artifacts.corp.com/toolchains/bundle.tar.gz
tar xzf bundle.tar.gz -C third_party/

# Pros: Professional, audit trail, versioning
# Cons: Infrastructure required
```

## Environment Variables

All environment variables from Phase 1 (PR #209) continue to work:

| Variable | Purpose | Default |
|----------|---------|---------|
| `BAZEL_WASM_OFFLINE` | Use vendored files instead of downloading | `0` (disabled) |
| `BAZEL_WASM_GITHUB_MIRROR` | GitHub releases mirror URL | `https://github.com` |
| `BAZEL_NODEJS_MIRROR` | Node.js binary download mirror | `https://nodejs.org` |
| `BAZEL_NPM_REGISTRY` | npm package registry | `https://registry.npmjs.org` |
| `BAZEL_GO_MIRROR` | Go SDK download mirror | `https://go.dev` |
| `BAZEL_GOPROXY` | Go module proxy | `https://proxy.golang.org,direct` |

## Vendored Tools

The following tools are vendored for each platform:

| Tool | Version | Size (per platform) | Purpose |
|------|---------|---------------------|---------|
| wasm-tools | 1.240.0 | ~15 MB | WASM manipulation |
| wit-bindgen | 0.39.0 | ~10 MB | WIT binding generation |
| wac | 0.7.0 | ~8 MB | Component composition |
| wkg | 0.11.1 | ~5 MB | Component registry |
| wasmtime | 29.0.1 | ~20 MB | WASM runtime |
| wizer | 9.0.1 | ~5 MB | Pre-initialization |
| wasi-sdk | 25.0.0 | ~200 MB | C/C++ compiler |
| nodejs | 20.18.0 | ~40 MB | JavaScript runtime |
| tinygo | 0.39.0 | ~60 MB | Go compiler |

**Total per platform**: ~363 MB
**All 5 platforms**: ~1.8 GB

## Maintenance

### Updating Vendored Toolchains

When tool versions change in `checksums/tools/*.json`:

```bash
# 1. Clear old vendored files
rm -rf third_party/toolchains/

# 2. Re-vendor with new versions
bazel fetch @vendored_toolchains//...
bazel run @vendored_toolchains//:export_to_third_party

# 3. Commit changes
git add third_party/toolchains/
git commit -m "vendor: update toolchains to latest versions"
```

### Verifying Vendored Files

All vendored files are verified against SHA256 checksums from the central registry:

```bash
# Check manifest
cat $(bazel info output_base)/external/vendored_toolchains/vendored_manifest.json

# Verify a specific tool
sha256sum third_party/toolchains/wasm-tools/1.240.0/linux_amd64/*
```

## Troubleshooting

### Error: "Vendored toolchain not found"

```
OFFLINE MODE: Vendored toolchain not found at third_party/toolchains/wasm-tools/1.240.0/darwin_arm64
Run 'bazel run @vendored_toolchains//:export_to_third_party' to vendor toolchains first.
```

**Solution**: Run the export command to vendor toolchains.

### Slow Vendoring

Vendoring downloads ~1.8 GB for all platforms. To speed up:

```starlark
# Vendor only your platform
vendor_all_toolchains(
    name = "vendored_toolchains",
    platforms = ["darwin_arm64"],  # Just your platform
)
```

### Git Clone Too Slow

If committing vendored files to git:

```bash
# Use shallow clone
git clone --depth=1 https://github.com/your/repo.git

# Or use Git LFS (see Storage Options above)
```

## Comparison with Other Approaches

| Approach | Shell Scripts | Cross-Platform | Hermetic | Audit Trail |
|----------|---------------|----------------|----------|-------------|
| **This (Bazel + WASM)** | ❌ Zero | ✅ Yes | ✅ Yes | ✅ Yes |
| Python vendoring script | ✅ Yes | ⚠️ Needs Python | ❌ No | ⚠️ Manual |
| Bazel distdir | ❌ Zero | ✅ Yes | ✅ Yes | ⚠️ Opaque |
| Manual downloads | ✅ Yes | ❌ No | ❌ No | ❌ No |

## Security

- ✅ **SHA256 verification**: All downloads verified against central registry
- ✅ **Hermetic**: No system dependencies, pure Bazel
- ✅ **Audit trail**: Manifest tracks all vendored items
- ✅ **Content-addressed**: Bazel cache prevents tampering
- ✅ **No shell execution**: Pure WASM component for file ops

## Related

- **Phase 1 (PR #209)**: Mirror environment variables
- **Issue #208**: Enterprise air-gap support roadmap
- **checksums/tools/**: Central checksum registry

## License

Same as parent project
