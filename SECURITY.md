# Security Notice

## Current Security Limitations

**⚠️ WARNING: This repository contains security issues that make it unsuitable for production use.**

### 1. Placeholder Checksums

The following files contain placeholder SHA256 checksums instead of real cryptographic hashes:

- `toolchains/wasm_toolchain.bzl` - Lines containing `"1234567890abcdef"`
- `toolchains/wasi_sdk_toolchain.bzl` - Lines containing `"1234567890abcdef"`

**Risk**: Downloaded tools cannot be verified for integrity, making builds vulnerable to supply chain attacks.

**Impact**: 
- Downloaded binaries could be tampered with
- No verification of tool authenticity
- Potential for malicious code execution

### 2. Git Override Dependencies

The MODULE.bazel file relies on a forked version of rules_rust:

```starlark
git_override(
    module_name = "rules_rust",
    commit = "1945773a",
    remote = "https://github.com/avrabe/rules_rust.git",
)
```

**Risk**: Dependency on unofficial fork introduces supply chain risk.

## Recommendations

### For Development Use
1. Use only in trusted, isolated environments
2. Verify all downloaded tools manually
3. Monitor network traffic during builds

### For Production Use
**DO NOT USE** until these issues are resolved:

1. **Replace placeholder checksums** with real SHA256 hashes for all tool downloads
2. **Use official rules_rust releases** instead of git overrides
3. **Implement checksum verification** in all download operations
4. **Add security testing** to CI pipeline

## Responsible Disclosure

If you discover additional security issues, please follow responsible disclosure practices:

1. **Do not** create public issues for security vulnerabilities
2. **Do not** commit fixes for security issues without review
3. **Contact** the maintainers privately first

## Timeline for Fixes

These security issues are tracked and will be addressed before any production release:

- [ ] Replace all placeholder checksums with real values
- [ ] Remove dependency on forked rules_rust
- [ ] Add checksum verification mechanisms
- [ ] Security review of all download operations

**Estimated timeline**: 2-3 months for complete security hardening.