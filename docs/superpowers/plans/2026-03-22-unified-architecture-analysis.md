# Unified Architecture Analysis: Issues #257, #253, #250

## Executive Summary

The three feature issues are **interconnected** — they're different facets of the same architectural problem: the codebase grew organically per-language, duplicating logic that should be shared. Solving them together yields compounding benefits. Solving them separately creates friction.

**Recommended approach: tackle them in reverse order (250 → 253 → 257)** because each builds on the previous:

1. **#250 Meta-Toolchain** simplifies the download/registration surface
2. **#253 Unified Rule** eliminates per-language duplication using the simplified toolchain
3. **#257 Multi-Bundle P2/P3** becomes trivial once tools and rules are unified

---

## Current State (measured, not estimated)

| Metric | Value |
|--------|-------|
| Language-specific rule files | 7 files, 4,041 LOC |
| Duplicated patterns across rules | ~300-400 LOC (WasmComponentInfo, WIT, validation, attrs) |
| Module extensions for toolchains | 8 separate extensions |
| `register_toolchains()` calls in MODULE.bazel | 14 |
| Lines in MODULE.bazel for toolchain setup | 130+ |
| Tools in checksum registry | 18 |
| Full download size (all languages) | ~950 MB |
| Minimal download (Rust only) | ~50 MB |

### Key Pain Points

1. **User onboarding**: A new user must understand 8 extensions, 14 toolchain registrations, 4 different rule names
2. **Adding wasi_version**: Required touching 4 files with identical changes (Rust, Python component, Python binary, future Go/C++/JS)
3. **P3 support**: Each language needs independent P3 integration work instead of one central change
4. **Maintenance**: Bug fixes in WIT handling, validation, or provider creation must be replicated across 7 files

---

## Analysis by Issue

### Issue #250: Meta-Toolchain

**Problem**: 8 separate `use_extension()` calls, 14 `register_toolchains()`, ~130 lines of MODULE.bazel boilerplate.

**Current MODULE.bazel flow**:
```starlark
# User must write ALL of this:
wasm_toolchain.register(name="wasm_tools", ...)
use_repo(wasm_toolchain, "wasm_tools_toolchains")
register_toolchains("@wasm_tools_toolchains//:wasm_tools_toolchain")

wasmtime.register(name="wasmtime", ...)
use_repo(wasmtime, "wasmtime_toolchain")
register_toolchains("@wasmtime_toolchain//:wasmtime_toolchain")

wkg.register(name="wkg", ...)
use_repo(wkg, "wkg_toolchain")
register_toolchains("@wkg_toolchain//:wkg_toolchain_def")

# ... repeat for wasi_sdk, tinygo, jco, binaryen, cpp ...
```

**Proposed**:
```starlark
# User writes THIS:
wasm = use_extension("@rules_wasm_component//wasm:extensions.bzl", "wasm")
wasm.toolchains(
    bundle = "stable-2026-03",   # or "experimental-p3"
    languages = ["rust", "go"],  # only download what you need
)
use_repo(wasm, "wasm_toolchains")
register_toolchains("@wasm_toolchains//:all")
```

**Impact on STPA**: This directly addresses SC-001 (checksum verification) by having ONE download path instead of 8. It addresses H-003 (eager loading) by making language selection explicit — you don't download Python toolchain unless you say `languages = ["python"]`.

**Risk**: Low. The `tool_registry.download()` already unifies the download logic. The extension layer just needs consolidation.

### Issue #253: Unified wasm_component Rule

**Problem**: 7 rule implementations with ~300-400 LOC of shared patterns.

**Duplicated across ALL rules** (concrete code):
```starlark
# Pattern 1: WasmComponentInfo creation (7 instances, ~25 LOC each = 175 LOC)
component_info = WasmComponentInfo(
    wasm_file = ...,
    wit_info = ...,          # 3 different patterns for this!
    component_type = "component",
    imports = ...,
    exports = ...,
    metadata = {"name": ..., "language": ..., "target": ..., "wasi_version": ...},
    profile = ...,
    profile_variants = {},
)

# Pattern 2: wasi_version attribute (4 identical definitions, ~5 LOC each)
"wasi_version": attr.string(default = "p2", values = ["p2", "p3"], ...)

# Pattern 3: WIT validation (2 implementations, ~70 LOC each = 140 LOC)
# Only Rust and Go implement it; Python/C++/JS skip it entirely
```

**Proposed unified rule**:
```starlark
wasm_component(
    name = "my_component",
    language = "rust",        # or "go", "python", "cpp", "js"
    srcs = ["src/lib.rs"],
    wit = ":interfaces",
    wasi_version = "p2",      # or "p3"
    validate_wit = True,      # works for ALL languages now
)
```

Internally: a dispatcher that calls language-specific compilation, then shared WIT handling, validation, and provider creation.

**Impact on STPA**: Reduces UCA surface — fewer code paths means fewer places where checksum verification or validation can be skipped. A single validation workflow means ALL languages get validation, not just Rust and Go.

### Issue #257: Multi-Bundle P2/P3

**Current state**: Partially addressed. We have:
- ✅ `stable-2026-03` and `experimental-p3` bundles
- ✅ Per-target `wasi_version` attribute
- ✅ Same tools serve both P2 and P3
- ❌ No way to use different tool versions for P2 vs P3 targets in same build

**Why this matters less than expected**: Our P3 architecture made `wasi_version` a target property, not a toolchain property. The same wasmtime 43.0.0 handles both P2 and P3. You don't need different tool versions — just different WIT interfaces and build flags.

**What's still needed**:
- When P3 stabilizes, users may want to pin P2 components to older, proven tool versions while using latest for P3
- Bundle validation: ensure selected bundle supports the `wasi_version` requested by targets

**Impact on STPA**: SC-004 (P3 RC tracking) becomes easier with explicit bundle selection.

---

## Recommended Implementation Order

### Phase 1: Shared Utilities (1-2 days, low risk)
Extract duplicated patterns into `common/wasm_component_utils.bzl`:
- `create_component_info()` factory function
- Shared attribute definitions (`WASI_VERSION_ATTR`, `WIT_ATTR`, `VALIDATE_WIT_ATTR`)
- Unified `validate_component()` action
- Entry point discovery helper

**This is pure refactoring** — no user-facing changes, no new features. Each language rule calls the shared functions instead of duplicating.

**Files**:
- Create: `common/wasm_component_utils.bzl`
- Modify: All 7 rule files (replace duplicated code with calls to shared utils)

### Phase 2: Meta-Toolchain Extension (#250, 2-3 days)
Consolidate 8 extensions into 1:
```starlark
wasm.toolchains(bundle = "stable-2026-03", languages = ["rust", "go"])
```

**Files**:
- Create: `wasm/unified_extension.bzl`
- Modify: `wasm/extensions.bzl` (wrap existing extensions)
- Modify: MODULE.bazel example docs

### Phase 3: Unified Rule (#253, 3-5 days)
Single `wasm_component()` that dispatches to language-specific compilation:

```starlark
wasm_component(name = "hello", language = "rust", srcs = [...], wit = ":interfaces")
```

**Files**:
- Create: `wasm/wasm_component.bzl` (unified rule)
- Create: `wasm/private/language_dispatch.bzl` (compilation dispatch)
- Keep: Existing per-language rules as implementation detail
- Add: `wasm/defs.bzl` re-export of `wasm_component`

### Phase 4: Bundle-Aware P3 (#257, 1-2 days)
Add validation that bundle supports target's `wasi_version`:

```starlark
# Fails at analysis time if bundle doesn't support P3:
wasm_component(name = "async_handler", language = "rust", wasi_version = "p3")
# Error: Bundle 'stable-2026-03' does not support P3. Use 'experimental-p3'.
```

---

## Cross-Reference with STPA Artifacts

| STPA Artifact | Relevant Issue | How Unification Helps |
|---------------|---------------|----------------------|
| SC-001 (SHA256 verification) | #250 | One download path = one verification path |
| SC-002 (lazy loading) | #250 | `languages = [...]` makes opt-in explicit |
| SC-003 (preserve pinned versions) | #257 | Bundle system manages versions atomically |
| SC-004 (P3 RC tracking) | #257 | Bundle `wasi_rc` field tracks RC version |
| H-003 (eager load blocks builds) | #250 | No eager loading — download only selected languages |
| CC-001 (fail on missing checksum) | #250 | Single download function = single enforcement point |
| UCA-003 (eager rolling deps) | #250 | Eliminated — no per-language extension to add eagerly |

### New STPA Hazards to Add

| Hazard | Description | Mitigation |
|--------|-------------|------------|
| H-006 | Unified rule accepts invalid language/wasi_version combination | Fail at analysis time with clear error |
| H-007 | Bundle version mismatch: tool too old for requested wasi_version | Validate bundle compatibility in extension |

---

## What NOT to Do

1. **Don't deprecate per-language rules immediately** — keep them as the implementation layer. The unified rule dispatches to them.
2. **Don't merge all toolchain downloads into one mega-download** — keep lazy per-language loading. Users who only need Rust shouldn't download 950MB.
3. **Don't force bundles** — explicit version override must remain possible for advanced users.
4. **Don't break backward compatibility** — old MODULE.bazel with 8 extensions must continue to work. The unified extension is an *alternative*, not a replacement.
