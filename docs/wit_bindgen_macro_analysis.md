# WIT-Bindgen Macro Support Analysis

## Executive Summary

This document analyzes the effort required to support wit-bindgen's `generate!()` procedural macro directly in Rust source code, as an alternative to the current separate crate approach used by `rust_wasm_component_bindgen`.

## Current vs Proposed Approach

### Current Approach (Separate Crates)

- Uses `wit_bindgen` CLI to generate `.rs` files
- Creates separate `rust_library` targets for bindings
- Developer imports bindings as external crate: `use my_component_bindings::*;`
- Clear separation between generated and user code

### Proposed Approach (Procedural Macros)

- Uses `wit_bindgen::generate!()` macro directly in source code
- WIT files provided via `compile_data` and environment variables
- Developer writes: `wit_bindgen::generate!({ world: "my-world", path: "../wit" });`
- Generated code appears inline in the same compilation unit

## Technical Analysis

### Phase 1: Research Findings

#### wit-bindgen Macro Capabilities

- **Basic usage**: `generate!()`, `generate!("world")`, `generate!(in "path")`
- **Full configuration**: `generate!({ world: "...", path: "...", inline: "...", ... })`
- **Supports both imports and exports**: Generates traits for exports, direct functions for imports
- **Runtime flexibility**: Can target different runtime environments

#### Bazel Integration Challenges

- **Issue #79**: "Including a genfile at compile time is not possible"
- **Issue #459**: "Can't use `include_str!()` macro with Bazel-generated data files"
- **Core problem**: Procedural macros need file access at compile time, but Bazel's sandboxing complicates this

### Phase 2: Bazel Procedural Macro Integration Patterns

#### Solution: `compile_data` + `rustc_env`

```bazel
rust_library(
    name = "my_component",
    srcs = ["src/lib.rs"],
    compile_data = [":wit_files"],
    rustc_env = {
        "CARGO_MANIFEST_DIR": "$(execpath :wit_files)",
        "WIT_ROOT_DIR": "$(execpath :wit_files)",
    },
    deps = ["@crate_index//:wit-bindgen"],
)
```

#### How It Works

1. **`compile_data`**: Makes WIT files available during compilation
2. **`rustc_env`**: Provides environment variables for macro to locate files
3. **`$(execpath)`**: Bazel substitution provides correct paths to generated files
4. **Macro resolution**: `wit_bindgen::generate!()` uses `CARGO_MANIFEST_DIR` to find WIT files

## Implementation Design

### Phase 3: API Design

#### New Rule: `rust_wasm_component_macro`

```bazel
rust_wasm_component_macro(
    name = "my_component",
    srcs = ["src/lib.rs"],  # Contains wit_bindgen::generate!() calls
    wit = ":my_interfaces",
    generation_mode = "guest",  # or "native-guest"
    symmetric = False,  # Future: support cpetig's fork
)
```

#### Generated Targets

- `{name}_host`: Host-platform `rust_library` for native applications
- `{name}`: Final WASM component
- Automatic dependency management and environment variable setup

#### Source Code Usage

```rust
use wit_bindgen::generate;

generate!({
    world: "my-world",
    path: "../wit",  // Resolved via CARGO_MANIFEST_DIR
});

// Use generated bindings directly...
impl Guest for Component {
    // Implementation using generated traits
}
```

## Comparison Matrix

| Aspect                   | Current (Separate Crates) | Proposed (Macros)          |
| ------------------------ | ------------------------- | -------------------------- |
| **Developer Experience** | Import external crate     | Inline generation          |
| **File Organization**    | Clear separation          | Everything in one file     |
| **Build Complexity**     | Medium (separate targets) | High (env var setup)       |
| **IDE Support**          | Good (separate files)     | Variable (macro expansion) |
| **Debugging**            | Easy (real files)         | Harder (generated code)    |
| **Compile Times**        | Incremental builds        | Macro re-expansion         |
| **Bazel Integration**    | Native                    | Workarounds needed         |
| **Flexibility**          | Limited by CLI            | Full macro features        |

## Implementation Phases

### Phase 4: Proof of Concept (2-3 weeks)

- [x] ✅ Basic `rust_wasm_component_macro` rule
- [x] ✅ Environment variable setup for CARGO_MANIFEST_DIR
- [x] ✅ Simple example demonstrating macro usage
- [ ] Testing with actual wit-bindgen macro
- [ ] Validation of file path resolution

### Phase 5: Core Implementation (3-4 weeks)

- [ ] Robust path handling for different WIT structures
- [ ] Support for WIT dependencies and imports
- [ ] Error handling and debugging improvements
- [ ] Integration with existing toolchain system
- [ ] Comprehensive test suite

### Phase 6: Advanced Features (2-3 weeks)

- [ ] Symmetric mode support (requires cpetig's fork integration)
- [ ] Multiple world support
- [ ] Custom wit-bindgen crate versions
- [ ] Performance optimizations

### Phase 7: Production Readiness (1-2 weeks)

- [ ] Documentation and examples
- [ ] Migration guide from separate crate approach
- [ ] Performance benchmarking
- [ ] CI/CD integration

## Risk Assessment

### High Risk

- **Bazel sandboxing**: Procedural macros may not access files correctly
- **Path resolution**: Environment variable approach may fail in complex scenarios
- **IDE support**: Generated code may not be visible to language servers

### Medium Risk

- **Compile performance**: Macros may slow down incremental builds
- **Debugging complexity**: Generated code harder to inspect and debug
- **Maintenance burden**: More complex than current approach

### Low Risk

- **Feature parity**: wit-bindgen macro supports all needed features
- **Ecosystem compatibility**: Standard Rust procedural macro patterns

## Recommendation

### Hybrid Approach (Recommended)

1. **Keep current approach as default**: Stable, well-tested, good developer experience
2. **Add macro support as opt-in**: For developers who prefer inline generation
3. **Provide migration tools**: Easy switching between approaches
4. **Gradual adoption**: Allow teams to experiment with macro approach

### Implementation Priority

1. **Phase 4**: Quick proof of concept to validate technical feasibility
2. **Decision point**: Evaluate POC results before committing to full implementation
3. **Phase 5-7**: Only proceed if POC demonstrates clear value

## Effort Estimation

- **Total effort**: 8-12 weeks
- **Risk-adjusted**: 10-16 weeks (considering Bazel integration challenges)
- **Team size**: 1-2 developers
- **Prerequisites**: Strong knowledge of Bazel, Rust procedural macros, wit-bindgen internals

## Success Criteria

1. **Functional**: wit-bindgen macros work with Bazel-provided WIT files
2. **Performance**: Compile times comparable to current approach
3. **Developer experience**: Intuitive API, good error messages
4. **Maintainability**: Clean implementation, comprehensive tests
5. **Documentation**: Clear examples and migration guides

## Next Steps

1. **Validate POC**: Test the implemented `rust_wasm_component_macro` with real wit-bindgen
2. **Performance testing**: Compare build times vs separate crate approach
3. **Stakeholder feedback**: Get input from potential users
4. **Go/no-go decision**: Decide whether to proceed to full implementation

---

_This analysis provides a comprehensive foundation for the wit-bindgen macro support GitHub issue and implementation planning._
