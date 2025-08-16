---
title: Basic Component Example
description: Build your first WebAssembly component with a simple hello world example
---

Learn the fundamentals of WebAssembly components by building a simple "Hello World" component that exports a greeting function.

## Overview

This example demonstrates:

- ✅ **WIT Interface Definition** - Defining component contracts
- ✅ **Rust Implementation** - Building with `rust_wasm_component`
- ✅ **Testing** - Validating component functionality
- ✅ **Running** - Executing with wasmtime

## Project Structure

```
examples/basic/
├── BUILD.bazel          # Bazel build configuration
├── src/
│   └── lib.rs          # Rust component implementation
└── wit/
    └── hello.wit       # WIT interface definition
```

## Step 1: Define the WIT Interface

Create the WebAssembly Interface Type (WIT) definition:

```wit title="wit/hello.wit"
package hello:world@1.0.0;

world hello {
  export hello: func(name: string) -> string;
}
```

This interface defines:

- **Package**: `hello:world@1.0.0` - A versioned package identifier
- **World**: `hello` - The component's interface boundary
- **Export**: `hello` function that takes a string and returns a string

## Step 2: Configure the Build

Set up Bazel targets in your BUILD file:

```python title="BUILD.bazel"
load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component")

# Define WIT library target
wit_library(
    name = "hello_interfaces",
    srcs = ["wit/hello.wit"],
    package_name = "hello:world@1.0.0",
)

# Build Rust WebAssembly component
rust_wasm_component(
    name = "basic_component",
    srcs = ["src/lib.rs"],
    wit = ":hello_interfaces",
    deps = [
        "@crates//:wit-bindgen",
    ],
)

# Test the component
rust_wasm_component_test(
    name = "basic_test",
    component = ":basic_component",
)
```

## Step 3: Implement the Component

Create the Rust implementation:

```rust title="src/lib.rs"
// Import generated bindings
use basic_component_bindings::exports::hello::world::Guest;

// Component implementation
struct Component;

impl Guest for Component {
    fn hello(name: String) -> String {
        format!("Hello, {}! 👋", name)
    }
}

// Export the component implementation
basic_component_bindings::export!(Component with_types_in basic_component_bindings);
```

Key points:

- **Generated bindings** - `basic_component_bindings` is auto-generated from WIT
- **Guest trait** - Implement this trait to provide the component interface
- **Export macro** - Makes the component available to the WebAssembly runtime

## Step 4: Build the Component

Build your component with Bazel:

```bash
# Build the WebAssembly component
bazel build //examples/basic:basic_component

# Check the output
ls bazel-bin/examples/basic/
# Output: basic_component.wasm
```

The build process:

1. **WIT processing** - Generates interface metadata
2. **Binding generation** - Creates Rust bindings from WIT
3. **Rust compilation** - Compiles to WebAssembly
4. **Component creation** - Packages as a WebAssembly component

## Step 5: Test the Component

Run the included tests:

```bash
# Run component tests
bazel test //examples/basic:basic_test

# Output:
# //examples/basic:basic_test                      PASSED in 0.8s
```

## Step 6: Run the Component

Execute your component with wasmtime:

```bash
# Run with wasmtime (requires wasmtime to be installed)
wasmtime run --wasi preview2 bazel-bin/examples/basic/basic_component.wasm

# You can also inspect the component
wasm-tools component wit bazel-bin/examples/basic/basic_component.wasm
```

<div class="demo-buttons">
  <a href="https://stackblitz.com/github/your-repo/rules_wasm_component/tree/main/examples/basic" class="demo-button">
    🚀 Try in StackBlitz
  </a>
  <a href="https://github.com/your-repo/rules_wasm_component/tree/main/examples/basic" class="demo-button">
    📖 View Source
  </a>
</div>

## Understanding the Generated Code

When you build the component, wit-bindgen creates bindings that bridge your Rust code with the WebAssembly Component Model:

```rust
// Generated in basic_component_bindings (simplified)
pub mod exports {
    pub mod hello {
        pub mod world {
            pub trait Guest {
                fn hello(name: String) -> String;
            }
        }
    }
}

// Export function for the runtime
#[export_name = "hello"]
extern "C" fn hello(/* ... */) -> /* ... */ {
    // Marshalling code that calls your Guest implementation
}
```

## Extending the Example

### Add More Functions

Extend the WIT interface:

```wit title="wit/extended.wit"
package hello:world@1.0.0;

world hello {
  export hello: func(name: string) -> string;
  export goodbye: func(name: string) -> string;
  export get-greeting-count: func() -> u32;
}
```

Update the implementation:

```rust title="src/extended.rs"
use std::sync::atomic::{AtomicU32, Ordering};

static GREETING_COUNT: AtomicU32 = AtomicU32::new(0);

struct Component;

impl Guest for Component {
    fn hello(name: String) -> String {
        GREETING_COUNT.fetch_add(1, Ordering::SeqCst);
        format!("Hello, {}! 👋", name)
    }

    fn goodbye(name: String) -> String {
        format!("Goodbye, {}! 👋", name)
    }

    fn get_greeting_count() -> u32 {
        GREETING_COUNT.load(Ordering::SeqCst)
    }
}
```

### Add Error Handling

Use WIT's result types for operations that can fail:

```wit title="wit/with-errors.wit"
package hello:world@1.0.0;

world hello {
  export hello: func(name: string) -> result<string, string>;
  export divide: func(a: f64, b: f64) -> result<f64, string>;
}
```

```rust title="src/with_errors.rs"
impl Guest for Component {
    fn hello(name: String) -> Result<String, String> {
        if name.is_empty() {
            Err("Name cannot be empty".to_string())
        } else {
            Ok(format!("Hello, {}! 👋", name))
        }
    }

    fn divide(a: f64, b: f64) -> Result<f64, String> {
        if b == 0.0 {
            Err("Division by zero".to_string())
        } else {
            Ok(a / b)
        }
    }
}
```

## Performance Considerations

<div class="perf-indicator">⚡ ~500KB component size</div>
<div class="perf-indicator">🚀 <1ms startup time</div>

This basic component demonstrates:

- **Small binary size** - Minimal WebAssembly footprint
- **Fast execution** - Direct function calls with no overhead
- **Memory efficiency** - Stack-allocated strings for simple operations

## Next Steps

Now that you have a working basic component:

1. **[Explore other languages](/languages/go/)** - Try the same example in Go, C++, or JavaScript
2. **[Learn composition](/composition/wac/)** - Combine multiple components
3. **[Add advanced features](/production/performance/)** - Optimize for production
4. **[See complex examples](/examples/calculator/)** - Build more sophisticated components

## Troubleshooting

**Build fails with "wit-bindgen not found":**

```bash
# Check crate dependencies
bazel query @crates//:wit-bindgen

# Regenerate Cargo.lock if needed
cargo generate-lockfile
```

**Component doesn't export functions:**

```rust
// Ensure you have the export macro
basic_component_bindings::export!(Component with_types_in basic_component_bindings);
```

**wasmtime execution fails:**

```bash
# Use WASI Preview 2
wasmtime run --wasi preview2 component.wasm

# Check component structure
wasm-tools component wit component.wasm
```
