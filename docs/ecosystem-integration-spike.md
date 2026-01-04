# Ecosystem Integration Spike: LOOM and WSC

## Summary

This document assesses the feasibility of integrating pulseengine/loom (optimizer) and pulseengine/wsc (signing) into rules_wasm_component.

## LOOM (WebAssembly Optimizer)

### Current State

- **Repo**: https://github.com/pulseengine/loom
- **Status**: Active development, proof of concept
- **Releases**: None yet
- **Build**: Cargo/Rust only (no Bazel rules_rust setup)

### Capabilities

- Constant folding, strength reduction, function inlining
- 80-95% binary size reduction
- 10-30 µs optimization time
- Z3 SMT-based formal verification (optional)
- Component Model support

### Integration Approach

**Option A: Build from Source** (Recommended for now)
```starlark
# Use git_repository to fetch source
git_repository(
    name = "loom_src",
    remote = "https://github.com/pulseengine/loom.git",
    commit = "...",  # Pin to specific commit
)

# Build with rules_rust
rust_binary(
    name = "loom",
    srcs = ["@loom_src//:loom-cli/src/main.rs"],
    deps = [...],
)
```

**Option B: Download Prebuilt** (Future when releases exist)
```starlark
# Add to checksums/tools/loom.json
secure_download_tool(ctx, "loom", version, platform)
```

### Proposed Rule API

```starlark
load("@rules_wasm_component//wasm:defs.bzl", "wasm_optimize")

wasm_optimize(
    name = "my_component_optimized",
    component = ":my_component",
    # Optimization settings
    inline_functions = True,
    constant_fold = True,
    strength_reduce = True,
    # Verification (requires Z3)
    verify = False,  # Default off for speed
)
```

### Integration Complexity: MEDIUM-HIGH

- Requires building Rust project with workspace dependencies
- Z3 dependency for verification is complex
- No stable release to pin versions

### Recommendation

**Wait for LOOM v0.1.0 release** before integration. Once released:
1. Add checksums/tools/loom.json
2. Create toolchains/loom_toolchain.bzl
3. Create wasm/loom.bzl with wasm_optimize rule

---

## WSC (WebAssembly Signing)

### Current State

- **Repo**: https://github.com/pulseengine/wsc
- **Status**: Production-ready
- **Latest Release**: v0.4.0
- **Assets**: `wsc-cli.wasm`, `wsc-component.wasm`

### Capabilities

- Keyless signing via Sigstore/Fulcio/Rekor
- Offline verification (no network required)
- Embedded signatures in WASM modules
- WebAssembly modules signatures proposal compliant
- Both CLI and library (component) variants

### Integration Approach

**Run via Wasmtime** (Recommended)
```bash
# Sign a component
wasmtime run wsc-cli.wasm -- sign --keyless -i input.wasm -o signed.wasm

# Verify a component
wasmtime run wsc-cli.wasm -- verify --keyless -i signed.wasm
```

This fits perfectly with our existing wasmtime toolchain.

### Proposed Rule API

```starlark
load("@rules_wasm_component//wasm:defs.bzl", "wasm_sign", "wasm_verify")

# Sign a component (CI keyless signing)
wasm_sign(
    name = "my_component_signed",
    component = ":my_component",
    keyless = True,  # Use Sigstore OIDC
    # Optional: explicit key
    # private_key = ":signing_key",
)

# Verify signature (build-time check)
wasm_verify(
    name = "verify_my_component",
    component = ":my_component_signed",
    keyless = True,
    # Optional: identity constraints
    cert_identity = "github-actions[bot]@users.noreply.github.com",
    cert_oidc_issuer = "https://token.actions.githubusercontent.com",
)
```

### Integration Complexity: LOW

- WASM component runs via existing wasmtime toolchain
- Already have checksums/tools/wasmsign2-cli.json (older version)
- Just need to update to WSC and add new rules

### Recommended Implementation

1. **Update checksums**: Add `checksums/tools/wsc.json`
   ```json
   {
     "tool_name": "wsc",
     "github_repo": "pulseengine/wsc",
     "latest_version": "0.4.0",
     "versions": {
       "0.4.0": {
         "platforms": {
           "wasm": {
             "sha256": "...",
             "url_suffix": "wsc-cli.wasm"
           }
         }
       }
     }
   }
   ```

2. **Create signing rules**: `wasm/signing.bzl`
   - `wasm_sign` rule
   - `wasm_verify` rule
   - Uses wasmtime to run wsc-cli.wasm

3. **Documentation**: Add signing guide

---

## Priority Recommendation

| Tool | Priority | Reason |
|------|----------|--------|
| **WSC** | HIGH | Production-ready, simple integration, high user value |
| **LOOM** | MEDIUM | Wait for stable release, complex build dependencies |

### Immediate Actions

1. ✅ Create this feasibility document
2. 🔲 Integrate WSC signing (can start now)
3. 🔲 Wait for LOOM release, then integrate

### Timeline Estimate

- **WSC Integration**: 1-2 days
- **LOOM Integration**: 3-5 days (after release)

---

## Existing Signing Infrastructure

We already have `wasmsign2_cli_wasm` in MODULE.bazel:

```starlark
http_file(
    name = "wasmsign2_cli_wasm",
    downloaded_file_path = "wasmsign2.wasm",
    sha256 = "cb3125ce35704fed117bee95d56ab34576c6c1c8b940234aba5dc9893c224fa7",
    url = "https://github.com/pulseengine/wsc/releases/download/v0.2.7-rc.1/wsc-cli.wasm",
)
```

This is already WSC! Just need to:
1. Update to v0.4.0
2. Move to JSON registry
3. Create proper rules around it
