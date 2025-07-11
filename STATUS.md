# Rules WASM Component - Current Status

## Summary

This project provides Bazel rules for building WebAssembly Component Model components from Rust code. The implementation now successfully builds wasm32-wasip2 components with proper WIT binding generation.

## Recent Fixes

### 1. WASI SDK Tool Accessibility (Fixed)
- **Issue**: Rust build actions couldn't access WASI SDK tools (ar, clang, etc.) due to Bazel sandbox restrictions
- **Solution**: Collaborated with rules_rust fork maintainer (avrabe) to add `additional_inputs` support to cc_common functions
- **Commits**: 84ddf3a3, df1e8ac6 in avrabe/rules_rust fork

### 2. Absolute Path Inclusions (Fixed)
- **Issue**: WASI SDK headers were being included with absolute paths, breaking sandbox isolation
- **Solution**: Fixed by using empty sources list for WASI allocator_library in rules_rust
- **Commit**: df1e8ac6 in avrabe/rules_rust fork

### 3. WIT Bindings Dependency Resolution (Fixed)
- **Issue**: Generated WIT bindings weren't properly accessible to dependent Rust targets
- **Solution**: Fixed RustInfo provider forwarding in _wasm_rust_library rule using rust_common.crate_info and rust_common.dep_info

### 4. wasm32-wasip2 Support (Fixed)
- **Issue**: Originally only supported wasm32-wasip1
- **Solution**: 
  - Switched default platform to wasm32-wasip2
  - Discovered wasip2 outputs are already components (no conversion needed)
  - Added logic to skip component conversion for wasip2 targets

### 5. Infinite Analysis Loop (Fixed)
- **Issue**: Bazel would get stuck in an infinite analysis loop when building components
- **Solution**: Removed double transition in _wasm_rust_library rule (was applying transition both on the rule and target attribute)

## Current Working State

✅ **Working Features:**
- Building Rust WASM components for wasm32-wasip2
- WIT binding generation with wit-bindgen
- Component validation and testing
- Multiple build profiles (debug, release, custom)
- Integration with rules_rust toolchain

⚠️ **Known Limitations:**
- Clippy integration needs work for transitioned targets
- Building with `//examples/...` may try to build intermediate targets
- Recommend building specific component targets directly

## Build Instructions

```bash
# Build a specific component
bazel build //examples/basic:hello_component

# Run component tests  
bazel test //examples/basic:hello_component_test

# Build all main example components
bazel build //examples/basic:hello_component //examples/multi_profile:camera_sensor //examples/multi_profile:object_detection //examples/simple_module:simple_wasm
```

## Dependencies

- **rules_rust**: Using avrabe fork with WASI SDK support (commit df1e8ac6)
- **WASI SDK**: Version 25 (downloaded automatically)
- **wasm-tools**: Version 1.235.0 (for component manipulation)

## Architecture Notes

1. **Transitions**: Uses Bazel platform transitions to build Rust code for wasm32-wasip2 target
2. **WIT Bindings**: Generated bindings are built as a separate library, then transitioned to WASM
3. **Component Detection**: wasip2 outputs are automatically detected as components (no conversion needed)
4. **Provider Forwarding**: Properly forwards RustInfo providers through transition boundaries

## Future Work

- Fix clippy integration for transitioned targets
- Add support for component composition
- Improve documentation and examples
- Consider upstreaming rules_rust fixes