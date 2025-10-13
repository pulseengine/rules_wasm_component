# RFC: Add Optional Auto-Detection Control to rules_cc cc_configure Extension

## Target: [bazelbuild/rules_cc](https://github.com/bazelbuild/rules_cc)

## Summary

Propose adding an optional parameter to the `cc_configure` module extension to disable automatic C++ toolchain detection. This would allow users to opt for fully hermetic builds when they don't want system toolchain auto-detection.

## Problem Statement

### Current Behavior

The `cc_configure` extension in rules_cc **always** auto-detects system C++ toolchains:

```python
# In cc/extensions.bzl
def _cc_configure_extension_impl(ctx):
    cc_autoconf_toolchains(name = "local_config_cc_toolchains")
    cc_autoconf(name = "local_config_cc")  # Always runs
    # ...
```

During auto-detection (`cc_autoconf`), the extension:
1. Scans system paths (`/usr/local`, `/usr/bin`, etc.)
2. Detects compilers (clang, gcc, etc.)
3. Hardcodes absolute paths into generated toolchain configuration
4. Creates `@@rules_cc++cc_configure_extension+local_config_cc//:toolchain`

### The Issue

**This breaks hermeticity** when:
- Users have compilers installed in non-standard locations
- System tools are different versions than expected
- Builds need to be reproducible across environments
- Users want to use only Bazel-managed hermetic toolchains

### Real-World Example

```bash
# User has WASI SDK installed at /usr/local/wasi-sdk
$ ls /usr/local/wasi-sdk/bin/clang
/usr/local/wasi-sdk/bin/clang  # Exists

# cc_configure detects it and hardcodes paths:
$ cat $(bazel info output_base)/external/rules_cc++cc_configure_extension+local_config_cc/BUILD

link_flags = ["-fuse-ld=/usr/local/wasi-sdk/bin/ld64.lld", ...]
```

This affects downstream tools like `rules_rust`'s `process_wrapper`, which uses the auto-configured C++ toolchain and inherits non-hermetic flags.

### Existing Workaround Doesn't Work with Bzlmod

There's an environment variable `BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1`, but:
- **Does NOT work** with bzlmod module extensions
- Module extensions don't see `--repo_env` flags
- Only works with WORKSPACE (legacy)

```bash
# These don't work:
$ export BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1
$ bazel build --repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1 //target
# Still detects and uses system toolchain
```

## Proposed Solution

### API Design

Add a tag class to allow users to configure auto-detection behavior:

```starlark
# In cc/extensions.bzl

_configure = tag_class(attrs = {
    "auto_detect": attr.bool(
        default = True,
        doc = """
        Whether to automatically detect system C++ toolchains.

        When True (default): Scans system for compilers and generates toolchain config.
        When False: Generates minimal empty toolchain config, allowing users to
                   provide their own hermetic toolchains.
        """,
    ),
})

cc_configure_extension = module_extension(
    implementation = _cc_configure_extension_impl,
    tag_classes = {"configure": _configure},
)
```

### Implementation

```python
def _cc_configure_extension_impl(module_ctx):
    # Check if user configured auto_detect
    auto_detect = True
    for mod in module_ctx.modules:
        for configure in mod.tags.configure:
            auto_detect = configure.auto_detect
            break  # First wins

    if auto_detect:
        # Current behavior - auto-detect system toolchains
        cc_autoconf_toolchains(name = "local_config_cc_toolchains")
        cc_autoconf(name = "local_config_cc")
    else:
        # New behavior - skip auto-detection
        # Reuse existing BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1 logic
        _create_empty_config(module_ctx, "local_config_cc_toolchains")
        _create_empty_config(module_ctx, "local_config_cc")

    # ... rest of implementation
```

### Usage

```starlark
# In MODULE.bazel

bazel_dep(name = "rules_cc", version = "0.2.5")  # Future version

# Disable auto-detection for hermetic builds
cc_configure = use_extension("@rules_cc//cc:extensions.bzl", "cc_configure")
cc_configure.configure(auto_detect = False)

# Then provide your own hermetic toolchains
register_toolchains("//toolchains:my_hermetic_cc_toolchain")
```

## Benefits

1. **Hermeticity**: Users can opt out of system toolchain detection
2. **Reproducibility**: Builds work identically across different environments
3. **Explicit Configuration**: Clear control over toolchain sources
4. **Backwards Compatible**: Default behavior unchanged (`auto_detect = True`)
5. **Consistent with Bazel Philosophy**: Hermetic builds by default option

## Alternatives Considered

### Alternative 1: Do Nothing

**Pros**: No work required
**Cons**: Hermiticity issues persist for bzlmod users

### Alternative 2: Make env var work with bzlmod

Try to make `BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN` work with module extensions.

**Pros**: Uses existing code
**Cons**:
- Module extensions have limited environment access by design
- Would be a workaround rather than proper API
- Doesn't follow bzlmod best practices

### Alternative 3: Disable by default, require opt-in

Change default to `auto_detect = False`.

**Pros**: Hermetic by default
**Cons**:
- **Breaking change** for all users
- Many users rely on auto-detection
- Not acceptable for rules_cc

## Migration Path

### Phase 1: Add Parameter (rules_cc 0.2.5)

- Add `configure` tag class with `auto_detect` parameter
- Default to `True` (current behavior)
- Update documentation

### Phase 2: Adoption

Users who want hermetic builds explicitly set:

```starlark
cc_configure.configure(auto_detect = False)
```

### Phase 3: Future (Optional)

Consider making `auto_detect = False` the default in a major version (2.0.0), with migration guide.

## Testing Plan

1. **Test auto_detect = True**: Verify existing behavior unchanged
2. **Test auto_detect = False**: Verify no system detection occurs
3. **Test hermiticity**: Run builds with execution log analysis
4. **Test cross-platform**: Verify on Linux, macOS, Windows

## Documentation Updates

1. Update `cc/extensions.bzl` docstrings
2. Add section to rules_cc README about hermetic builds
3. Create migration guide for users wanting hermetic toolchains
4. Update examples repository

## Implementation Estimate

- **Code changes**: ~100 lines
- **Tests**: ~200 lines
- **Documentation**: ~50 lines
- **Total effort**: 1-2 days for experienced contributor

## References

- Existing code: [cc/private/toolchain/cc_configure.bzl](https://github.com/bazelbuild/rules_cc/blob/main/cc/private/toolchain/cc_configure.bzl)
- Similar pattern: [rules_python module extension](https://github.com/bazelbuild/rules_python/blob/main/python/extensions/python.bzl)
- Related: rules_rust hermiticity issues with C++ toolchain detection

## Open Questions

1. Should we add more granular control (e.g., which compilers to detect)?
2. Should there be a way to provide explicit toolchain paths instead of auto-detection?
3. How should this interact with `--incompatible_enable_cc_toolchain_resolution`?

## Proof of Concept

Working implementation:
- Fork: https://github.com/avrabe/rules_cc
- Branch: `feature/optional-cc-toolchain-auto-detect`
- Commit: `7215331f9e53f80070dc01c4a95a0f9c53ea477b`
- RFC Issue: https://github.com/avrabe/rules_cc/issues/1

## Next Steps

1. Gather feedback from rules_cc maintainers
2. Refine API based on feedback
3. Submit PR to bazelbuild/rules_cc
4. Iterate based on code review

---

**Date**: 2025-10-13
**Discussion**: https://github.com/avrabe/rules_cc/issues/1
