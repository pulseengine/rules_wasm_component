# Wizer Pre-Initialization Example

This example demonstrates how to use Wizer for WebAssembly component pre-initialization to achieve dramatically improved startup performance.

## What is Wizer?

Wizer is a WebAssembly pre-initialization tool that:
- Runs your component's initialization code at **build time** instead of runtime
- Snapshots the initialized state into the WebAssembly binary
- Provides **1.35-6x startup performance improvements** depending on initialization complexity

## Example Overview

This example shows a component with expensive initialization:
- **Normal component**: Performs expensive computations on every startup
- **Wizer component**: Pre-computes everything at build time

## Files

- `src/lib.rs` - Rust component with expensive initialization logic
- `wit/expensive-init.wit` - WIT interface definition  
- `BUILD.bazel` - Bazel build configuration showing both normal and Wizer builds

## Building

```bash
# Build normal component (with runtime initialization)
bazel build //examples/wizer_example:expensive_init_component

# Build Wizer pre-initialized component  
bazel build //examples/wizer_example:optimized_component

# Cross-platform build validation (ensures both components build successfully)
bazel build //examples/wizer_example:build_test

# Individual component validation using wasm-tools
bazel build //examples/wizer_example:validate_normal_component
bazel build //examples/wizer_example:validate_wizer_component

# Complete validation suite
bazel build //examples/wizer_example:validation_test
```

## Performance Results

The benchmark typically shows:
- **Normal component**: ~50-100ms startup (includes initialization overhead)
- **Wizer component**: ~15-30ms startup (initialization already done)
- **Improvement**: 2-6x faster startup depending on initialization complexity

## How It Works

### 1. Wizer Initialization Function

Your Rust code exports a special initialization function:

```rust
#[export_name = "wizer.initialize"]  
pub extern "C" fn wizer_initialize() {
    // Expensive initialization work here
    // This runs at BUILD TIME, not runtime
    
    let mut data = HashMap::new();
    for i in 1..1000 {
        data.insert(format!("key_{}", i), expensive_computation(i));
    }
    
    unsafe { EXPENSIVE_DATA = Some(data); }
}
```

### 2. Build Process

```starlark
# Normal component - initialization runs at runtime
rust_wasm_component(
    name = "expensive_init_component",
    srcs = ["src/lib.rs"],  
    wit = "wit/expensive-init.wit",
)

# Wizer component - initialization runs at build time
wizer_chain(
    name = "optimized_component",
    component = ":expensive_init_component", 
    init_function_name = "wizer.initialize",
)
```

### 3. Runtime Behavior

- **Normal component**: Calls `wizer_initialize()` on every instantiation
- **Wizer component**: State is already initialized, skips initialization entirely

## Integration with TinyGo

For Go components, use the integrated rule:

```starlark
go_wasm_component_wizer(
    name = "go_optimized_component",
    srcs = ["main.go"],
    wit = "component.wit",
    world = "my-world", 
    wizer_init_function = "wizer.initialize",
)
```

With corresponding Go code:

```go
//export wizer.initialize
func wizerInitialize() {
    // Expensive Go initialization here
    // Runs at build time
}
```

## When to Use Wizer

✅ **Great for:**
- Components with expensive startup computations
- Large data structure initialization  
- Complex configuration parsing
- Machine learning model loading
- Database connection setup

❌ **Not suitable for:**
- Components that need runtime-specific data
- Initialization that depends on external resources
- Time-sensitive initialization (uses current timestamp)

## Performance Tips

1. **Move expensive work to Wizer**: Any computation that doesn't depend on runtime inputs
2. **Pre-compute lookup tables**: Build hash maps, arrays, etc. at build time
3. **Initialize global state**: Set up static data structures
4. **Avoid I/O in initialization**: Wizer runs in a sandboxed environment

The more expensive your initialization, the greater Wizer's performance benefit! 🚀