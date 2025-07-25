# Intermediate Examples

Examples showing cross-package dependencies and multi-component systems.

## Example 1: WIT Library Dependencies

**Purpose**: Define WIT libraries that depend on each other

> **✅ Status**: External dependency binding generation has been fixed! Components can now successfully use external WIT packages.

```starlark
# external/BUILD.bazel  
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "lib_interfaces",
    package_name = "external:lib@1.0.0",
    srcs = ["lib.wit"],
    interfaces = ["utilities"],
    visibility = ["//visibility:public"],
)
```

```wit
// external/lib.wit
package external:lib@1.0.0;

interface utilities {
    format-message: func(msg: string) -> string;
    get-timestamp: func() -> u64;
}
```

```starlark
# consumer/BUILD.bazel
load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")

wit_library(
    name = "consumer_interfaces",
    package_name = "consumer:app@1.0.0",
    srcs = ["consumer.wit"],
    deps = ["//external:lib_interfaces"],
)

rust_wasm_component_bindgen(
    name = "consumer_component",
    srcs = ["src/lib.rs"],
    wit = ":consumer_interfaces",
)
```

```wit
// consumer/consumer.wit
package consumer:app@1.0.0;

use external:lib/utilities@1.0.0;

interface app {
    run: func() -> string;
}

world consumer-world {
    import utilities;
    export app;
}
```

## Example 2: Multi-Profile Builds

**Purpose**: Build components with different optimization levels

```starlark
# BUILD.bazel
rust_wasm_component_bindgen(
    name = "optimized_component",
    srcs = ["src/lib.rs"],
    wit = ":interfaces",
    profiles = ["debug", "release"],
)
```

Outputs:
- `bazel-bin/optimized_component_debug.wasm` - Debug build
- `bazel-bin/optimized_component_release.wasm` - Release build

## Example 3: Component with External Crates

**Purpose**: Use external Rust dependencies in components

```starlark
# BUILD.bazel
load("@crates//:defs.bzl", "crate")

rust_wasm_component_bindgen(
    name = "complex_component",
    srcs = ["src/lib.rs"],
    wit = ":interfaces",
    deps = [
        crate("serde"),
        crate("anyhow"),
        # Note: wit-bindgen is automatically provided
    ],
)
```