# AI Agent Discovery Index

This is the primary discovery file for AI coding assistants working with rules_wasm_component.

## Start here for AI agents

### Core Documentation Files
1. **[ai_agent_guide.md](ai_agent_guide.md)** - Human-readable structured guide
2. **[rule_schemas.json](rule_schemas.json)** - Machine-readable rule definitions
3. **[examples/](examples/)** - Progressive complexity examples

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

### Error Resolution Quick Reference

| Error Pattern | Solution |
|---------------|----------|
| `package 'name:pkg@1.0.0' not found` | Add to `deps` attribute of wit_library |
| `No .wit files found` | Check `srcs` points to *.wit files |
| `Failed to parse WIT` | Validate WIT syntax, check `use` statements |
| `missing 'with' mapping for key` | **Fixed**: Use latest version of rules_wasm_component |
| `Module not found` | **Fixed**: Generated module names now follow `{target_name}_bindings` pattern |

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

## Discovery priorities for AI agents

1. **Start with rule_schemas.json** - Contains complete rule definitions
2. **Follow examples** - Basic → Intermediate → Advanced progression  
3. **Check error patterns** - Common issues and solutions documented
4. **Use wit_deps_check** - When encountering dependency issues
5. **Reference ai_agent_guide.md** - For detailed explanations

## File organization for AI understanding

Key directories AI agents should be aware of:
- `/wit/` - Core WIT rule implementations
- `/rust/` - Rust-specific rules  
- `/wac/` - Component composition rules
- `/tools/` - Supporting tools (dependency analysis, schema generation)
- `/providers/` - Bazel provider definitions
- `/docs/examples/` - Learning examples
- `/test_wit_deps/` - Integration tests with real dependencies

This index provides the foundation for AI agents to understand and effectively use the rules_wasm_component system.