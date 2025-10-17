# Hermetic Testing Guide for rules_wasm_component

This guide explains how to properly test for build hermeticity in rules_wasm_component.

## Understanding Hermeticity in Bazel

**Hermetic build**: A build that produces the same output regardless of the host environment, using only explicitly declared dependencies.

### Key Concepts

1. **Detection vs Usage**: Just because Bazel *detects* system tools doesn't mean they're *used* for all builds
2. **Platform Constraints**: Toolchains have `target_compatible_with` that determines when they match
3. **Host vs Target**: Builds can target different platforms (host: darwin_arm64, target: wasm32-wasip2)

## What Should Be Hermetic

| Build Type | Should Be Hermetic? | Why |
|------------|---------------------|-----|
| WASM Component builds | ✅ YES | Library authors control the output |
| Host tools (checksum_updater, etc) | ❌ NO | User's development environment |
| C++ examples for docs | ❌ NO | User's C++ toolchain |

## Common Hermiticity Mistakes

### ❌ Mistake 1: "Detection = Usage"

```bash
# Wrong assumption
$ bazel query @local_config_cc//...
# Shows system paths detected
→ "This breaks WASM hermeticity!"

# Reality check needed
$ bazel build //examples:wasm --toolchain_resolution_debug=...
→ Actually uses @wasi_sdk, not @local_config_cc
```

**Lesson**: Always verify which toolchain is *selected*, not just what's *detected*.

### ❌ Mistake 2: "System Paths = Bad"

```bash
# Observed
bazel aquery //examples:wasm | grep /usr/local
→ Found system paths

# Wrong conclusion
"System paths leak into WASM builds!"

# Should check
bazel aquery //examples:wasm | grep /usr/local | grep -v "@wasi_sdk"
→ System paths only from our hermetic @wasi_sdk, not from host
```

**Lesson**: Distinguish between hermetic toolchains installed in system locations vs actual system dependency leakage.

### ❌ Mistake 3: "One Toolchain for Everything"

```bash
# Wrong mental model
cc_configure auto-detects → creates ONE toolchain → used for ALL builds

# Correct model
cc_configure auto-detects → creates @local_config_cc with HOST constraints
rules_wasm_component provides → @wasi_sdk with WASM constraints
Bazel selects based on target platform
```

**Lesson**: Multiple cc_toolchains coexist, platform constraints determine selection.

## Hermetic Testing Strategy

### 1. Clean Build Test

**Purpose**: Verify builds work without any cached state

```bash
bazel clean --expunge
bazel build //examples/basic:hello_component
```

**What it tests**: No hidden dependencies on cached artifacts

### 2. Toolchain Selection Test

**Purpose**: Verify correct toolchain is selected for each platform

```bash
# For WASM builds
bazel build //examples/basic:hello_component_wasm_lib_release_wasm_base \
  --toolchain_resolution_debug='@bazel_tools//tools/cpp:toolchain_type' 2>&1 | \
  grep -E "(Selected|Rejected|wasi|local_config)"
```

**Expected output**:
```
Rejected toolchain @@+wasi_sdk+wasi_sdk//:wasm_cc_toolchain; mismatching values: wasm32, wasi
Selected @@rules_cc++cc_configure_extension+local_config_cc//:cc-compiler-darwin_arm64
```

Wait, that's backwards! For WASM targets, should be:
```
For wasm32-wasip2 target:
  Rejected: @local_config_cc (mismatching: darwin_arm64)
  Selected: @wasi_sdk//:cc_toolchain (matches: wasm32, wasi)
```

**What it tests**: Platform constraints enforce correct toolchain selection

### 3. System Path Leakage Test

**Purpose**: Verify WASM artifacts don't reference system paths

```bash
# Get compilation/linking commands for WASM target
bazel aquery //examples/basic:hello_component_wasm_lib_release_wasm_base \
  'mnemonic("RustcCompile|CppLink", //examples/basic:hello_component_wasm_lib_release_wasm_base)'

# Check for unexpected system paths (excluding @wasi_sdk)
bazel aquery ... | grep -v "@wasi_sdk" | grep "/usr/local"
```

**What it tests**: No accidental system dependency leakage

### 4. Reproducibility Test

**Purpose**: Verify builds produce identical outputs

```bash
# First build
bazel build //examples/basic:hello_component_wasm_lib_release_wasm_base
shasum -a 256 bazel-bin/examples/basic/hello_component_wasm_lib_release_wasm_base.wasm

# Rebuild
bazel clean
bazel build //examples/basic:hello_component_wasm_lib_release_wasm_base
shasum -a 256 bazel-bin/examples/basic/hello_component_wasm_lib_release_wasm_base.wasm

# Compare checksums
```

**What it tests**: No timestamp, random, or environment-dependent artifacts

### 5. Constraint Verification Test

**Purpose**: Verify toolchains have correct platform constraints

```bash
# Check WASI SDK constraints
bazel query 'kind(toolchain, @wasi_sdk//...)' --output=build | \
  grep "target_compatible_with"

# Should show
target_compatible_with = ["@platforms//cpu:wasm32", "@platforms//os:wasi"]
```

**What it tests**: Toolchain metadata is correctly configured

### 6. Environment Independence Test

**Purpose**: Verify builds don't require specific environment variables

```bash
# Build with minimal environment
env -i HOME="$HOME" USER="$USER" PATH="/usr/bin:/bin" \
  bazel build //examples/basic:hello_component
```

**What it tests**: No hidden environment variable dependencies

### 7. Host/Target Separation Test

**Purpose**: Verify host and WASM builds use different toolchains

```bash
# Build host tool
bazel build //tools/checksum_updater:checksum_updater \
  --toolchain_resolution_debug='@bazel_tools//tools/cpp:toolchain_type' 2>&1 | \
  grep "Selected"

# Should use @local_config_cc

# Build WASM target
bazel build //examples/basic:hello_component \
  --toolchain_resolution_debug='@bazel_tools//tools/cpp:toolchain_type' 2>&1 | \
  grep "Selected"

# Should use @wasi_sdk
```

**What it tests**: Platform-based toolchain selection works correctly

## Automated Testing

Run the comprehensive hermetic test suite:

```bash
./.hermetic_test.sh
```

This runs all 7 tests and provides a clear pass/fail report.

## CI Integration

Add to `.github/workflows/hermetic-test.yml`:

```yaml
name: Hermetic Build Tests

on: [push, pull_request]

jobs:
  hermetic-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Bazel
        uses: bazel-contrib/setup-bazel@0.8.1
      - name: Run hermetic tests
        run: ./.hermetic_test.sh
```

## Troubleshooting

### Issue: "Found system paths in WASM build"

**Diagnosis**:
```bash
bazel aquery //examples:wasm | grep /usr/local
```

**Fix checklist**:
1. Are paths from `@wasi_sdk`? (hermetic, OK)
2. Are paths from `@local_config_cc`? (check toolchain selection)
3. Verify platform constraints on both toolchains

### Issue: "Build not reproducible"

**Common causes**:
- Timestamps embedded in artifacts
- Random identifiers
- Environment variable leakage
- Non-hermetic dependencies

**Fix**:
```bash
# Check for environment variable usage
bazel aquery //examples:wasm --output=text | grep "Environment"

# Check for non-hermetic repository rules
bazel query 'kind(".*_repository", //external:*)'
```

### Issue: "Wrong toolchain selected"

**Diagnosis**:
```bash
bazel build //examples:wasm \
  --toolchain_resolution_debug='@bazel_tools//tools/cpp:toolchain_type' \
  2>&1 | grep -A 10 "Performing resolution"
```

**Fix**:
- Verify `target_compatible_with` on toolchains
- Check that platform is correctly set in transitions
- Ensure toolchain registration order in MODULE.bazel

## Best Practices

1. **Test at multiple levels**:
   - Unit: Individual toolchain constraints
   - Integration: Full WASM build pipeline
   - System: Clean environment builds

2. **Automate hermetic tests**:
   - Run on every PR
   - Block merges on failures
   - Include in release checklist

3. **Document expectations**:
   - What should be hermetic vs not
   - Why certain system dependencies are OK
   - How to verify hermeticity

4. **Monitor over time**:
   - Track artifact checksums
   - Watch for new system dependencies
   - Review toolchain changes carefully

## Related Documentation

- [Issue #163: Hermiticity Analysis](https://github.com/pulseengine/rules_wasm_component/issues/163)
- [Bazel Platform Documentation](https://bazel.build/extending/platforms)
- [Bazel Toolchain Resolution](https://bazel.build/extending/toolchains)

## Summary

**Key Takeaway**: Hermetic testing requires verifying *what gets used*, not just *what gets detected*.

**The Three-Step Check**:
1. ✅ Clean build succeeds
2. ✅ Correct toolchain selected (via `--toolchain_resolution_debug`)
3. ✅ Reproducible artifacts (checksums match)

If all three pass, your builds are hermetic where they need to be.
