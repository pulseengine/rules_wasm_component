---
title: Rust Components
description: Build WebAssembly components with Rust using rules_rust integration
---

## Why Rust for WebAssembly Components?

Rust is the **ideal language** for WebAssembly components. Its zero-cost abstractions, memory safety, and lack of runtime overhead make it perfect for creating fast, secure, portable components.

**The Rust advantage:**

- **Memory safety without garbage collection** - Perfect for sandboxed environments
- **Zero-cost abstractions** - High-level code compiles to efficient WebAssembly
- **Excellent tooling** - wit-bindgen automatically generates all the glue code
- **Small binaries** - Dead code elimination keeps components lightweight
- **Mature ecosystem** - Leverage existing Rust crates in your components

**How it works:** You write normal Rust code, define interfaces in WIT (WebAssembly Interface Types), and the toolchain handles all the WebAssembly compilation magic. The result is a portable component that can be called from any language.

## Features

- **Full Component Model Support** - WASI Preview 2 and Component Model
- **wit-bindgen Integration** - Automatic binding generation from WIT interfaces
- **Multiple Build Profiles** - Debug, release, and custom configurations
- **rules_rust Integration** - Leverages existing Bazel Rust ecosystem
- **Incremental Builds** - Fast iteration with Bazel caching

## Choosing the Right Rule

rules_wasm_component provides **three Rust rules** for different use cases:

### `rust_wasm_component_bindgen` (Recommended)

**Use for most component development** - exports custom interfaces for other components to use.

```python
rust_wasm_component_bindgen(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit = ":my_interfaces",  # WIT interfaces automatically generate bindings
    profiles = ["release"],  # Simple configuration
)
```

**Perfect for:**
- Components with custom WIT interfaces
- Inter-component communication
- Reusable component libraries
- Standard component development workflows

### `rust_wasm_binary` (CLI Applications)

**Use for CLI tools and applications** - builds proper WASI CLI binaries that export `wasi:cli/command`.

```python
rust_wasm_binary(
    name = "my_cli_tool",
    srcs = ["src/main.rs"],  # Must have main() function
    deps = ["@crates//:clap"],
    edition = "2021",
)
```

**Perfect for:**
- Command-line applications with `main()` function
- CLI tools executable via `wasmtime run`
- Standalone applications that need CLI argument parsing
- Hermetic tool replacements (like ssh-keygen, file processors, etc.)

### `rust_wasm_component` (Advanced)

**Use for library components** - WASI-only components without custom interfaces.

```python
rust_wasm_component(
    name = "my_lib_component",
    srcs = ["src/lib.rs"],  # Library with exports, no main()
    deps = ["@crates//:serde"],
    rustc_flags = ["-C", "opt-level=3"],  # Custom compiler flags
)
```

**Perfect for:**
- Library components without custom WIT interfaces
- WASI-only components (filesystem, stdio, etc.)
- Custom build requirements and optimization
- Converting existing WASM modules

### Rule Selection Guide

| Use Case | Rule | Entry Point | Exports Interfaces | Executable |
|----------|------|-------------|-------------------|------------|
| **Component Library** | `rust_wasm_component_bindgen` | `lib.rs` | ✅ Yes | ❌ No |
| **CLI Application** | `rust_wasm_binary` | `main.rs` | ❌ No | ✅ Yes |
| **Microservice** | `rust_wasm_component_bindgen` | `lib.rs` | ✅ Yes | ❌ No |
| **File Processor Tool** | `rust_wasm_binary` | `main.rs` | ❌ No | ✅ Yes |
| **API Server** | `rust_wasm_component_bindgen` | `lib.rs` | ✅ Yes | ❌ No |
| **Data Converter Library** | `rust_wasm_component` | `lib.rs` | ❌ No | ❌ No |

**Quick decisions**: 
- **Has `main()` function?** → Use `rust_wasm_binary`
- **Other components call your functions?** → Use `rust_wasm_component_bindgen`
- **Library without custom interfaces?** → Use `rust_wasm_component`

## Basic Component

Let's build a calculator component to demonstrate the core concepts. This example shows how to:

- Define a clear interface with WIT
- Implement business logic in pure Rust
- Handle errors properly with WebAssembly-safe types
- Build and test the component

### WIT Interface Definition

```wit title="wit/calculator.wit"
package calculator:math@1.0.0;

interface calculator {
    add: func(a: f64, b: f64) -> f64;
    subtract: func(a: f64, b: f64) -> f64;
    multiply: func(a: f64, b: f64) -> f64;
    divide: func(a: f64, b: f64) -> result<f64, string>;
}

world calculator {
    export calculator;
}
```

### Build Configuration

```python title="BUILD.bazel"
load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")

wit_library(
    name = "calculator_interfaces",
    srcs = ["wit/calculator.wit"],
    package_name = "calculator:math@1.0.0",
)

rust_wasm_component_bindgen(
    name = "calculator_component",
    srcs = ["src/lib.rs"],
    wit = ":calculator_interfaces",
    # Multiple build profiles
    profiles = ["debug", "release"],
)
```

### Rust Implementation

```rust title="src/lib.rs"
use calculator_component_bindings::exports::calculator::math::calculator::Guest;

struct Calculator;

impl Guest for Calculator {
    fn add(a: f64, b: f64) -> f64 {
        a + b
    }

    fn subtract(a: f64, b: f64) -> f64 {
        a - b
    }

    fn multiply(a: f64, b: f64) -> f64 {
        a * b
    }

    fn divide(a: f64, b: f64) -> Result<f64, String> {
        if b == 0.0 {
            Err("Division by zero".to_string())
        } else {
            Ok(a / b)
        }
    }
}

calculator_component_bindings::export!(Calculator with_types_in calculator_component_bindings);
```

### Dependencies

```toml title="Cargo.toml"
[package]
name = "calculator-component"
version = "0.1.0"
edition = "2021"

[dependencies]
wit-bindgen = { version = "0.30.0", default-features = false, features = ["realloc"] }
anyhow = "1.0"

[lib]
crate-type = ["cdylib"]
```

## Advanced Patterns

### Error Handling with Results

```rust title="src/advanced.rs"
use calculator_component_bindings::exports::calculator::math::calculator::Guest;

struct AdvancedCalculator;

impl Guest for AdvancedCalculator {
    fn power(base: f64, exponent: f64) -> Result<f64, String> {
        if base == 0.0 && exponent < 0.0 {
            return Err("Cannot raise zero to negative power".to_string());
        }

        let result = base.powf(exponent);

        if result.is_infinite() {
            Err("Result overflow".to_string())
        } else if result.is_nan() {
            Err("Invalid operation".to_string())
        } else {
            Ok(result)
        }
    }

    fn sqrt(value: f64) -> Result<f64, String> {
        if value < 0.0 {
            Err("Cannot calculate square root of negative number".to_string())
        } else {
            Ok(value.sqrt())
        }
    }
}
```

### Complex Data Types

```wit title="wit/data-types.wit"
package data:types@1.0.0;

interface operations {
    record point {
        x: f64,
        y: f64,
    }

    variant calculation-result {
        success(f64),
        error(string),
    }

    enum operation-type {
        add,
        subtract,
        multiply,
        divide,
    }

    calculate-batch: func(operations: list<operation-type>, values: list<point>) -> list<calculation-result>;
}
```

```rust title="src/complex.rs"
use data_types_component_bindings::exports::data::types::operations::{
    Guest, Point, CalculationResult, OperationType
};

struct DataProcessor;

impl Guest for DataProcessor {
    fn calculate_batch(
        operations: Vec<OperationType>,
        values: Vec<Point>
    ) -> Vec<CalculationResult> {
        operations.iter().zip(values.iter())
            .map(|(op, point)| {
                match op {
                    OperationType::Add => CalculationResult::Success(point.x + point.y),
                    OperationType::Subtract => CalculationResult::Success(point.x - point.y),
                    OperationType::Multiply => CalculationResult::Success(point.x * point.y),
                    OperationType::Divide => {
                        if point.y == 0.0 {
                            CalculationResult::Error("Division by zero".to_string())
                        } else {
                            CalculationResult::Success(point.x / point.y)
                        }
                    }
                }
            })
            .collect()
    }
}
```

## Build Profiles

### Debug Profile (Default)

```bash
# Build with debug symbols and assertions
bazel build //:calculator_component_debug
```

### Release Profile

```bash
# Build optimized for production
bazel build //:calculator_component_release
```

### Custom Profile

```python title="BUILD.bazel"
rust_wasm_component_bindgen(
    name = "calculator_optimized",
    srcs = ["src/lib.rs"],
    wit = ":calculator_interfaces",
    profiles = ["release"],  # Use release profile for optimization
)
```

## Testing

### Component Tests

```python title="BUILD.bazel"
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_test")

rust_wasm_component_test(
    name = "calculator_test",
    component = ":calculator_component",
    test_data = ["test_cases.json"],
)
```

### Integration Tests

```rust title="tests/integration_test.rs"
use wasmtime::{Engine, Store, Component, Linker};
use wasmtime_wasi::{WasiCtx, WasiView};

#[tokio::test]
async fn test_calculator_component() -> wasmtime::Result<()> {
    let engine = Engine::default();
    let component = Component::from_file(&engine, "calculator_component.wasm")?;

    let mut store = Store::new(&engine, WasiCtx::new());
    let mut linker = Linker::new(&engine);

    // Add WASI bindings
    wasmtime_wasi::add_to_linker_async(&mut linker)?;

    let instance = linker.instantiate_async(&mut store, &component).await?;

    // Test the calculator functions
    let add_func = instance.get_typed_func::<(f64, f64), f64>(&mut store, "add")?;
    let result = add_func.call_async(&mut store, (5.0, 3.0)).await?;

    assert_eq!(result, 8.0);
    Ok(())
}
```

## Performance Optimization

### Wizer Pre-initialization

```python title="BUILD.bazel"
load("@rules_wasm_component//wasm:defs.bzl", "wasm_component_wizer")

wasm_component_wizer(
    name = "calculator_optimized",
    component = ":calculator_component",
    init_func = "initialize_calculator",
)
```

```rust title="src/optimized.rs"
static mut CACHE: Option<HashMap<String, f64>> = None;

#[export_name = "initialize_calculator"]
pub extern "C" fn initialize_calculator() {
    unsafe {
        CACHE = Some(HashMap::new());
        // Pre-compute common values
        let cache = CACHE.as_mut().unwrap();
        cache.insert("pi".to_string(), std::f64::consts::PI);
        cache.insert("e".to_string(), std::f64::consts::E);
    }
}
```

### Memory Optimization

```rust title="src/memory.rs"
// Use smaller allocator for WebAssembly
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

// Minimize memory allocations
impl Guest for OptimizedCalculator {
    fn batch_calculate(operations: &[f64]) -> Vec<f64> {
        // Pre-allocate result vector
        let mut results = Vec::with_capacity(operations.len());

        for &value in operations {
            results.push(value * 2.0);
        }

        results
    }
}
```

## Troubleshooting

### Common Issues

**Module naming conflicts:**

```rust
// ❌ Wrong - conflicts with generated bindings
mod calculator;

// ✅ Correct - use different name
mod calculator_impl;
```

**Missing export macro:**

```rust
// ❌ Wrong - component won't export functions
impl Guest for Calculator { /* ... */ }

// ✅ Correct - exports component interface
calculator_component_bindings::export!(Calculator with_types_in calculator_component_bindings);
```

**Build profile not found:**

```bash
# Check available profiles
bazel query 'kind(rust_wasm_component_bindgen, //...)'
```

<div class="demo-buttons">
  <a href="https://stackblitz.com/github/pulseengine/rules_wasm_component/tree/main/examples/basic" class="demo-button">
    Try Rust Example
  </a>
  <a href="/examples/basic/" class="demo-button">
    Full Example
  </a>
</div>

## Performance Characteristics

**Production-ready performance** out of the box:

<div class="perf-indicator">1.35-6x faster startup with Wizer</div>
<div class="perf-indicator">~2MB typical component size</div>
<div class="perf-indicator">Low memory footprint with wee_alloc</div>

Rust components offer excellent performance characteristics:

- **Minimal runtime overhead** - No garbage collection
- **Small binary size** - Efficient dead code elimination
- **Memory safety** - Zero-cost abstractions
- **WASI Preview 2** - Modern system interface support
