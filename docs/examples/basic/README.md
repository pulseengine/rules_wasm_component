# Basic Examples

Simple examples that demonstrate the fundamental usage patterns of rules_wasm_component.

## Example 1: Single WIT Library

**Purpose**: Define a basic WIT interface library

```starlark
# BUILD.bazel
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(
    name = "hello_interfaces",
    package_name = "example:hello@1.0.0",
    srcs = ["hello.wit"],
    interfaces = ["greeting"],
)
```

```wit
// hello.wit
package example:hello@1.0.0;

interface greeting {
    say-hello: func(name: string) -> string;
}

world hello-world {
    export greeting;
}
```

## Example 2: Simple Rust Component

**Purpose**: Build a WASM component from Rust source with WIT bindings

```starlark
# BUILD.bazel
load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")

wit_library(
    name = "hello_interfaces",
    package_name = "example:hello@1.0.0", 
    srcs = ["hello.wit"],
)

rust_wasm_component_bindgen(
    name = "hello_component",
    srcs = ["src/lib.rs"],
    wit = ":hello_interfaces",
)
```

```rust
// src/lib.rs
// Import the generated WIT bindings
use hello_component_bindings::exports::example::hello::greeting::Guest;

// Component implementation
struct Component;

impl Guest for Component {
    fn say_hello(name: String) -> String {
        format!("Hello, {}!", name)
    }
}

// Export the component implementation
hello_component_bindings::export!(Component with_types_in hello_component_bindings);
```

> **Note**: This pattern works for all components, including those with external WIT dependencies.

## Example 3: Dependency Analysis

**Purpose**: Check for missing WIT dependencies

```starlark
# BUILD.bazel
load("@rules_wasm_component//wit:wit_deps_check.bzl", "wit_deps_check")

wit_deps_check(
    name = "check_missing_deps",
    wit_file = "consumer.wit",
)
```

Run with: `bazel build :check_missing_deps && cat bazel-bin/check_missing_deps_report.txt`