# Claude Development Guidelines

## Project Standards

### RULE #1: THE BAZEL WAY FIRST

**🎯 PRIMARY PRINCIPLE: Always prefer Bazel-native solutions over shell scripts, even for proof of concepts**

Before implementing any solution:

1. **Check for existing Bazel rules** that solve the problem
2. **Use ctx.actions.run()** instead of shell commands
3. **Create custom rules** instead of complex genrules
4. **Use Bazel toolchains** instead of system tools
5. **Apply transitions** instead of manual platform detection

**Examples:**

- ❌ `genrule` with shell script for file processing
- ✅ Custom `rule()` with `ctx.actions.run()`
- ❌ System rust/cargo calls
- ✅ `@rules_rust` with proper transitions
- ❌ Shell-based tool wrappers
- ✅ Hermetic toolchain rules

**Even for prototypes and proof-of-concepts, follow Bazel principles to avoid technical debt.**

### Shell Script Elimination Policy

#### 🚫 Prohibited Patterns

1. **No Shell Script Files**: No `.sh` files in the repository
2. **No Shell Scripts in Disguise**: Avoid complex shell commands in `genrule` cmd attributes
3. **No Embedded Shell Scripts**: Minimize multi-line shell scripts in `.bzl` files
4. **No Platform-Specific Commands**: Avoid Unix-specific commands that won't work on Windows

#### ✅ Approved Patterns

1. **Single Command genrules**: Simple tool invocations (`wasm-tools validate`)
2. **Bazel Native Rules**: Use built-in test rules, toolchain rules
3. **Tool Wrapper Actions**: Direct tool execution via `ctx.actions.run()`
4. **Platform-Agnostic Logic**: Use Bazel's platform detection and toolchain system

#### 🔄 Migration Strategy

**Phase 2 COMPLETE ✅**

- ✅ All 6 shell script files eliminated
- ✅ Complex genrules replaced with Bazel-native approaches
- ✅ Test scripts converted to build_test and test_suite rules

**Phase 4 FINAL SUCCESS 🎆**
**Achieved 76% Reduction: 82 → 31 ctx.execute() calls**

**✅ COMPLETED MODERNIZATIONS:**

1. **wasm_toolchain.bzl** - 40 → 17 calls (-23)
   - ✅ All mv/cp operations → repository_ctx.symlink()
   - ✅ Git clone operations → git_repository rules
   - ✅ Cargo builds → Hybrid git_repository + genrule approach

2. **tool_cache.bzl** - 22 → 6 calls (-16)
   - ✅ Custom cache system → Simplified to use Bazel repository caching
   - ⏳ Tool validation calls remain

3. **tinygo_toolchain.bzl** - 8 → 3 calls (-5)
   - ✅ uname -m → repository_ctx.os.arch
   - ✅ File operations → repository_ctx.symlink()
   - ⏳ Tool installation and validation remain

4. **Simple files ELIMINATED** - 7 → 0 calls (-7)
   - ✅ wasi_sdk_toolchain.bzl: mkdir operations eliminated
   - ✅ cpp_component_toolchain.bzl: test/mkdir → Bazel-native path operations
   - ✅ diagnostics.bzl: which/test → repository_ctx.which() and path.exists

5. **Medium files IMPROVED** - 5 → 3 calls (-2)
   - ✅ wkg_toolchain.bzl: cp → symlink
   - ✅ wizer_toolchain.bzl: REMOVED (wizer now part of wasmtime v39.0.0+)

**REMAINING COMPLEX OPERATIONS (29 calls):**

- **wasm_toolchain.bzl (17)**: Remaining download and build operations (hybrid approach working)
- **tool_cache.bzl (6)**: Tool validation and file existence checks
- **tinygo_toolchain.bzl (3)**: Tool installation and validation
- **Others (3)**: Package management and validation

**Shell Operation Categories MODERNIZED:**

- ✅ **File System**: All cp, mv, mkdir operations → Bazel-native
- ✅ **Platform Detection**: uname → repository_ctx.os properties
- ✅ **Git Operations**: git clone → git_repository rules
- ✅ **Source Management**: git_repository + hybrid cargo builds
- ✅ **Tool Discovery**: which → repository_ctx.which()
- ✅ **Cache System**: Custom shell cache → Bazel repository caching
- ✅ **Path Operations**: test → repository_ctx.path().exists
- ⏳ **Tool Validation**: --version checks (appropriate to keep)
- ⏳ **Complex Builds**: Some cargo builds (complex dependency resolution)

**Phase 4 PROGRESS ⚡**

- **MAJOR SUCCESS**: Modernized 4 component rule files with significant improvements
- **Identified**: 15 remaining `ctx.actions.run_shell()` calls across 7 files

**✅ COMPLETED MODERNIZATIONS:**

1. **wit_deps_check.bzl** - ✅ **COMPLETE MODERNIZATION**
   - Replaced `ctx.actions.run_shell()` with `ctx.actions.run()` for tool execution
   - Eliminated shell command for simple tool invocation with output redirection
   - Now uses `stdout` parameter for clean output capture

2. **rust_wasm_component_bindgen.bzl** - ✅ **SIMPLIFIED**
   - Cleaned up complex shell string interpolation
   - Replaced multi-command echo/cat sequence with cleaner approach
   - Pre-generate content with `ctx.actions.write()`, then simple `cat` command

3. **wit_markdown.bzl** - ✅ **ENHANCED**
   - Improved file copying operations using `find` instead of shell globs
   - Pre-generate index.md content using Bazel's template system
   - Cleaner separation of content generation vs file operations

4. **wasm_validate.bzl** - ✅ **RESTRUCTURED**
   - Broke down monolithic 67-line shell script into focused, single-purpose actions
   - Separated validation, component inspection, and module info extraction
   - Better error handling and progress reporting with distinct mnemonics

**📊 REMAINING COMPLEX CASES (11 calls):**

- **go/defs.bzl (5)**: Complex TinyGo compilation pipeline with Go module resolution
- **wkg/defs.bzl (1)**: WKG package extraction and component discovery
- **wit/wit_bindgen.bzl (2)**: WIT binding generation with language-specific outputs
- **wasm_validate.bzl (4)**: Multi-step validation process (partially modernized)

**🎯 STRATEGY FOR REMAINING CASES:**
These remaining shell scripts are **appropriate complexity** for their tasks:

- **Go module resolution**: Requires system Go binary detection and GOPATH management
- **WKG package handling**: Complex archive extraction and component detection
- **WIT code generation**: Language-specific file discovery and copying
- **WASM validation**: Multi-tool validation workflow

**Phase 4 Assessment**: ✅ **SUCCESSFUL MODERNIZATION**

- Focused on **quick wins** and **quality improvements**
- Eliminated unnecessary shell complexity where possible
- Left appropriate complexity in place for legitimate use cases
- **All builds still working** - no regressions introduced

**Target State**: Bazel-native, cross-platform implementation

- Zero shell script files ✅
- Minimal single-command genrules only ✅
- Platform-agnostic toolchain setup ✅ (major progress)
- Direct tool execution without shell wrappers ✅ (file operations modernized)

## WIZER INTEGRATION STATUS

### ✅ MIGRATION COMPLETE: Wasmtime v39.0.0+ Integration

**As of November 2025**, Wizer has been merged into Wasmtime and is available as the `wasmtime wizer` subcommand.
This eliminates the need for a standalone wizer toolchain and simplifies dependency management.

### Architecture

The wizer pre-initialization workflow now uses wasmtime's built-in wizer subcommand:

1. **wasm_component_wizer Rule** (`//wasm:wasm_component_wizer.bzl`)
   - Uses `wasmtime_toolchain_type` instead of standalone wizer
   - Invokes `wasmtime wizer` subcommand
   - Default init function: `wizer-initialize` (breaking change from `wizer.initialize`)

2. **wasm_component_wizer_library Rule** (`//wasm:wasm_component_wizer_library.bzl`)
   - Library-based pre-initialization support
   - Uses wasmtime toolchain for wizer functionality

3. **Working Example** (`//examples/wizer_example`)
   - Demonstrates pre-initialization with wasmtime wizer
   - Uses `#[export_name = "wizer-initialize"]` (new naming convention)

### Breaking Changes (Issue #246)

- Init function name changed: `wizer.initialize` → `wizer-initialize`
- Standalone wizer toolchain removed (use wasmtime toolchain)
- `//tools/wizer_initializer` removed (no longer needed)
- `checksums/tools/wizer.json` removed

### Migration Guide

**Before (standalone wizer):**
```rust
#[export_name = "wizer.initialize"]
pub extern "C" fn init() { ... }
```

**After (wasmtime wizer):**
```rust
#[export_name = "wizer-initialize"]
pub extern "C" fn init() { ... }
```

#### 📋 Implementation Guidelines

**Instead of Shell Scripts:**

```starlark
# ❌ BAD: Complex shell in genrule
genrule(
    cmd = """
    if [ -f input.txt ]; then
        grep "pattern" input.txt > $@
    else
        echo "No input" > $@
    fi
    """,
)

# ✅ GOOD: Simple tool invocation
genrule(
    cmd = "$(location //tools:processor) $(location input.txt) > $@",
    tools = ["//tools:processor"],
)
```

**Instead of ctx.execute():**

```python
# ❌ BAD: Shell command execution
ctx.execute(["bash", "-c", "git clone ... && cd ... && make"])

# ✅ GOOD: Use Bazel's http_archive or repository rules
http_archive(
    name = "external_tool",
    urls = ["https://github.com/tool/releases/download/v1.0.0/tool.tar.gz"],
    build_file = "@//tools:BUILD.external_tool",
)
```

### Bazel-First Approach

- **Testing**: Use `genrule`, built-in test rules, validation markers
- **Validation**: Direct toolchain binary invocation
- **Cross-platform**: Bazel's platform constraint system
- **Build reproducibility**: No external shell dependencies

### Cross-Platform Compatibility Requirements

- **Windows Support**: All builds must work on Windows without WSL
- **Tool Availability**: Don't assume Unix tools (`git`, `make`, `bash`)
- **Path Handling**: Use Bazel's path utilities
- **Platform Detection**: Use `@platforms//` constraints, not `uname`

## Dependency Management Patterns

### 🎯 RULE #2: STRATIFIED HYBRID APPROACH

**Use the RIGHT download pattern for each dependency category**

This project uses a **stratified hybrid approach** to dependency management, selecting the most appropriate mechanism based on the characteristics of each dependency type.

### Decision Matrix

| Dependency Type | Pattern | Location | Why |
|----------------|---------|----------|-----|
| **Tools carried by a varve realm** | varve module extension | `//:varve*.toml`, `//varve/toolchains` | Signed, counter-protected layer replaces hand-maintained checksums for the tools it carries |
| **Multi-platform GitHub binaries (no varve realm)** | JSON Registry + secure_download | `checksums/tools/*.json` | Solves platform × version matrix, central security auditing |
| **Bazel Central Registry deps** | `bazel_dep` | `MODULE.bazel` | Ecosystem standard, automatic dependency resolution |
| **Source builds** | `git_repository` | `wasm_tools_repositories.bzl` | Bazel standard, maximum flexibility |
| **Universal WASM binaries** | JSON Registry (preferred) or `http_file` | `checksums/tools/*.json` or `MODULE.bazel` | Platform-independent, security auditable |
| **NPM packages** | Hermetic npm + package.json | `toolchains/jco_toolchain.bzl` | Ecosystem standard, package lock files |

### Pattern 0: varve (PulseEngine Toolchain Layer Manager)

**Use for**: Tools carried by a varve realm — currently loom/meld/spar/synth/witness
(pulseengine realm, `//:varve.toml` + `//:rolling.pub`) and wasm-tools/wac/wkg/
wit-bindgen-wrpc (pulseengine-wasm realm, `//:varve-wasm.toml` + `//:wasm-rolling.pub`).
See `//varve/toolchains:BUILD.bazel` for the toolchain wiring.

**Why**: One signed, counter-protected, dated layer replaces a whole set of
hand-maintained `checksums/tools/*.json` entries + per-tool download logic.
varve's signature chain (DSSE against the realm's trust root) does the
verification; Bazel just resolves and caches through it hermetically.

**Caveat**: a realm's trust root is a claim about who *signs*, not who *built*
the payload — read `varve-realms.toml`'s per-realm comment before assuming
upstream provenance. In the pulseengine-wasm realm specifically, only
wasm-tools carries build-provenance; wac/wkg/wit-bindgen-wrpc are PulseEngine-
key-signed hashes of unverified upstream downloads.

**Not (yet) in a varve realm, still on Pattern 1 below**: wit-bindgen (plain),
wasmtime, wasi-sdk, binaryen, wrpc (non-wrpc-bindgen), wsc (deliberately
excluded — signing path, needs its own review), rivet (no toolchain to
replace). Check `varve-realms.toml` before adding a new JSON registry entry —
if the tool already has a realm home, prefer that.

### Pattern 1: JSON Registry (Multi-Platform GitHub Binaries)

**Use for**: Tools with different binaries per platform not (yet) carried by a
varve realm (wit-bindgen, wasmtime, wizer, wasi-sdk, nodejs, tinygo)

**Why**: Elegantly handles the combinatorial explosion of (platforms × versions × URL patterns)

**Structure**:
```json
{
  "tool_name": "wasm-tools",
  "github_repo": "bytecodealliance/wasm-tools",
  "latest_version": "1.240.0",
  "supported_platforms": ["darwin_amd64", "darwin_arm64", "linux_amd64", "linux_arm64", "windows_amd64"],
  "versions": {
    "1.240.0": {
      "release_date": "2025-10-08",
      "platforms": {
        "darwin_arm64": {
          "sha256": "8959eb9f494af13868af9e13e74e4fa0fa6c9306b492a9ce80f0e576eb10c0c6",
          "url_suffix": "aarch64-macos.tar.gz"
        }
        // ... other platforms
      }
    }
  }
}
```

**Usage**:
```python
# In toolchain .bzl file
from toolchains.secure_download import secure_download_tool

secure_download_tool(ctx, "wasm-tools", "1.240.0", platform)
```

**Benefits**:
- ✅ Single source of truth for all versions and checksums
- ✅ Central security auditing (`checksums/` directory)
- ✅ Supports multiple versions side-by-side
- ✅ Platform detection and URL construction automatic
- ✅ Clean API via `registry.bzl`

### Pattern 2: Bazel Central Registry (`bazel_dep`)

**Use for**: Standard Bazel ecosystem dependencies (rules_rust, bazel_skylib, platforms, rules_cc, etc.)

**Why**: Bazel's standard mechanism with automatic dependency resolution

**Structure**:
```starlark
# MODULE.bazel
bazel_dep(name = "rules_rust", version = "0.65.0")
bazel_dep(name = "bazel_skylib", version = "1.8.1")
bazel_dep(name = "platforms", version = "1.0.0")
```

**Benefits**:
- ✅ Ecosystem standard - no learning curve
- ✅ Automatic transitive dependency resolution
- ✅ Maintained by Bazel team
- ✅ Built-in security and version compatibility

**Do NOT**:
- ❌ Duplicate BCR deps in JSON registry
- ❌ Use http_archive for tools available in BCR

### Pattern 3: Git Repository (Source Builds)

**Use for**: Custom forks, bleeding edge versions, or when source builds are required

**Why**: Bazel-native source repository management

**Structure**:
```starlark
# wasm_tools_repositories.bzl
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "wasm_tools_src",
    remote = "https://github.com/bytecodealliance/wasm-tools.git",
    tag = "v1.235.0",
    build_file = "//toolchains:BUILD.wasm_tools",
)
```

**When to use**:
- Custom fork with patches
- Need bleeding edge from main branch
- Binary not available for your platform
- Building from source is required for licensing

**Prefer download over build**: When prebuilt binaries are available and work correctly, use Pattern 1 (JSON Registry) instead for faster, more hermetic builds.

### Pattern 4: Universal WASM Binaries

**Use for**: WebAssembly components (platform-independent .wasm files)

**Preferred**: JSON Registry for consistency and security auditing
```json
// checksums/tools/file-ops-component.json
{
  "tool_name": "file-ops-component",
  "github_repo": "pulseengine/bazel-file-ops-component",
  "latest_version": "0.1.0-rc.3",
  "supported_platforms": ["wasm"],  // Universal
  "versions": {
    "0.1.0-rc.3": {
      "release_date": "2025-10-15",
      "platforms": {
        "wasm": {
          "sha256": "8a9b1aa8a2c9d3dc36f1724ccbf24a48c473808d9017b059c84afddc55743f1e",
          "url": "https://github.com/.../file_ops_component.wasm"
        }
      }
    }
  }
}
```

**Alternative**: `http_file` for very simple cases (legacy)
```starlark
# MODULE.bazel (only for simple cases)
http_file(
    name = "component_external",
    url = "https://github.com/.../component.wasm",
    sha256 = "abc123...",
    downloaded_file_path = "component.wasm",
)
```

**Recommendation**: Migrate all WASM components to JSON Registry for:
- Consistent security auditing
- Version management
- Same tooling as other downloads

### Pattern 5: NPM Packages

**Use for**: Node.js ecosystem tools (jco, componentize-js)

**Why**: npm is the standard package manager with lock file support

**Structure**:
```python
# Download hermetic Node.js first (Pattern 1)
secure_download_tool(ctx, "nodejs", "20.18.0", platform)

# Use hermetic npm for package installation
ctx.execute([npm_path, "install", "@bytecodealliance/jco@1.4.0"])
```

**Benefits**:
- ✅ Hermetic builds (no system Node.js dependency)
- ✅ Package lock files for reproducibility
- ✅ Ecosystem standard

### Adding New Dependencies

**Decision Tree**:

1. **Is it in Bazel Central Registry?**
   - YES → Use `bazel_dep` (Pattern 2)
   - NO → Continue to step 2

2. **Is it a GitHub release with platform-specific binaries?**
   - YES → Create JSON in `checksums/tools/` (Pattern 1)
   - NO → Continue to step 3

3. **Is it a universal WASM component?**
   - YES → Create JSON in `checksums/tools/` with platform "wasm" (Pattern 4)
   - NO → Continue to step 4

4. **Is it an NPM package?**
   - YES → Use hermetic npm installation (Pattern 5)
   - NO → Continue to step 5

5. **Must it be built from source?**
   - YES → Use `git_repository` (Pattern 3)
   - NO → Reconsider if this dependency is needed

### Security Best Practices

1. **Always verify checksums**: All downloads MUST have SHA256 verification
2. **Central audit trail**: Prefer JSON registry for auditability
3. **Version pinning**: Always specify exact versions, never use "latest"
4. **Minimal versions**: Keep only latest stable + previous stable in JSON files
5. **Review changes**: All checksum changes require careful PR review

### Maintenance Guidelines

**Adding a new version to JSON registry**:
```bash
# 1. Download binaries for all platforms
# 2. Calculate SHA256 checksums
shasum -a 256 wasm-tools-1.241.0-*.tar.gz

# 3. Add version block to JSON file
# 4. Update "latest_version" if appropriate
# 5. Remove old versions if keeping only latest + previous
```

**Updating a BCR dependency**:
```starlark
# Simply change version in MODULE.bazel
bazel_dep(name = "rules_rust", version = "0.66.0")  # Updated
```

**Removing old versions**:
- Keep latest stable version
- Keep previous stable version (for rollback capability)
- Remove all older versions
- Update tests if they pin to old versions

### Anti-Patterns to Avoid

❌ **DO NOT** create custom download mechanisms
❌ **DO NOT** hardcode URLs in .bzl files
❌ **DO NOT** duplicate BCR dependencies in JSON registry
❌ **DO NOT** use http_archive for multi-platform binaries (use JSON registry)
❌ **DO NOT** keep more than 2 versions per tool without strong justification
❌ **DO NOT** use "strategy options" - pick ONE best approach per tool

## Current State

### Toolchains Implemented

- ✅ TinyGo v0.39.0 with WASI Preview 2 support
- ✅ Rust WebAssembly components
- ✅ C++ components with WASI SDK
- ✅ JavaScript/TypeScript components with ComponentizeJS (jco)
- ✅ Wizer pre-initialization support
- ❌ Javy is NOT supported (see decision below)

### JavaScript Tooling Decision: jco vs Javy

**Decision**: Use **jco/ComponentizeJS** exclusively. Do NOT add Javy support.

**Rationale**:
- jco provides full WebAssembly Component Model support; Javy does not
- jco uses WASI 0.2 (current standard); Javy uses WASI 0.1 (legacy)
- jco enables interoperability with other components (Rust, Go, C++); Javy cannot
- jco supports TypeScript, NPM ecosystem, modern JS features
- Size trade-off (~8MB vs 1-16KB) is acceptable for Component Model benefits

**Javy is unsuitable** because rules_wasm_component is fundamentally about WebAssembly Components, and Javy only produces WASI modules without Component Model support.

### Performance Optimizations

- ✅ Wizer pre-initialization (1.35-6x startup improvement)
- ✅ Platform constraint validation
- ✅ Cross-platform toolchain resolution
- ✅ Build caching and parallelization

### Documentation Status

- ✅ All READMEs updated with current implementation
- ✅ Multi-language support documented
- ✅ Production-ready examples provided

## Bazel Version Compatibility

### Supported Versions

| Bazel Version | Status | Notes |
|--------------|--------|-------|
| 7.x | ✅ Supported | Tested in CI |
| 8.x | ✅ Supported (Primary) | Current development target, tested in CI |
| 9.x | ✅ Supported | Tested in CI, benefits from performance improvements |

### Bazel 9 Specific Features

The following Bazel 9 features are available but not required (graceful fallback for 7/8):

1. **Memory Efficiency** (automatic)
   - 20% retained heap reduction
   - 30% faster remote cache builds
   - 80% faster tree artifact sandbox extraction

2. **`module_ctx.facts`** (future enhancement)
   - Can be used to cache checksum lookups in extension
   - Would reduce network calls after first resolution

3. **Native `set` Data Type** (future enhancement)
   - Could simplify duplicate detection in file processing
   - Requires version checking for fallback

### Version Detection Pattern

For Bazel 9+ specific features with fallback:
```starlark
# Check Bazel version for feature availability
def _is_bazel_9_or_later():
    """Check if running on Bazel 9 or later."""
    version = native.bazel_version
    if not version:
        return False
    parts = version.split(".")
    return int(parts[0]) >= 9

# Usage with fallback
def deduplicate_files(files):
    if _is_bazel_9_or_later():
        # Use native set() in Bazel 9+
        return list(set(files))
    else:
        # Fallback for Bazel 7/8
        seen = {}
        result = []
        for f in files:
            if f not in seen:
                seen[f] = True
                result.append(f)
        return result
```

### CI Matrix

The CI workflow tests across:
- Ubuntu (Linux x86_64) - Bazel 8.x
- macOS (ARM64) - Bazel 8.x
- Windows (x86_64) - Bazel 8.x (experimental)
- BCR Docker environment - Latest Bazel
