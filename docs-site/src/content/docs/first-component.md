---
title: Your First Component
description: Step-by-step guide to creating your first WebAssembly component
---

Build your first WebAssembly component from scratch in under 10 minutes.

## What You'll Learn

- Set up a basic project structure
- Define WIT interfaces
- Implement a component in Rust
- Build and test with Bazel
- Run your component

## Prerequisites

Make sure you have:

- **Bazelisk installed** - [See installation guide](/installation/)
- **Git** - For repository management

Bazelisk will automatically download the correct Bazel version for you.

## Step 1: Project Setup

Create a new directory for your component:

```bash
mkdir my-first-component
cd my-first-component
```

Initialize the project structure:

```bash
# Create directories
mkdir -p src wit

# Create basic files
touch BUILD.bazel MODULE.bazel Cargo.toml src/lib.rs wit/greeting.wit
```

## Step 2: Configure Your Project

Set up your project dependencies. For detailed installation instructions and advanced configuration options, see the [Installation Guide](/installation/).

**Quick setup for Rust components:**

```python title="MODULE.bazel"
module(name = "my_first_component", version = "0.1.0")

bazel_dep(name = "rules_wasm_component", version = "1.0.0")
bazel_dep(name = "rules_rust", version = "0.48.0")

crate = use_extension("@rules_rust//crate_universe:extension.bzl", "crate")
crate.from_cargo(name = "crates", cargo_lockfile = "//:Cargo.lock", manifests = ["//:Cargo.toml"])
use_repo(crate, "crates")
```

```toml title="Cargo.toml"
[package]
name = "my-first-component"
version = "0.1.0"
edition = "2021"

[dependencies]
wit-bindgen = { version = "0.30.0", default-features = false, features = ["realloc"] }

[lib]
crate-type = ["cdylib"]
```

```bash
cargo generate-lockfile
```

## Step 3: Define the WIT Interface

Create your component interface in `wit/greeting.wit`:

```wit title="wit/greeting.wit"
package greeting:api@1.0.0;

/// A simple greeting interface
interface greeter {
    /// Generate a personalized greeting
    greet: func(name: string) -> string;

    /// Get a random greeting
    random-greeting: func() -> string;

    /// Count how many greetings have been made
    greeting-count: func() -> u32;
}

world greeting-component {
    export greeter;
}
```

## Step 4: Configure the Build

Set up your `BUILD.bazel`:

```python title="BUILD.bazel"
load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen", "rust_wasm_component_test")

# WIT interface library
wit_library(
    name = "greeting_interfaces",
    srcs = ["wit/greeting.wit"],
    package_name = "greeting:api@1.0.0",
)

# Rust WebAssembly component
rust_wasm_component_bindgen(
    name = "greeting_component",
    srcs = ["src/lib.rs"],
    wit = ":greeting_interfaces",
)

# Component test
rust_wasm_component_test(
    name = "greeting_test",
    component = ":greeting_component",
)
```

> **📋 Rule Reference:** For complete details on all rule attributes and options, see [`wit_library`](/reference/rules/#wit_library), [`rust_wasm_component_bindgen`](/reference/rules/#rust_wasm_component_bindgen), and [`rust_wasm_component_test`](/reference/rules/#rust_wasm_component_test).

## Step 5: Implement the Component

Create your Rust implementation in `src/lib.rs`:

```rust title="src/lib.rs"
use std::sync::atomic::{AtomicU32, Ordering};

// Import the generated bindings
use greeting_component_bindings::exports::greeting::api::greeter::Guest;

// Global counter for tracking greetings
static GREETING_COUNTER: AtomicU32 = AtomicU32::new(0);

// Predefined greetings for random selection
const GREETINGS: &[&str] = &[
    "Hello",
    "Hi there",
    "Greetings",
    "Hey",
    "Good day",
    "Howdy",
    "Salutations",
];

// Component implementation
struct GreetingComponent;

impl Guest for GreetingComponent {
    fn greet(name: String) -> String {
        // Increment the counter
        let count = GREETING_COUNTER.fetch_add(1, Ordering::SeqCst) + 1;

        // Generate personalized greeting
        format!("Hello, {}! This is greeting #{}", name, count)
    }

    fn random_greeting() -> String {
        // Increment the counter
        let count = GREETING_COUNTER.fetch_add(1, Ordering::SeqCst) + 1;

        // Simple pseudo-random selection based on counter
        let greeting = GREETINGS[count as usize % GREETINGS.len()];

        format!("{}, friend!", greeting)
    }

    fn greeting_count() -> u32 {
        GREETING_COUNTER.load(Ordering::SeqCst)
    }
}

// Export the component
greeting_component_bindings::export!(GreetingComponent with_types_in greeting_component_bindings);
```

## Step 6: Build Your Component

Now build your component with Bazel:

```bash
# Build the component
bazel build //:greeting_component

# Check the output
ls bazel-bin/
# You should see: greeting_component.wasm
```

If the build succeeds, you'll see output like:

```
INFO: Build completed successfully, 15 total actions
```

## Step 7: Test Your Component

Run the automated tests:

```bash
# Run component tests
bazel test //:greeting_test

# Expected output:
# //:greeting_test                                 PASSED in 1.2s
```

## Step 8: Inspect Your Component

Examine the generated WebAssembly component:

```bash
# View component interface
wasm-tools component wit bazel-bin/greeting_component.wasm

# Validate the component
wasm-tools validate bazel-bin/greeting_component.wasm --features component-model

# Check component size
ls -lh bazel-bin/greeting_component.wasm
```

## Step 9: Run Your Component

If you have wasmtime installed, you can run your component:

```bash
# Execute with wasmtime
wasmtime run --wasi preview2 bazel-bin/greeting_component.wasm
```

<div class="demo-buttons">
  <a href="https://stackblitz.com/github/pulseengine/rules_wasm_component/tree/main/examples/basic" class="demo-button">
    Try this tutorial in StackBlitz
  </a>
  <a href="https://github.com/codespaces/new?repo=pulseengine/rules_wasm_component" class="demo-button">
    Open in GitHub Codespace
  </a>
</div>

## Understanding What Happened

### 1. WIT Interface Definition

The WIT file defined three functions that your component exports:

- `greet(name: string) -> string` - Personalized greeting
- `random-greeting() -> string` - Random greeting selection
- `greeting-count() -> u32` - Counter tracking

### 2. Code Generation

wit-bindgen automatically generated Rust bindings that:

- Define the `Guest` trait you implemented
- Handle WebAssembly memory management
- Marshal data between WebAssembly and the host

### 3. Component Building

Bazel orchestrated the build process:

- Processed WIT interfaces
- Generated Rust bindings
- Compiled Rust to WebAssembly
- Created a WebAssembly component

### 4. Component Model Features

Your component demonstrates:

- **Interface Types** - Rich type system beyond basic WebAssembly
- **Capability Security** - Isolated execution environment
- **Language Interoperability** - Can be called from any language

## Next Steps

Congratulations! You've built your first WebAssembly component. Now you can:

### Explore Different Languages

- **[Go Components](/languages/go/)** - Build the same functionality with TinyGo
- **[C++ Components](/languages/cpp/)** - Try native C++ development
- **[JavaScript Components](/languages/javascript/)** - Use ComponentizeJS

### Add Advanced Features

- **[Component Composition](/composition/wac/)** - Combine multiple components
- **[Error Handling](/examples/calculator/)** - Use WIT result types
- **[Performance Optimization](/production/performance/)** - Optimize with Wizer

### Build Real Applications

- **[HTTP Service](/examples/http-service/)** - Create web services
- **[Multi-Language System](/examples/multi-language/)** - Polyglot applications
- **[OCI Publishing](/production/publishing/)** - Distribute components

## Troubleshooting

**Bazel can't find rules_wasm_component:**

```bash
# Check MODULE.bazel syntax
bazel mod deps

# Verify rules are available
bazel query '@rules_wasm_component//...' >/dev/null
```

**Rust compilation errors:**

```bash
# Check Cargo.lock is present
ls Cargo.lock

# Regenerate if needed
cargo generate-lockfile
```

**Component doesn't export functions:**

```rust
// Make sure you have the export macro at the end of lib.rs
greeting_component_bindings::export!(GreetingComponent with_types_in greeting_component_bindings);
```

**wasmtime execution issues:**

```bash
# Ensure you're using WASI Preview 2
wasmtime run --wasi preview2 component.wasm

# Check if wasmtime supports components
wasmtime --version
```

You now have a fully functional WebAssembly component that demonstrates the core concepts of the Component Model!
