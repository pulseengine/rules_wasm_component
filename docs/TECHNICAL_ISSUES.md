# Technical Issues Explanation

This document explains the technical issues that have been resolved in the WebAssembly Component Model rules.

> **Status Update**: The major blocking issues have been fixed as of the latest version.

## Issue 1: External dependency binding generation ✅ FIXED

### What works now
- WIT libraries can define dependencies using `deps = ["//path/to:other_wit_library"]`
- wit-bindgen correctly discovers the external packages in the directory structure
- WIT packages are properly resolved with the `use external:lib/interface@1.0.0` syntax
- **External dependency binding generation now works automatically**

### Previous issue (now resolved)
Previously, when a Rust component tried to use external WIT dependencies, wit-bindgen would fail with:

```
Error: missing either `--generate-all` or `--with external:lib/utilities@1.0.0=(...|generate)`
Caused by: missing `with` mapping for the key `external:lib/utilities@1.0.0`
```

### How it was fixed
The fix was implemented in `wit/wit_bindgen.bzl` by automatically adding the `--generate-all` flag when external dependencies are detected:

```starlark
# Check if we have external dependencies and add --generate-all if needed
bindgen_args = cmd_args[:-len(wit_file_args)]
if wit_info.wit_deps and len(wit_info.wit_deps.to_list()) > 0:
    # Add --generate-all to handle external dependencies automatically
    bindgen_args.append("--generate-all")
```

This tells wit-bindgen to automatically generate bindings for all discovered external packages without requiring explicit `--with` mappings.

## Issue 2: Generated module name mismatches ✅ FIXED

### What works now
- Generated modules consistently follow the `{target_name}_bindings` pattern
- Import paths follow predictable patterns based on WIT package structure
- Module naming works correctly for both simple and complex components

### Previous issue (now resolved)
Previously there were inconsistencies where wit-bindgen would generate files based on world names, but Rust code expected module names based on target names.

### How it was resolved
The existing implementation in `rust/rust_wasm_component_bindgen.bzl` already handled this correctly:

```starlark
# Line 208: Creates bindings with consistent naming
crate_name = name.replace("-", "_") + "_bindings"
```

The issue was actually in the import paths in user code. The correct pattern is:

```rust
// For target name "consumer_component" accessing interface "app" in package "consumer:app"
use consumer_component_bindings::exports::consumer::app::app::Guest;
consumer_component_bindings::export!(Component with_types_in consumer_component_bindings);
```

The generated binding modules follow the pattern `{target_name}_bindings`, and import paths follow the WIT package structure.

## Current Status: All Major Issues Resolved ✅

### What works now
1. **Simple components**: Components without external WIT dependencies work perfectly
2. **Complex components**: Components with external WIT dependencies now work fully
3. **WIT library dependencies**: The dependency discovery and directory structure works
4. **Generated module names**: Follow consistent, predictable patterns
5. **WAC composition**: Works for composing components

### Recent Achievements
- ✅ External dependency binding generation fixed with `--generate-all` approach
- ✅ Module naming consistency verified and documented
- ✅ All test examples now build successfully
- ✅ Documentation updated to reflect working state

## Production Readiness

The system is now production-ready for:
- **Single-package WIT libraries**
- **Multi-package WIT dependencies** 
- **Complex component compositions**
- **Mixed simple and complex component builds**

## Implementation Notes

The fixes were implemented in the Bazel rule logic:
- wit-bindgen tool works correctly when called with proper arguments ✅
- The WIT dependency discovery system we built works correctly ✅
- The directory structure we create is correct ✅
- The Bazel rule logic now calls these tools correctly ✅

All major blocking issues have been resolved, making the rules suitable for production use with complex WIT dependency scenarios.

## AI Agent Troubleshooting Decision Tree

### Build Failure Analysis

```
Build Failed?
├─ wit_library target?
│  ├─ "package not found" error?
│  │  └─ ✅ Add missing dependency to `deps` attribute
│  ├─ "No .wit files found" error?
│  │  └─ ✅ Check `srcs` points to .wit files
│  └─ "Failed to parse WIT" error?
│     └─ ✅ Fix WIT syntax, validate `use` statements
├─ rust_wasm_component_bindgen target?
│  ├─ "Module not found" in Rust?
│  │  └─ ✅ Use `{target_name}_bindings` import pattern
│  ├─ "missing with mapping" error?
│  │  └─ ✅ Update rules_wasm_component (auto-fixed)
│  └─ External dependency issues?
│     └─ ✅ Ensure wit_library has `package_name` set
└─ wac_compose target?
   ├─ "missing instantiation argument wasi:*"?
   │  └─ ✅ Use `{ ... }` syntax for WASI components
   ├─ "failed to create registry client"?
   │  └─ ✅ Fixed in rules - update version
   └─ "dangling symbolic link"?
      └─ ✅ Fixed in rules - relative paths used
```

### Validation Workflow for AI Agents

1. **Before building anything**: Read ai_agent_guide.md pitfalls
2. **For each wit_library**: Run `wit_deps_check` if using external deps
3. **For each component**: Build individually before composition
4. **For wac_compose**: Verify components build first, then compose
5. **On any error**: Match against decision tree above

### Success Indicators

- ✅ `bazel-bin/{target}_wit/` directory exists (wit_library)
- ✅ `bazel-bin/{target}_{profile}.wasm` file exists (rust component)
- ✅ `bazel-bin/{target}.wasm` file exists (wac_compose)
- ✅ No "missing" or "not found" errors during build
- ✅ Generated Rust bindings import successfully