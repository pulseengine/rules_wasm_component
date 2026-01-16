---
title: Air-Gap and Offline Builds
description: Build WebAssembly components in disconnected environments, corporate networks, or for fully reproducible builds
---

This guide explains how to build WebAssembly components in disconnected environments, corporate networks with restricted internet access, or when you need fully reproducible builds.

## Overview

`rules_wasm_component` supports three levels of air-gap capability:

| Level | What's Vendored | Network Required | Use Case |
|-------|-----------------|------------------|----------|
| **Toolchain Only** | Build tools (wasm-tools, wasmtime, etc.) | Yes (for OCI pulls) | Corporate artifact proxies |
| **Toolchain + WIT** | Build tools + WASI WIT definitions | Yes (for OCI pulls) | Reproducible WIT dependencies |
| **Full Air-Gap** | Everything including OCI components | No | Complete disconnected builds |

## Quick Start: Digest-Based Pulls

The simplest way to improve reproducibility is using digest-based OCI pulls instead of tags:

```starlark
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_from_oci")

# Instead of tag-based pull (mutable):
wasm_component_from_oci(
    name = "auth_service",
    registry = "ghcr.io",
    namespace = "my-org",
    component_name = "auth-service",
    tag = "v1.2.0",  # Tag can be overwritten
)

# Use digest-based pull (immutable):
wasm_component_from_oci(
    name = "auth_service_pinned",
    registry = "ghcr.io",
    namespace = "my-org",
    component_name = "auth-service",
    digest = "sha256:8a9b1aa8a2c9d3dc36f1724ccbf24a48c473808d9017b059c84afddc55743f1e",
)
```

To find a component's digest:
```bash
wkg oci pull ghcr.io/my-org/auth-service:v1.2.0 --output /tmp/component.wasm
shasum -a 256 /tmp/component.wasm
# Use output as: digest = "sha256:<hash>"
```

### Component Checksum Registry

For commonly used components, check the centralized registry at `//checksums/components/`:

```starlark
# The registry provides verified digests for popular components
# See: checksums/components/*.json

# Example registry entry structure:
# {
#   "component_name": "wasi-http-proxy",
#   "versions": {
#     "0.2.6": {
#       "digest": "sha256:abc123...",
#       "wit_world": "wasi:http/proxy@0.2.6"
#     }
#   }
# }
```

Adding a new component to the registry:
1. Create `checksums/components/<component-name>.json`
2. Pull the component and compute its digest
3. Add the entry to `checksums/components/registry.json`

## Vendored Components (Full Air-Gap)

For fully offline builds, pre-download components and reference them locally:

```starlark
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_from_oci")

# Reference a pre-downloaded component
wasm_component_from_oci(
    name = "auth_service",
    vendored_component = "//vendor/components:auth-service.wasm",
)
```

### Vendoring Workflow

1. **Download components online** (one-time setup):
```bash
mkdir -p vendor/components

# Pull each component you need
wkg oci pull ghcr.io/my-org/auth-service:v1.2.0 \
    --output vendor/components/auth-service.wasm

wkg oci pull ghcr.io/my-org/payment-gateway:v2.0.0 \
    --output vendor/components/payment-gateway.wasm
```

2. **Create BUILD.bazel for vendored components**:
```starlark
# vendor/components/BUILD.bazel
package(default_visibility = ["//visibility:public"])

exports_files([
    "auth-service.wasm",
    "payment-gateway.wasm",
])
```

3. **Commit to source control** and build offline:
```bash
git add vendor/components/
git commit -m "Vendor OCI components for air-gap builds"
```

## Toolchain Vendoring

For air-gapping build tools (wasm-tools, wasmtime, wkg, etc.):

### Using vendor_all_toolchains

```bash
# Download all toolchains to vendor directory
bazel run //tools/vendor:vendor_all_toolchains -- \
    --output-dir vendor/toolchains

# Build offline using vendored toolchains
BAZEL_WASM_VENDOR_DIR=vendor/toolchains bazel build //...
```

### Environment Variables

**Toolchain Downloads:**

| Variable | Description | Example |
|----------|-------------|---------|
| `BAZEL_WASM_OFFLINE` | Use vendored files from `third_party/toolchains/` | `1` |
| `BAZEL_WASM_VENDOR_DIR` | Custom vendor directory (e.g., NFS mount) | `/mnt/shared/wasm-tools` |
| `BAZEL_WASM_MIRROR` | Mirror URL for all toolchain downloads | `https://internal.example.com/tools` |
| `BAZEL_WASM_GITHUB_MIRROR` | Override GitHub URL for releases | `https://github.internal.example.com` |

**OCI/Component Pulls (via wkg):**

| Variable | Description | Example |
|----------|-------------|---------|
| `WKG_CONFIG_FILE` | Path to wkg.toml configuration | `/etc/wkg/config.toml` |
| `WKG_REGISTRY_<NAME>_URL` | Registry URL override | `https://registry.internal.example.com` |
| `WKG_REGISTRY_<NAME>_TOKEN` | Registry authentication token | `ghp_xxxxx` |

**Using with Bazel:**

Environment variables must be passed to Bazel using `--repo_env` (for repository rules) or `--action_env` (for build actions):

```bash
# In .bazelrc for persistent configuration
common --repo_env=BAZEL_WASM_VENDOR_DIR=/mnt/shared/wasm-tools
common --repo_env=BAZEL_WASM_OFFLINE=1
build --action_env=WKG_CONFIG_FILE=/etc/wkg/config.toml
```

Or on the command line:
```bash
bazel build --repo_env=BAZEL_WASM_OFFLINE=1 //...
```

### Offline Build

```bash
# Set environment for fully offline builds
export BAZEL_WASM_OFFLINE=true
export BAZEL_WASM_VENDOR_DIR=/path/to/vendor

# Build without network access
bazel build --sandbox_network=off //...
```

## WIT Dependency Vendoring

### Standard WASI Interfaces

WASI WIT dependencies are already air-gap ready via `wasi_wit_dependencies()`:

```starlark
# In your WORKSPACE or MODULE.bazel setup
load("@rules_wasm_component//wit:defs.bzl", "wasi_wit_dependencies")

wasi_wit_dependencies()  # Downloads once, cached by Bazel with SHA256 verification
```

### Custom WIT Packages with wit_package

For custom WIT packages from registries, use the `wit_package` repository rule:

```starlark
# In MODULE.bazel or WORKSPACE
load("@rules_wasm_component//wit:defs.bzl", "wit_package")

wit_package(
    name = "custom_api",
    package = "myorg:custom-api@1.0.0",
    registry = "ghcr.io/myorg",
    sha256 = "abc123...",  # Optional but recommended
)

# Then use in BUILD.bazel:
wit_library(
    name = "my_interface",
    srcs = ["my.wit"],
    deps = ["@custom_api//:myorg-custom-api"],
)
```

### Manual Vendoring Workflow

For complete control, vendor WIT packages manually:

```bash
# 1. Vendor WIT dependencies (one-time, online)
mkdir -p vendor/wit
wkg wit fetch wasi:cli@0.2.6 --output vendor/wit/wasi-cli
wkg wit fetch myorg:custom-api@1.0.0 --output vendor/wit/custom-api

# 2. Commit to source control
git add vendor/wit/
git commit -m "Vendor WIT dependencies"
```

Then create BUILD.bazel for vendored packages:
```starlark
# vendor/wit/BUILD.bazel
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "wasi_cli",
    srcs = glob(["wasi-cli/**/*.wit"]),
    package_name = "wasi:cli@0.2.6",
    visibility = ["//visibility:public"],
)

wit_library(
    name = "custom_api",
    srcs = glob(["custom-api/**/*.wit"]),
    package_name = "myorg:custom-api@1.0.0",
    visibility = ["//visibility:public"],
)
```

### Lock File Generation

Generate a lock file for reproducible WIT dependencies:

```starlark
# BUILD.bazel
load("@rules_wasm_component//wit:defs.bzl", "wit_vendor_lock")

wit_vendor_lock(
    name = "vendor_wit",
    packages = [
        "wasi:cli@0.2.6",
        "wasi:http@0.2.6",
        "myorg:custom-api@1.0.0",
    ],
    lock_file = "wit.lock",
    output_dir = "vendor/wit",
)
```

Run the vendor target:
```bash
bazel run //:vendor_wit_generate
```

### Offline Mode for wit_package

Enable offline mode to use pre-vendored WIT packages:

```bash
# Set environment variables
export BAZEL_WASM_OFFLINE=1
export BAZEL_WASM_WIT_VENDOR_DIR=/path/to/vendor/wit

# Build uses vendored packages, no network required
bazel build //...
```

## OCI Registry Mirroring

For corporate environments, configure an internal OCI registry mirror:

### Option 1: Environment Variable

```bash
export BAZEL_WASM_COMPONENT_MIRROR=https://registry.internal.example.com
bazel build //...
```

### Option 2: wkg.toml Configuration

Create a `wkg.toml` file:
```toml
[registry."ghcr.io"]
auth = { type = "basic", username = "user", password_env = "GHCR_TOKEN" }

[registry."ghcr.io".mirror]
url = "https://registry.internal.example.com"
fallback = true  # Fall back to primary if mirror fails
```

### Option 3: Local Filesystem Registry

For fully offline environments, use a local filesystem registry:
```toml
[registry."local"]
local = { root = "/path/to/local/registry" }

[overrides]
"wasi:cli" = { path = "/path/to/local/wasi-cli" }
"wasi:http" = { path = "/path/to/local/wasi-http" }
```

## CI/CD Integration

### GitHub Actions (Air-Gap Mode)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Restore vendored dependencies
        uses: actions/cache@v4
        with:
          path: |
            vendor/toolchains
            vendor/components
          key: wasm-vendor-${{ hashFiles('vendor/manifest.json') }}

      - name: Build offline
        env:
          BAZEL_WASM_OFFLINE: true
          BAZEL_WASM_VENDOR_DIR: vendor
        run: bazel build --sandbox_network=off //...
```

### GitLab CI (Air-Gap Mode)

```yaml
build:
  stage: build
  variables:
    BAZEL_WASM_OFFLINE: "true"
    BAZEL_WASM_VENDOR_DIR: vendor
  cache:
    paths:
      - vendor/
  script:
    - bazel build --sandbox_network=off //...
```

## Verifying Air-Gap Builds

To ensure your build truly works offline:

```bash
# Test with network disabled
bazel build --sandbox_network=off //...

# Verify no network access occurred
bazel query 'deps(//...)' --output=build 2>&1 | grep -c "repository_rule"
```

## Troubleshooting

### "Failed to download" errors in offline mode

Ensure all dependencies are vendored:
```bash
# List all external dependencies
bazel query 'deps(//...)' --output=build | grep "http_archive\|git_repository"
```

### Digest mismatch errors

If a component's digest doesn't match:
1. Verify the vendored file matches the expected digest
2. Re-download the component: `wkg oci pull <ref>@<digest> --output <path>`
3. Check for file corruption during transfer

### Mirror fallback not working

Check wkg.toml configuration:
```bash
wkg config show
```

Ensure the mirror URL is reachable and has the required components.

## Best Practices

1. **Always use digests for production**: Tags are mutable; digests are immutable
2. **Vendor early, update regularly**: Set up vendoring before you need it
3. **Document your vendor process**: Include vendor scripts in your repository
4. **Test offline builds in CI**: Catch missing dependencies before deployment
5. **Keep vendor directories in sync**: Use a manifest file to track versions
