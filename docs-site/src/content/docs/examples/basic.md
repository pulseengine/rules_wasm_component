---
title: Basic Component Example
description: Build your first WebAssembly component with a simple hello world example
---

## Your First WebAssembly Component

**This example shows how easy it is** to turn regular Rust code into a portable WebAssembly component. You'll build a simple greeting service that can be called from any language and deployed anywhere.

**What makes this powerful:**

- **Universal compatibility** - Once built, your component runs on any platform that supports WebAssembly
- **Language agnostic** - Other components written in Go, C++, or JavaScript can call your Rust functions
- **Secure by default** - Your component runs in complete isolation with explicit interfaces
- **Production ready** - This same pattern scales to complex microservices

## What You'll Learn

This walkthrough covers the complete component development lifecycle:

- **Interface-first design** - Define your API before writing implementation code
- **Automatic code generation** - Let the toolchain create the boilerplate
- **Component testing** - Validate your component works correctly
- **Runtime execution** - See your component in action

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

**Start by defining your component's API contract.** This is like writing a function signature before implementing the function - it forces you to think about what your component does and how other components will interact with it.

**Why WIT matters:** WIT (WebAssembly Interface Types) is the universal language for describing component interfaces. Any language can generate bindings from WIT, making your Rust component callable from Go, JavaScript, C++, or any other supported language.

```wit title="wit/hello.wit"
package hello:world@1.0.0;

world hello {
  export hello: func(name: string) -> string;
}
```

**Breaking down this interface:**

- **Package**: `hello:world@1.0.0` - A unique, versioned identifier (like npm package names)
- **World**: `hello` - Defines the component's complete interface boundary
- **Export**: `hello` function - What this component provides to the outside world

Think of this as defining a microservice API, but one that works across any language and platform.

## Step 2: Configure the Build

**Tell Bazel how to transform your code into a component.** This configuration is like a recipe - it describes all the ingredients (source files, dependencies) and steps (compilation, binding generation, packaging) needed to create your component:

```python title="BUILD.bazel"
load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")

# Define WIT library target
wit_library(
    name = "hello_interfaces",
    srcs = ["wit/hello.wit"],
    package_name = "hello:world@1.0.0",
)

# Build Rust WebAssembly component
rust_wasm_component_bindgen(
    name = "basic_component",
    srcs = ["src/lib.rs"],
    wit = ":hello_interfaces",
)

# Test the component
rust_wasm_component_test(
    name = "basic_test",
    component = ":basic_component",
)
```

**What each target does:**

- **`wit_library`** - Processes your WIT file and validates the interface
- **`rust_wasm_component_bindgen`** - Compiles your Rust code into a WebAssembly component
- **`rust_wasm_component_test`** - Creates tests for your component

The build system handles all the complexity: downloading toolchains, generating bindings, compiling to WebAssembly, and packaging as a component.

## Step 3: Implement the Component

**Now write the actual business logic.** This is regular Rust code - no WebAssembly knowledge required. The generated bindings handle all the marshaling between WebAssembly and Rust types:

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

**Key insights:**

- **Generated bindings** - `basic_component_bindings` is automatically created from your WIT file
- **Guest trait** - This trait defines the functions your component must implement
- **Export macro** - This line makes your implementation available to the WebAssembly runtime

The beauty of this approach: you write normal Rust code, and the toolchain handles all the WebAssembly complexity.

## Step 4: Build the Component

**One command builds everything.** Bazel coordinates downloading tools, generating code, compiling, and packaging:

```bash
# Build the WebAssembly component
bazel build //examples/basic:basic_component

# Check the output
ls bazel-bin/examples/basic/
# Output: basic_component.wasm
```

**What happened during the build:**

1. **WIT processing** - Validated your interface and generated metadata
2. **Binding generation** - Created Rust code that bridges your implementation to WebAssembly
3. **Rust compilation** - Compiled your code to a WebAssembly core module
4. **Component wrapping** - Packaged the module with component metadata

The result: a single `.wasm` file that contains your entire component and can run anywhere.

## Step 5: Test the Component

**Verify your component works correctly.** Testing components is just like testing any other code, but with the added confidence that the tests exercise the same interfaces other components will use:

```bash
# Run component tests
bazel test //examples/basic:basic_test

# Output:
# //examples/basic:basic_test                      PASSED in 0.8s
```

## Step 6: Run the Component

**See your component in action!** WebAssembly components run in any WebAssembly runtime. We'll use wasmtime, which is the reference implementation:

```bash
# Run with wasmtime (requires wasmtime to be installed)
wasmtime run --wasi preview2 bazel-bin/examples/basic/basic_component.wasm

# You can also inspect the component
wasm-tools component wit bazel-bin/examples/basic/basic_component.wasm
```

<div class="demo-buttons">
  <a href="https://stackblitz.com/github/pulseengine/rules_wasm_component/tree/main/examples/basic" class="demo-button">
    Try in StackBlitz
  </a>
  <a href="https://github.com/pulseengine/rules_wasm_component/tree/main/examples/basic" class="demo-button">
    View Source
  </a>
</div>

## Understanding the Generated Code

**Behind the scenes, the build process generates a lot of boilerplate code** so you don't have to write it. Here's what wit-bindgen creates to bridge your Rust code with the WebAssembly Component Model:

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

## Performance Characteristics

**This simple component delivers impressive performance:**

<div class="perf-indicator">~500KB component size</div>
<div class="perf-indicator">&lt;1ms startup time</div>

What makes components so efficient:

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
