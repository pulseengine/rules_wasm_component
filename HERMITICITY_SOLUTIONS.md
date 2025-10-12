# Hermiticity Solutions - Deep Dive

## Problem Summary

When you have WASI SDK installed at `/usr/local/wasi-sdk`, Bazel's `cc_configure` extension auto-detects it and hardcodes paths into the C++ toolchain configuration:

```python
link_flags = ["-fuse-ld=/usr/local/wasi-sdk/bin/ld64.lld", ...]
```

This affects `rules_rust`'s `process_wrapper` (a host tool), causing non-hermetic builds.

## Investigation Findings

### Why cc_configure Runs Automatically

From rules_cc source:
```python
cc_configure_extension = module_extension(implementation = _cc_configure_extension_impl)

def _cc_configure_extension_impl(module_ctx):
    cc_autoconf_toolchains(name = "local_config_cc_toolchains")
    cc_autoconf(name = "local_config_cc")
```

**Key Finding**: `rules_cc` version 0.2.4 **always** runs `cc_configure` during module extension initialization. There are **no parameters to disable it**.

### What cc_configure Does

1. Scans system for C++ compilers (checks `/usr/local`, `/usr/bin`, etc.)
2. Finds `/usr/local/wasi-sdk/bin/clang`
3. Generates toolchain configuration with hardcoded paths
4. Creates `@@rules_cc++cc_configure_extension+local_config_cc//:toolchain`

### How It Affects rules_rust

From issue search: PR #3608 shows `rules_rust` explicitly uses `cc_toolchain` for linking.

The `process_wrapper` binary (used for all Rust compilations) links against the auto-configured C++ toolchain, inheriting the non-hermetic flags.

## Potential Solutions

### Solution 1: Remove System WASI SDK ⭐ **Recommended**

**Approach**: Remove `/usr/local/wasi-sdk` from your system

```bash
# Backup first if needed
sudo mv /usr/local/wasi-sdk /usr/local/wasi-sdk.backup

# Or fully remove
sudo rm -rf /usr/local/wasi-sdk
```

**Pros**:
- ✅ Immediate fix
- ✅ No code changes needed
- ✅ Project already provides hermetic WASI SDK (version 27)

**Cons**:
- ❌ May affect other projects using system WASI SDK
- ❌ Need to repeat on each developer machine

**Impact**: After removal, `cc_configure` will use system Xcode/clang instead, which is fine for host tools.

### Solution 2: Override Toolchain Priority via .bazelrc

**Approach**: Register a higher-priority C++ toolchain

```python
# In .bazelrc
build --extra_toolchains=@bazel_tools//tools/cpp:toolchain
```

**Status**: ⚠️ Needs testing

**Pros**:
- ✅ Per-project configuration
- ✅ Doesn't require system changes
- ✅ Can be committed to repo

**Cons**:
- ❌ May not override auto-configured toolchain
- ❌ Bazel toolchain resolution is complex
- ❌ Needs verification it actually works

**Next Steps**: Test if this successfully overrides the auto-configured toolchain.

### Solution 3: Patch rules_cc to Add Disable Flag

**Approach**: Submit PR to rules_cc to add optional parameter

```python
# Proposed API
cc_configure = use_extension("@rules_cc//cc:extensions.bzl", "cc_configure")
cc_configure.configure(auto_detect = False)  # New parameter
```

**Status**: 🔴 Not available

**Pros**:
- ✅ Clean solution
- ✅ Helps entire Bazel ecosystem

**Cons**:
- ❌ Requires upstream changes
- ❌ Long timeline (months to acceptance)
- ❌ Maintenance burden

**Next Steps**:
1. Search for existing issues in bazelbuild/rules_cc
2. Propose RFC if none exists
3. Implement and submit PR

### Solution 4: Configure PATH to Hide WASI SDK

**Approach**: Manipulate PATH during Bazel repository phase

```python
# In a custom repository rule
repository_ctx.execute(
    ["env", "PATH=/usr/bin:/bin", "bazel", "..."],
)
```

**Status**: ⚠️ Complex, may not work

**Pros**:
- ✅ Doesn't require removing system files

**Cons**:
- ❌ Bazel may not respect PATH changes during cc_configure
- ❌ cc_configure uses absolute path detection, not just PATH
- ❌ Very hacky

**Likelihood of success**: Low

### Solution 5: Accept as Known Limitation

**Approach**: Document the issue and provide workarounds

**Status**: ✅ Already done (HERMITICITY.md)

**Pros**:
- ✅ Honest about current state
- ✅ No additional complexity
- ✅ Builds still work correctly

**Cons**:
- ❌ Not truly hermetic
- ❌ May cause issues in some environments

## Related Upstream Issues

### Found via gh CLI search:

1. **bazelbuild/rules_rust#3619**: "Can't use rules_rust on windows with zig hermetic_cc_toolchain"
   - Shows `rules_rust` has hermetic C++ toolchain challenges
   - Different issue but similar root cause

2. **bazelbuild/rules_rust#3608**: "Ensure the library search path from cc_toolchain is preferred"
   - Shows `rules_rust` explicitly uses `cc_toolchain`
   - Confirms the dependency on auto-configured toolchain

3. **bazelbuild/rules_rust#3535**: "Bump rules_cc to 0.2.4"
   - Recent rules_cc upgrade
   - May have changed cc_configure behavior

## Testing Solutions

### Test Solution 1 (Remove WASI SDK)

```bash
# Backup
sudo mv /usr/local/wasi-sdk /usr/local/wasi-sdk.backup

# Clean rebuild
bazel clean --expunge
bazel build --execution_log_json_file=/tmp/test.log //tools/checksum_updater:checksum_updater

# Analyze hermiticity
python3 tools/hermetic_test/analyze_exec_log.py /tmp/test.log

# Restore if needed
sudo mv /usr/local/wasi-sdk.backup /usr/local/wasi-sdk
```

### Test Solution 2 (Toolchain Override)

```bash
# Add to .bazelrc.test
echo "build --extra_toolchains=@bazel_tools//tools/cpp:toolchain" > .bazelrc.test

# Test
bazel clean
bazel build --bazelrc=.bazelrc.test --execution_log_json_file=/tmp/test.log //tools/checksum_updater:checksum_updater

# Check if it helped
grep "wasi-sdk" /tmp/test.log
```

## Recommended Action Plan

### Short-term (Today)

1. ✅ Document the issue (done - HERMITICITY.md)
2. ✅ Remove cc_configure from MODULE.bazel (done)
3. **Recommended**: Remove `/usr/local/wasi-sdk` if not needed for other projects

### Medium-term (This Week)

1. Test Solution 2 (toolchain override in .bazelrc)
2. Search bazelbuild/rules_cc for existing issues about disabling cc_configure
3. If none exist, create issue proposing optional auto-detection

### Long-term (Months)

1. Monitor rules_cc and rules_rust for improvements
2. Consider contributing PR to rules_cc if feature would be accepted
3. Re-evaluate hermiticity when rules_cc 0.3+ is released

## Conclusion

**The best immediate solution is removing `/usr/local/wasi-sdk`** because:
- You're not using it (project has hermetic WASI SDK 27)
- It's a manual installation that most users don't have
- No code changes or upstream work required
- Instant fix

The root cause (automatic cc_configure) is a Bazel ecosystem issue that affects the broader community and would benefit from an upstream fix.

## Upstream Work

### RFC and Fork

We've created a fork of rules_cc to develop a proper upstream solution:

- **Fork**: https://github.com/avrabe/rules_cc
- **RFC Issue**: https://github.com/avrabe/rules_cc/issues/1
- **Proposal**: Add `auto_detect` parameter to `cc_configure` extension

The RFC proposes adding a tag class to control auto-detection:

```starlark
# Proposed API
cc_configure = use_extension("@rules_cc//cc:extensions.bzl", "cc_configure")
cc_configure.configure(auto_detect = False)
```

This would allow users to opt out of system toolchain detection while maintaining backwards compatibility (default `auto_detect = True`).

See the full RFC at: https://github.com/avrabe/rules_cc/issues/1
