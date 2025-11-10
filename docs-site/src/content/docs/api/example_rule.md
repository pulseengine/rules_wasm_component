---
title: Example Rule
description: Simple Stardoc example demonstrating documentation generation
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Example rule for Stardoc proof-of-concept

<a id="example_component"></a>

## example_component

<pre>
load("@rules_wasm_component//docs:example_rule.bzl", "example_component")

example_component(<a href="#example_component-name">name</a>, <a href="#example_component-srcs">srcs</a>, <a href="#example_component-crate_features">crate_features</a>, <a href="#example_component-profiles">profiles</a>, <a href="#example_component-validate_wit">validate_wit</a>, <a href="#example_component-wit">wit</a>)
</pre>

Builds a Rust WebAssembly component with multi-profile support.

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

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="example_component-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="example_component-srcs"></a>srcs |  Rust source files (.rs)   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="example_component-crate_features"></a>crate_features |  Rust crate features to enable (e.g., ['serde', 'std'])   | List of strings | optional |  `[]`  |
| <a id="example_component-profiles"></a>profiles |  Build profiles to generate.<br><br>Available profiles: - **debug**: opt-level=1, debug=true, strip=false - **release**: opt-level=s (size), debug=false, strip=true - **custom**: opt-level=2, debug=true, strip=false   | List of strings | optional |  `["release"]`  |
| <a id="example_component-validate_wit"></a>validate_wit |  Enable WIT validation against component exports   | Boolean | optional |  `False`  |
| <a id="example_component-wit"></a>wit |  WIT library for interface definitions   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


