"""Example rule for Stardoc proof-of-concept"""

def _example_component_impl(ctx):
    """Implementation of example_component."""
    pass

example_component = rule(
    implementation = _example_component_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".rs"],
            mandatory = True,
            doc = "Rust source files (.rs)",
        ),
        "wit": attr.label(
            providers = ["WitInfo"],
            doc = "WIT library for interface definitions",
        ),
        "profiles": attr.string_list(
            default = ["release"],
            doc = """Build profiles to generate.

Available profiles:
- **debug**: opt-level=1, debug=true, strip=false
- **release**: opt-level=s (size), debug=false, strip=true
- **custom**: opt-level=2, debug=true, strip=false
""",
        ),
        "validate_wit": attr.bool(
            default = False,
            doc = "Enable WIT validation against component exports",
        ),
        "crate_features": attr.string_list(
            doc = "Rust crate features to enable (e.g., ['serde', 'std'])",
        ),
    },
    doc = """Builds a Rust WebAssembly component with multi-profile support.

This rule compiles Rust source files into a WebAssembly component that implements
the WIT interface definition. Supports building multiple optimization profiles
in a single build invocation for efficient development workflows.

**Example:**

```starlark
example_component(
    name = "my_service",
    srcs = ["src/lib.rs"],
    wit = ":service_wit",
    profiles = ["debug", "release"],
    crate_features = ["serde"],
)
```

**Outputs:**
- `<name>.wasm`: Component file (default or first profile)
- `<name>_<profile>.wasm`: Profile-specific components
- `<name>_all_profiles`: Filegroup with all variants

**See Also:**
- [Multi-Profile Builds](multi_profile.md)
- [WIT Interface Guide](wit_guide.md)
""",
)
