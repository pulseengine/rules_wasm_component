# AI Agent Discovery Index

This is the primary discovery file for AI coding assistants working with rules_wasm_component. It follows Model Context Protocol (MCP) best practices for task decomposition and iterative development.

## MCP-Aligned Discovery Process

### Phase 1: Understanding (Read First)

1. **[ai_agent_guide.md](ai_agent_guide.md)** - MCP-aligned structured guide with critical pitfalls
2. **[rule_schemas.json](rule_schemas.json)** - Machine-readable rule definitions
3. **[TECHNICAL_ISSUES.md](TECHNICAL_ISSUES.md)** - Resolved issues and solutions

### Phase 2: Validation (Use for Checking)

1. **[examples/](../examples/)** - Progressive complexity examples for validation
2. **[test_wit_deps/](../test_wit_deps/)** - Real dependency test cases
3. **wit_deps_check rule** - For dependency validation

### Phase 3: Iteration (Build Incrementally)

1. Start with simple `wit_library`
2. Add `rust_wasm_component_bindgen`
3. Progress to `wac_compose` only after components work
4. Validate each step before proceeding

### Quick Rule Discovery

```json
{
  "available_rules": [
    "wit_library",
    "rust_wasm_component_bindgen",
    "wac_compose",
    "wit_deps_check"
  ],
  "load_statements": {
    "wit_library": "@rules_wasm_component//wit:defs.bzl",
    "rust_wasm_component_bindgen": "@rules_wasm_component//rust:defs.bzl",
    "wac_compose": "@rules_wasm_component//wac:defs.bzl",
    "wit_deps_check": "@rules_wasm_component//wit:wit_deps_check.bzl"
  },
  "providers": ["WitInfo", "WasmComponentInfo"]
}
```

### Rule Dependency Graph

```
wit_library → rust_wasm_component_bindgen → wac_compose
     ↓
wit_deps_check
     ↓
wit_bindgen
```

### Common Patterns by Use Case

#### Creating a WIT Interface Library

```starlark
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "interfaces",
    package_name = "my:pkg@1.0.0",
    srcs = ["interface.wit"],
    deps = ["//external:lib"],  # Optional dependencies
)
```

#### Building a Rust WASM Component

```starlark
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")

rust_wasm_component_bindgen(
    name = "component",
    srcs = ["src/lib.rs"],
    wit = ":interfaces",
    profiles = ["release"],  # Optional: ["debug", "release", "custom"]
)
```

#### Composing Multiple Components

```starlark
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")

wac_compose(
    name = "app",
    components = {":comp_a": "a", ":comp_b": "b"},
    composition = "let a = new a {}; let b = new b {}; export a;",
)
```

#### Checking for Missing Dependencies

```starlark
load("@rules_wasm_component//wit:wit_deps_check.bzl", "wit_deps_check")

wit_deps_check(
    name = "check_deps",
    wit_file = "consumer.wit",
)
```

### Error Resolution Quick Reference (MCP Validation Points)

| Error Pattern                           | Root Cause                     | Solution                               | Validation Step                  |
| --------------------------------------- | ------------------------------ | -------------------------------------- | -------------------------------- |
| `package 'name:pkg@1.0.0' not found`    | Missing wit_library dependency | Add to `deps` attribute                | Check with `wit_deps_check`      |
| `No .wit files found`                   | Incorrect `srcs` attribute     | Point `srcs` to \*.wit files           | Verify files exist in source     |
| `Failed to parse WIT`                   | WIT syntax error               | Fix WIT syntax, check `use` statements | Test with `wit-parser` if needed |
| `missing 'with' mapping for key`        | **Fixed in rules**             | Update rules_wasm_component version    | Build should work automatically  |
| `Module not found` in Rust              | Wrong import path              | Use `{target_name}_bindings` pattern   | Check generated bindings         |
| `missing instantiation argument wasi:*` | WASI component composition     | Use `{ ... }` syntax in composition    | Verify composition compiles      |
| `dangling symbolic link`                | Absolute symlink paths         | **Fixed in rules** with relative paths | Check bazel-bin/ output          |

### Current Status

- ✅ WIT library dependency discovery works
- ✅ Simple components without external dependencies work
- ✅ **Components with external WIT dependencies now work!**
- ✅ Generated Rust module names follow consistent patterns

> **Recent Fix**: External dependency binding generation has been resolved. Components can now successfully use external WIT packages.

### File System Layout Discovery

WIT libraries create this structure:

```
bazel-bin/path/to/target_wit/
├── deps/
│   └── external-lib/     # Package dependencies
│       └── lib.wit
├── deps.toml            # wit-deps compatibility
└── main.wit             # Source files
```

### Provider Access Patterns

```starlark
def _custom_rule_impl(ctx):
    wit_info = ctx.attr.wit[WitInfo]

    # Available fields:
    package_name = wit_info.package_name      # string
    wit_files = wit_info.wit_files           # depset
    wit_deps = wit_info.wit_deps             # depset
    world_name = wit_info.world_name         # string (optional)
    interface_names = wit_info.interface_names # list
```

### Build Command Examples

```bash
# Build a component
bazel build //path/to:component

# Check dependencies
bazel build //path/to:check_deps && cat bazel-bin/.../check_deps_report.txt

# Generate schemas (for development)
bazel build //tools/generate_schemas && bazel-bin/tools/generate_schemas/generate_schemas_/generate_schemas > docs/rule_schemas.json
```

## MCP Discovery Priorities for AI Agents

### Decomposition Strategy

1. **Understand before building** - Read ai_agent_guide.md pitfalls section first
2. **Validate incrementally** - Build wit_library → component → composition
3. **Use schemas for precision** - rule_schemas.json for exact attribute requirements
4. **Check historical issues** - TECHNICAL_ISSUES.md for resolved problems
5. **Follow proven patterns** - examples/ for working implementations

### Iteration Approach

1. **Single component first** - Don't attempt multi-component systems initially
2. **Test before compose** - Ensure components build before WAC composition
3. **Validate dependencies** - Use wit_deps_check for missing packages
4. **Verify outputs** - Check bazel-bin/ for generated artifacts

### Context Management

- **Provider data**: Use WitInfo/WasmComponentInfo for component relationships
- **Error patterns**: Match against documented solutions in ai_agent_guide.md
- **Tool behavior**: Trust rule implementations, don't assume direct tool usage

## File organization for AI understanding

Key directories AI agents should be aware of:

- `/wit/` - Core WIT rule implementations
- `/rust/` - Rust-specific rules
- `/wac/` - Component composition rules
- `/tools/` - Supporting tools (dependency analysis, schema generation)
- `/providers/` - Bazel provider definitions
- `/docs/examples/` - Learning examples
- `/test_wit_deps/` - Integration tests with real dependencies

## Critical Success Patterns for AI Agents

### What Works (Proven Patterns)

✅ **wit_library with explicit deps**: Dependencies resolved automatically
✅ **rust_wasm_component_bindgen with profiles**: Multi-variant builds
✅ **wac_compose with WASI { ... } syntax**: WASI import pass-through
✅ **Incremental validation**: Build each component before composition

### What to Avoid (Historical Pitfalls)

❌ **Shell commands in custom rules**: Breaks hermetic builds
❌ **Manual wit-bindgen invocation**: Rules handle complexity automatically
❌ **Assuming WAC registry resolution**: Local components need special handling
❌ **Complex composition without validation**: Test components individually first

### MCP Implementation Checklist

#### For wit_library

- [ ] Specify `package_name` for external dependencies
- [ ] Use Bazel target labels in `deps`, not file paths
- [ ] Validate with `wit_deps_check` if dependency issues

#### For rust_wasm_component_bindgen

- [ ] Reference wit_library target in `wit` attribute
- [ ] Import using `{target_name}_bindings` in Rust code
- [ ] Test build before proceeding to composition

#### For wac_compose

- [ ] Map components to unversioned package names
- [ ] Use `{ ... }` syntax for WASI components
- [ ] Include package declaration in composition string
- [ ] Validate composition builds successfully

This index provides the MCP-aligned foundation for AI agents to understand and effectively use the rules_wasm_component system without repeating our implementation mistakes.
