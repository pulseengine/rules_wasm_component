# Hermiticity Analysis and Solutions

## Overview

This document describes the hermiticity investigation, findings, and solutions for `rules_wasm_component`.

## Problem Statement

Non-hermetic builds occur when Bazel build actions depend on files or tools outside of Bazel's managed workspace. This can lead to:
- Build failures on different machines
- Non-reproducible builds
- CI/CD inconsistencies

## Investigation Results

### ✅ Completed Work

1. **Hermiticity CI Check**
   - Added GitHub Actions workflow that runs on every PR
   - Tests all component types (Rust, Go, C++, JavaScript)
   - Uses Bazel execution log analysis (cross-platform, no sudo required)

2. **Hermiticity Testing Tools**
   - `tools/hermetic_test/analyze_exec_log.py` - Bazel-native log analyzer
   - `tools/hermetic_test/macos_hermetic_test.sh` - fs_usage tracer for macOS
   - `tools/hermetic_test/linux_hermetic_test.sh` - strace tracer for Linux
   - `tools/hermetic_test/comprehensive_test.sh` - Tests all target types

3. **Go Toolchain Hermiticity Fix** (Issue #162 ✅)
   - Added `pure = "on"` to all Go tool binaries
   - Disabled CGO to prevent system linker detection
   - **Result**: ✅ HERMETIC - All Go components and tools pass hermiticity tests

4. **MODULE.bazel Cleanup**
   - Removed explicit `cc_configure` extension usage
   - Removed `cc_compatibility` proxy extension
   - **Result**: ✅ All builds still work correctly

### 🔴 Rust Hermiticity Issue (Issue #163)

**Status**: Known Limitation

**Root Cause**:
- `rules_cc` automatically runs `cc_configure` extension
- On systems with WASI SDK installed at `/usr/local/wasi-sdk`, `cc_configure` detects it
- `rules_rust`'s `process_wrapper` (host tool) uses the auto-configured C++ toolchain
- This creates link arguments like: `--codegen=link-arg=-fuse-ld=/usr/local/wasi-sdk/bin/ld64.lld`

**Investigation Findings**:
```bash
# Even after removing explicit cc_configure from MODULE.bazel:
$ bazel build --execution_log_json_file=/tmp/exec.log //tools/checksum_updater:checksum_updater
$ python3 tools/hermetic_test/analyze_exec_log.py /tmp/exec.log

⚠️  WARNING: Found 86 potential hermiticity issue(s)

Suspicious Tool Usage (43 instances):
  • Rustc: --codegen=link-arg=-fuse-ld=/usr/local/wasi-sdk/bin/ld64.lld
    Target: @@rules_rust+//util/process_wrapper:process_wrapper
```

**Why Removing cc_configure Didn't Fully Fix It**:
1. `rules_cc` version 0.2.4 automatically creates `cc_configure` extension
2. This is independent of user MODULE.bazel configuration
3. The extension runs during repository setup phase
4. `rules_rust` host tools inherit the configured C++ toolchain

**Affected Environments**:
The Rust hermiticity issue **ONLY** affects:
- Systems with WASI SDK installed at `/usr/local/wasi-sdk`
- After `cc_configure` auto-detection runs
- Users building Rust components with `rules_wasm_component`

**Not Affected**:
- Clean CI environments without system WASI SDK
- Systems without WASI SDK at `/usr/local/wasi-sdk`
- Non-Rust components (Go, C++, JavaScript)

## Hermiticity Test Results

| Component Type | Hermiticity Status | Notes |
|---------------|-------------------|-------|
| Go Components | ✅ PASS | pure = "on" + CGO disabled |
| Go Tools | ✅ PASS | Hermetic binaries |
| C++ Components | ✅ PASS | Uses hermetic WASI SDK |
| JavaScript/TypeScript | ✅ PASS | Hermetic Node.js + jco |
| Rust Components | ⚠️ CONDITIONAL | Fails only with system WASI SDK at /usr/local/wasi-sdk |

## Potential Solutions for Rust Issue

### Option 1: Disable cc_configure (Not Recommended)
**Pros**: Would prevent auto-detection
**Cons**:
- May break other Bazel rules expecting auto-configured C++ toolchain
- Would require manual C++ toolchain configuration
- Complex to implement with bzlmod

### Option 2: Configure rules_rust to Use Specific C++ Toolchain (Complex)
**Pros**: Targeted fix for rules_rust
**Cons**:
- Requires patches to rules_rust
- May not be accepted upstream
- Maintenance burden

### Option 3: Document as Known Limitation (✅ Recommended)
**Pros**:
- Honest about current state
- Provides workaround for affected users
- Doesn't break existing functionality
**Cons**:
- Issue remains for affected users
- Not a technical fix

## Recommended Workaround

For users affected by the Rust hermiticity issue:

1. **CI/CD Environments**: Ensure WASI SDK is not installed at `/usr/local/wasi-sdk`
2. **Development Machines**:
   - Remove system WASI SDK: `sudo rm -rf /usr/local/wasi-sdk`
   - Let Bazel manage WASI SDK via hermetic toolchains
   - Or accept the non-hermetic behavior (builds still work correctly)

## Conclusion

**Summary**:
- ✅ Hermiticity CI check implemented and working
- ✅ Go toolchain hermiticity fixed
- ✅ C++, JavaScript, and most language toolchains are hermetic
- ✅ Removed unnecessary cc_configure extension from MODULE.bazel
- ⚠️ Rust hermiticity issue documented as known limitation

**Impact**:
- Minimal - Only affects users with system WASI SDK at specific path
- Builds still work correctly even with the hermiticity issue
- CI environments are typically clean and unaffected

**Next Steps**:
- Monitor rules_cc and rules_rust for upstream improvements
- Consider contributing to rules_rust for better C++ toolchain control
- Keep documentation updated as toolchain ecosystem evolves
