# Version Management Analysis & Recommendations

## Current State: Version Tracking Issues

### Problem: Multiple Version Sources for wit-bindgen

We currently have **three different versions** of wit-bindgen across the codebase:

| Location | Version | Purpose | File |
|----------|---------|---------|------|
| **CLI Binary (Toolchain)** | 0.46.0 | Generates bindings from WIT files | `toolchains/wasm_toolchain.bzl:522` |
| **Proc Macro (Cargo)** | 0.47.0 | Used in checksum_updater tool | `tools/checksum_updater/Cargo.toml:34` |
| **Registry** | 0.43.0 | Checksums for downloadable binaries | `checksums/tools/wit-bindgen.json:4` |

### The Issue This Caused

The embedded runtime in `rust_wasm_component_bindgen.bzl` had a comment claiming compatibility with CLI v0.47.0, but:
- The actual CLI toolchain uses v0.46.0
- The proc macro dependency uses v0.47.0
- The registry only has checksums for v0.43.0

This version mismatch led to the recent bug where we tried using `wit-bindgen-rt` v0.39.0 (which doesn't exist on crates.io) with CLI v0.47.0, causing:
```
error[E0433]: could not find `Cleanup` in `rt`
error[E0433]: could not find `export` in bindings
```

## What We Already Have: Good Foundations

### ✅ 1. Centralized Checksum Registry (`checksums/tools/*.json`)

**Pattern**: JSON files with version + platform-specific checksums

**Example** (`checksums/tools/wasm-tools.json`):
```json
{
  "tool_name": "wasm-tools",
  "github_repo": "bytecodealliance/wasm-tools",
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

**Strengths**:
- ✅ Single source of truth for binary downloads
- ✅ Security auditing via checksums
- ✅ Platform-specific download URLs
- ✅ Multiple versions supported

**Gap**: Not used consistently for wit-bindgen

### ✅ 2. Tool Compatibility Validation (`checksums/registry.bzl`)

**Function**: `validate_tool_compatibility(tools_config)`

**Example** (from `checksums/registry.bzl:835-848`):
```python
compatibility_matrix = {
    "1.235.0": {  # wasm-tools version
        "wac": ["0.7.0", "0.8.0"],
        "wit-bindgen": ["0.43.0", "0.46.0"],  # Compatible wit-bindgen versions
        "wkg": ["0.11.0"],
        "wasmsign2": ["0.2.6"],
    },
}
```

**Strengths**:
- ✅ Validates cross-tool compatibility
- ✅ Warns about incompatible versions
- ✅ Centralized compatibility knowledge

**Gap**: Not extended to cover Rust crate versions (wit-bindgen proc macro vs CLI)

### ✅ 3. `get_tool_info()` API

**Usage**: Fetch version + checksum from registry

**Example**:
```python
tool_info = get_tool_info("wit-bindgen", "0.46.0", platform)
# Returns: { "sha256": "...", "url_suffix": "..." }
```

**Strengths**:
- ✅ Unified API for all tools
- ✅ Type-safe access to checksums
- ✅ Platform resolution

**Gap**: Doesn't validate that requested version exists in registry

## Gaps & Issues

### 🔴 Issue 1: No Single Source of Truth for wit-bindgen Version

**Problem**: Version defined in 3 places:
1. Hardcoded in `wasm_toolchain.bzl`: `wit_bindgen_version = "0.46.0"`
2. Hardcoded in `Cargo.toml`: `wit-bindgen = "0.47.0"`
3. Registry JSON: `"latest_version": "0.43.0"`

**Impact**:
- Manual sync required across 3 locations
- Easy to miss when updating
- No compile-time checks

### 🔴 Issue 2: No Validation Between CLI and Proc Macro Versions

**Problem**: The proc macro version (`wit-bindgen = "0.47.0"`) is independent of the CLI version (`0.46.0`)

**Impact**:
- API incompatibilities like the Cleanup/CleanupGuard issue
- Runtime errors instead of build-time errors
- No warning when versions drift

### 🔴 Issue 3: Registry Not Updated

**Problem**: `checksums/tools/wit-bindgen.json` has `latest_version: 0.43.0` but we're using 0.46.0

**Impact**:
- Registry is stale
- Can't use `get_tool_info("wit-bindgen", "0.46.0", ...)` - will fail
- Bypassing our own security infrastructure

### 🔴 Issue 4: No Runtime → Crate Version Mapping

**Problem**: The embedded runtime needs to know what API the CLI generates, but there's no mapping from:
- CLI version (e.g., 0.46.0) → Required runtime API (Cleanup, CleanupGuard, etc.)

**Impact**:
- Manual documentation in comments ("compatible with CLI 0.47.0")
- Easy to get wrong
- No automated verification

## Recommended Solutions

### 🎯 Solution 1: Single Version Constant (IMMEDIATE - Required)

**Create**: `toolchains/tool_versions.bzl`

```python
# Single source of truth for tool versions
TOOL_VERSIONS = {
    "wasm-tools": "1.240.0",
    "wit-bindgen": "0.46.0",  # CLI + Proc Macro MUST match
    "wac": "0.8.0",
    "wkg": "0.11.0",
    "wasmtime": "28.0.0",
    "wizer": "8.1.0",
}

# Compatibility constraints
TOOL_COMPATIBILITY = {
    "wasm-tools": {
        "1.240.0": {
            "wit-bindgen": ["0.46.0"],  # Only compatible wit-bindgen versions
            "wac": ["0.7.0", "0.8.0"],
        },
    },
}
```

**Usage**:
```python
# In wasm_toolchain.bzl
load("//toolchains:tool_versions.bzl", "TOOL_VERSIONS")
wit_bindgen_version = TOOL_VERSIONS["wit-bindgen"]

# In Cargo.toml (via template)
wit-bindgen = "${WIT_BINDGEN_VERSION}"  # Templated from TOOL_VERSIONS
```

**Benefits**:
- ✅ Single source of truth
- ✅ Type-safe (Bazel will error if key missing)
- ✅ Easy to update (one location)
- ✅ Can add compatibility checks

### 🎯 Solution 2: Automated Cargo.toml Version Sync (RECOMMENDED)

**Approach**: Generate `Cargo.toml` from template using Bazel

**Create**: `tools/checksum_updater/Cargo.toml.template`
```toml
[dependencies]
wit-bindgen = "${WIT_BINDGEN_VERSION}"  # Replaced by Bazel
wit-bindgen-rt = "${WIT_BINDGEN_RT_VERSION}"  # If needed
```

**Bazel rule**:
```python
genrule(
    name = "cargo_toml",
    srcs = ["Cargo.toml.template"],
    outs = ["Cargo.toml"],
    cmd = """
        sed -e 's/$${WIT_BINDGEN_VERSION}/0.46.0/g' \
            < $< > $@
    """,
)
```

**Benefits**:
- ✅ Cargo.toml version derived from TOOL_VERSIONS
- ✅ Impossible to have version mismatch
- ✅ Automated sync

**Alternative**: Use build.rs to validate versions at compile time

### 🎯 Solution 3: Update Registry with Current Versions (IMMEDIATE - Required)

**Action**: Update `checksums/tools/wit-bindgen.json`

**Current** (WRONG):
```json
{
  "latest_version": "0.43.0",
  "versions": {
    "0.43.0": { ... }
  }
}
```

**Fixed**:
```json
{
  "latest_version": "0.46.0",
  "versions": {
    "0.46.0": {
      "release_date": "2025-XX-XX",
      "platforms": {
        "darwin_arm64": {
          "sha256": "...",  # Actual checksum
          "url_suffix": "aarch64-macos.tar.gz"
        },
        // ... other platforms
      }
    },
    "0.43.0": { ... }  # Keep for compatibility
  }
}
```

**Tool**: Use `checksum_updater` to fetch checksums
```bash
bazel run //tools/checksum_updater -- update wit-bindgen 0.46.0
```

### 🎯 Solution 4: Embedded Runtime Compatibility Matrix (RECOMMENDED)

**Problem**: Need to know what API each CLI version expects

**Solution**: Document in embedded runtime
```python
# In rust_wasm_component_bindgen.bzl

# Compatibility: This embedded runtime API is compatible with:
# - wit-bindgen CLI 0.44.0 - 0.46.0
# - Requires: Cleanup, CleanupGuard, run_ctors_once, maybe_link_cabi_realloc
# - Breaking changes in CLI 0.47.0: [list changes]

COMPATIBLE_CLI_VERSIONS = ["0.44.0", "0.45.0", "0.46.0"]

def _validate_cli_compatibility(cli_version):
    if cli_version not in COMPATIBLE_CLI_VERSIONS:
        fail("Embedded runtime incompatible with CLI {}. Compatible versions: {}".format(
            cli_version, COMPATIBLE_CLI_VERSIONS
        ))
```

**Usage in rule**:
```python
wit_bindgen_version = TOOL_VERSIONS["wit-bindgen"]
_validate_cli_compatibility(wit_bindgen_version)
```

### 🎯 Solution 5: Automated Version Compatibility Tests (LONG-TERM)

**Approach**: Test embedded runtime against multiple CLI versions

**Example**:
```python
# In test/runtime_compatibility/
test_suite(
    name = "runtime_compatibility",
    tests = [
        ":test_runtime_with_cli_0_44",
        ":test_runtime_with_cli_0_45",
        ":test_runtime_with_cli_0_46",
    ],
)
```

**Benefits**:
- ✅ Catch API changes automatically
- ✅ Document compatible version ranges
- ✅ CI fails before merging incompatible changes

## Implementation Plan

### Phase 1: Immediate Fixes (THIS PR)

1. ✅ **DONE**: Fix embedded runtime to use proper allocator (no UB)
2. ✅ **DONE**: Remove wit-bindgen-rt dependency (incompatible version)
3. ⏳ **TODO**: Update `checksums/tools/wit-bindgen.json` to 0.46.0
4. ⏳ **TODO**: Add compatibility comment in embedded runtime

### Phase 2: Single Source of Truth (NEXT PR)

1. Create `toolchains/tool_versions.bzl` with `TOOL_VERSIONS` constant
2. Update all hardcoded versions to use `TOOL_VERSIONS`
3. Add validation in `wasm_toolchain.bzl` to check CLI version compatibility
4. Update `CLAUDE.md` to document version management pattern

### Phase 3: Automated Sync (FOLLOW-UP)

1. Convert `Cargo.toml` to template
2. Add genrule to generate `Cargo.toml` from `TOOL_VERSIONS`
3. Add CI check to ensure versions match
4. Document in `CONTRIBUTING.md`

### Phase 4: Testing (FUTURE)

1. Create runtime compatibility test suite
2. Test against ±1 CLI version
3. Add to CI pipeline
4. Document breaking change detection process

## Best Practices Going Forward

### ✅ DO

1. **Define versions in `TOOL_VERSIONS` constant** (single source of truth)
2. **Update registry JSON** when changing versions
3. **Run compatibility validation** before merging
4. **Document breaking changes** in embedded runtime
5. **Test with actual CLI version** used in toolchain

### ❌ DON'T

1. **Hardcode versions** in multiple places
2. **Assume crate versions match** CLI versions
3. **Skip checksum verification** (always use registry)
4. **Mix versions** (CLI vs proc macro)
5. **Forget to update compatibility matrix**

## Comparison with Other Build Systems

### Cargo (Rust)

**Approach**: `Cargo.lock` pins exact versions
- ✅ Automatic dependency resolution
- ✅ Transitive dependency management
- ❌ Can't express "CLI must match crate"

### Nix

**Approach**: Derivations with explicit dependencies
- ✅ Pure, reproducible builds
- ✅ All deps explicitly versioned
- ❌ Complex to set up

### Our Hybrid Approach

**Strategy**: Bazel constants + JSON registry + compatibility validation
- ✅ Single source of truth (`TOOL_VERSIONS`)
- ✅ Security auditing (checksums in JSON)
- ✅ Cross-tool compatibility checks
- ✅ Bazel-native (no external tools)
- ⏳ Needs automation for Cargo.toml sync

## Related Documentation

- `CLAUDE.md` - Dependency Management Patterns (RULE #2)
- `checksums/tools/` - JSON registry for tool versions
- `checksums/registry.bzl` - Tool compatibility API
- `toolchains/wasm_toolchain.bzl` - Toolchain setup

## Appendix: Current Version Audit

**As of 2025-11-14:**

| Tool | Source | Version | Status |
|------|--------|---------|--------|
| wit-bindgen CLI | `wasm_toolchain.bzl:522` | 0.46.0 | ✅ Used |
| wit-bindgen proc macro | `Cargo.toml:34` | 0.47.0 | ⚠️ Mismatch |
| wit-bindgen registry | `wit-bindgen.json:4` | 0.43.0 | ❌ Stale |
| wasm-tools | `wasm_toolchain.bzl` | 1.240.0 | ✅ OK |
| wasmtime | `wasmtime_toolchain.bzl` | 28.0.0 | ✅ OK |
| wac | `wasm_toolchain.bzl` | 0.8.0 | ✅ OK |

**Recommended Action**:
1. Update wit-bindgen registry to 0.46.0
2. Downgrade proc macro from 0.47.0 to 0.46.0 (or upgrade CLI to 0.47.0 if compatible)
3. Verify compatibility matrix still valid
