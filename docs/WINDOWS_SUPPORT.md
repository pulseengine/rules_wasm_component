# Windows Platform Support

## Current Status (2025-11-12)

| Component | Linux | macOS | Windows | Notes |
|-----------|-------|-------|---------|-------|
| **WASI SDK** | ✅ | ✅ | ✅ | Full support with .exe extensions |
| **C/C++ Components** | ✅ | ✅ | ✅ | All toolchain binaries work correctly |
| **TinyGo** | ✅ | ✅ | ✅ | Cross-platform compatibility verified |
| **Rust wasm32-wasip2** | ✅ | ✅ | ❌ | Blocked by missing wasm-component-ld.exe |
| **JavaScript** | ✅ | ✅ | ✅ | Node.js and jco work on Windows |
| **WASM Tools** | ✅ | ✅ | ✅ | All validation and composition tools work |

## Known Limitation: Rust wasm32-wasip2 on Windows

### The Issue

Windows builds of Rust wasm32-wasip2 components fail with:

```
error: linker `wasm-component-ld.exe` not found
  |
  = note: program not found
```

### Root Cause

The `wasm-component-ld` linker is required for the wasm32-wasip2 target. This tool:
- Wraps `wasm-ld` (LLVM's WASM linker)
- Converts core WASM modules to WASM components
- Is distributed as part of the Rust compiler toolchain

**Problem**: The Windows rustc distribution does not include `wasm-component-ld.exe`, or it's not in the expected PATH.

### What We Fixed

The rules_wasm_component codebase now correctly handles Windows:

1. **WASI SDK binaries** - All tool paths include `.exe` extension on Windows (commit 471b2a8, e137324, 44887aa)
2. **Platform detection** - Transitions detect Windows execution platform correctly
3. **Linker configuration** - Adds `.exe` extension to wasm-component-ld on Windows (commit cef738e)

The infrastructure works - the Rust toolchain just doesn't provide the required binary yet.

### Evidence from CI

The wasm32-wasip2 standard library IS installed:
```
rust-std-1.90.0-wasm32-wasip2.tar.xz
```

But the linker tool is missing:
```
ERROR: Compiling Rust cdylib hello_component_wasm_lib_release_wasm_base (1 files) failed
error: linker `wasm-component-ld.exe` not found
```

### Workarounds

**Option 1: Use wasm32-wasip1 (Older WASI Preview 1)**
```python
# In platforms/BUILD.bazel, use wasip1 instead of wasip2
platform(
    name = "wasm32-wasi",
    constraint_values = [
        "@platforms//cpu:wasm32",
        "@platforms//os:wasi",
        "@rules_rust//rust/platform:wasi_preview_1",  # Use Preview 1
    ],
)
```

**Option 2: Build wasm-component-ld Manually**
```bash
# Clone Rust repository
git clone https://github.com/rust-lang/rust.git
cd rust

# Build the linker tool
cargo build --release -p wasm-component-ld

# Add to PATH
copy target\release\wasm-component-ld.exe %USERPROFILE%\.cargo\bin\
```

**Option 3: Wait for Rust Ecosystem**

Track these Rust issues:
- Rust Windows wasm32-wasip2 support maturity
- wasm-component-ld distribution in rustup

### Future Resolution

This will be resolved when:
1. Rust officially distributes `wasm-component-ld.exe` with Windows rustc
2. Or rustup includes it when installing the wasm32-wasip2 target
3. Or Bazel rules_rust provides a hermetic wasm-component-ld for Windows

## Testing on Windows

### What Works

```bash
# C/C++ WASM components
bazel build //examples/cpp_component:...

# JavaScript components
bazel build //examples/js_component:...

# TinyGo components
bazel build //examples/tinygo:...

# WASM composition and validation
bazel test //tests/composition:...
```

### What Doesn't Work

```bash
# Rust wasm32-wasip2 components
bazel build //examples/basic:hello_component_release
# ERROR: linker `wasm-component-ld.exe` not found
```

## Commits and Progress

| Commit | Description | Status |
|--------|-------------|--------|
| 471b2a8 | WASI SDK Windows .exe extension support | ✅ Complete |
| e137324 | CC toolchain .exe paths | ✅ Complete |
| 44887aa | String replacement fix for format errors | ✅ Complete |
| b6b1b15 | Initial Windows linker detection in select() | ⚠️ Didn't work (wrong context) |
| 8df9edb | Move detection to transition | ⚠️ Wrong settings path |
| cef738e | Use correct rules_rust settings path | ✅ Works (but tool missing) |

## Recommendation

**For production use**: Document that Windows Rust wasm32-wasip2 support is experimental/unsupported until the Rust ecosystem provides the required tooling.

**For contributors**: All Windows compatibility work is complete on the rules_wasm_component side. The blocker is upstream in Rust's Windows distribution.

**For users**: Use Linux or macOS for Rust WASM component development, or use wasm32-wasip1 (Preview 1) on Windows as a temporary workaround.
