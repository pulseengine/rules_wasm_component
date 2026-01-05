---
title: C++ Components
description: Build WebAssembly components with C++ using WASI SDK integration
---

# C++ Components

<div class="complexity-badge intermediate">
  <span class="badge-icon">⚡</span>
  <div class="badge-content">
    <strong>INTERMEDIATE</strong>
    <p>Assumes basic C++ knowledge and some Bazel familiarity</p>
  </div>
</div>

## Why C++ for WebAssembly Components?

C++ brings **maximum performance** and **existing ecosystem** to WebAssembly components. Its predictable memory model, zero-cost abstractions, and decades of optimization make it ideal for performance-critical components.

**The C++ advantage:**

- **Predictable performance** - No garbage collection, no runtime overhead
- **Existing codebase** - Port millions of lines of battle-tested code
- **Low-level control** - Direct memory management for specialized use cases
- **Header-only libraries** - Many C++ libraries work out of the box
- **C compatibility** - Use C libraries directly

**How it works:** You write C++ code with familiar idioms, define interfaces in WIT (WebAssembly Interface Types), and WASI SDK compiles everything to WebAssembly. The `wit-bindgen` tool generates the C/C++ bindings that connect your code to the component model.

## Features

- **WASI SDK Integration** - Uses Clang/LLVM for WASM targeting
- **C++17/C++20 Support** - Modern C++ standards
- **WIT Binding Generation** - Automatic C/C++ bindings from WIT interfaces
- **No Standard Library** - Option for minimal, stdlib-free components
- **Bazel CC Rules Integration** - Works with existing C++ infrastructure
- **Exception Configuration** - Control exception handling (WASI SDK limitation)

## Toolchain Setup

C++ components require the WASI SDK toolchain. Use the lazy loading extensions for minimal download size:

```python title="MODULE.bazel"
bazel_dep(name = "rules_wasm_component", version = "1.0.0")
bazel_dep(name = "rules_cc", version = "0.2.14")

# Lazy loading: Only download WASI SDK when needed (+300MB)
cpp_wasm = use_extension(
    "@rules_wasm_component//wasm:language_extensions.bzl",
    "cpp_wasm",
)
cpp_wasm.configure(wasi_sdk_version = "29")
use_repo(cpp_wasm, "wasi_sdk", "cpp_toolchain")
register_toolchains(
    "@wasi_sdk//:wasi_sdk_toolchain",
    "@wasi_sdk//:cc_toolchain",
    "@cpp_toolchain//:cpp_component_toolchain",
)
```

## Choosing the Right Rule

rules_wasm_component provides **three C++ rules** for different use cases:

### `cpp_component` (Recommended)

**Use for most component development** - creates complete WebAssembly components from C++ source.

```python
cpp_component(
    name = "calculator",
    srcs = ["calculator.cpp"],
    hdrs = ["calculator.h"],
    wit = "calculator.wit",
    world = "calculator",
    cxx_std = "c++17",
)
```

**Perfect for:**
- New component development
- Self-contained libraries
- Performance-critical services
- Porting existing C++ code

### `cc_component_library`

**Use for reusable C++ libraries** - compiled for WASM but not yet a component.

```python
cc_component_library(
    name = "math_utils",
    srcs = ["math_utils.cpp"],
    hdrs = ["math_utils.h"],
    cxx_std = "c++20",
)
```

**Perfect for:**
- Internal utilities
- Shared code between components
- Header-only library wrappers

### `cpp_wit_bindgen`

**Use for manual binding control** - generates C/C++ bindings from WIT.

```python
cpp_wit_bindgen(
    name = "calculator_bindings",
    wit = "calculator.wit",
    world = "calculator",
    string_encoding = "utf8",
)
```

**Perfect for:**
- Custom build pipelines
- Complex multi-world scenarios
- Debugging binding issues

## Basic Component

Let's build a calculator component to demonstrate the core concepts.

### WIT Interface Definition

```wit title="calculator.wit"
package example:simple-calculator@1.0.0;

interface calc {
    add: func(a: f64, b: f64) -> f64;
    subtract: func(a: f64, b: f64) -> f64;
    multiply: func(a: f64, b: f64) -> f64;
    divide: func(a: f64, b: f64) -> f64;
}

world calculator {
    export calc;
}
```

### Build Configuration

```python title="BUILD.bazel"
load("@rules_wasm_component//cpp:defs.bzl", "cpp_component")

cpp_component(
    name = "calculator",
    srcs = ["calculator.cpp"],
    hdrs = ["calculator.h"],
    wit = "calculator.wit",
    world = "calculator",
    cxx_std = "c++17",
    enable_exceptions = False,  # WASI SDK limitation
    enable_rtti = False,        # Smaller binary size
    optimize = True,
)
```

### C++ Implementation

```cpp title="calculator.cpp"
#include "calculator_cpp.h"  // Generated WIT bindings

// Implementation in the generated namespace structure
namespace exports {
namespace example {
namespace simple_calculator {
namespace calc {

double Add(double a, double b) {
    return a + b;
}

double Subtract(double a, double b) {
    return a - b;
}

double Multiply(double a, double b) {
    return a * b;
}

double Divide(double a, double b) {
    if (b == 0.0) {
        return 0.0;  // Simple error handling
    }
    return a / b;
}

}}}} // namespace exports::example::simple_calculator::calc
```

### Build and Test

```bash
# Build the component
bazel build //:calculator

# Validate the component
wasm-tools component wit bazel-bin/calculator.wasm

# Run with wasmtime
wasmtime run bazel-bin/calculator.wasm
```

## Advanced Patterns

### Using External Libraries

Many header-only C++ libraries work with WASI SDK:

```python title="BUILD.bazel"
load("@rules_wasm_component//cpp:defs.bzl", "cpp_component")

cpp_component(
    name = "data_processor",
    srcs = ["processor.cpp"],
    wit = "processor.wit",
    world = "processor",
    deps = [
        "@nlohmann_json//:json",  # Header-only JSON library
        "@fmt//:fmt",             # Format library
    ],
)
```

```cpp title="processor.cpp"
#include <nlohmann/json.hpp>
#include <fmt/core.h>
#include "processor_cpp.h"

namespace exports {
namespace data {
namespace processor {

std::string Process(const std::string& input) {
    auto json = nlohmann::json::parse(input);
    return fmt::format("Processed: {}", json.dump());
}

}}} // namespace
```

### Multi-Component Systems

Build complex systems from multiple components:

```python title="BUILD.bazel"
load("@rules_wasm_component//cpp:defs.bzl", "cc_component_library", "cpp_component")

# Shared utilities
cc_component_library(
    name = "common_utils",
    srcs = ["common.cpp"],
    hdrs = ["common.h"],
)

# Main service component
cpp_component(
    name = "api_service",
    srcs = ["api_service.cpp"],
    wit = "api.wit",
    world = "api-service",
    deps = [":common_utils"],
)

# Worker component
cpp_component(
    name = "worker",
    srcs = ["worker.cpp"],
    wit = "worker.wit",
    world = "worker",
    deps = [":common_utils"],
)
```

### Error Handling Without Exceptions

Since WASI SDK doesn't support C++ exceptions, use result types:

```wit title="safe_math.wit"
package math:safe@1.0.0;

interface operations {
    record calc-result {
        success: bool,
        value: f64,
        error-message: option<string>,
    }

    safe-divide: func(a: f64, b: f64) -> calc-result;
    safe-sqrt: func(x: f64) -> calc-result;
}

world safe-math {
    export operations;
}
```

```cpp title="safe_math.cpp"
#include "safe_math_cpp.h"
#include <cmath>

namespace exports {
namespace math {
namespace safe {
namespace operations {

CalcResult SafeDivide(double a, double b) {
    if (b == 0.0) {
        return {false, 0.0, "Division by zero"};
    }
    return {true, a / b, {}};
}

CalcResult SafeSqrt(double x) {
    if (x < 0.0) {
        return {false, 0.0, "Cannot sqrt negative number"};
    }
    return {true, std::sqrt(x), {}};
}

}}}} // namespace
```

### No-stdlib Components

For minimal components without the standard library:

```python title="BUILD.bazel"
cpp_component(
    name = "minimal_component",
    srcs = ["minimal.cpp"],
    wit = "minimal.wit",
    world = "minimal",
    enable_exceptions = False,
    enable_rtti = False,
    copts = [
        "-fno-builtin",
        "-nostdlib",
    ],
)
```

```cpp title="minimal.cpp"
#include "minimal_cpp.h"

// No stdlib - pure computation
namespace exports {
namespace minimal {

int32_t ComputeFibonacci(int32_t n) {
    if (n <= 1) return n;

    int32_t prev = 0, curr = 1;
    for (int32_t i = 2; i <= n; ++i) {
        int32_t next = prev + curr;
        prev = curr;
        curr = next;
    }
    return curr;
}

}} // namespace
```

## Configuration Options

### C++ Standard Selection

```python
cpp_component(
    # C++17 (best compatibility)
    cxx_std = "c++17",

    # C++20 (concepts, ranges)
    # cxx_std = "c++20",
)
```

### Language Mode

```python
cpp_component(
    # C++ bindings (namespaced API)
    language = "cpp",

    # C bindings (flat functions)
    # language = "c",
)
```

### Optimization

```python
cpp_component(
    # Enable optimizations
    optimize = True,

    # Disable for debugging
    # optimize = False,
)
```

### Exception Handling

```python
cpp_component(
    # Disabled (WASI SDK requirement)
    enable_exceptions = False,

    # Enabled (may not work with all WASI SDK versions)
    # enable_exceptions = True,
)
```

## Testing

### Component Validation

```python title="BUILD.bazel"
load("@rules_wasm_component//wasm:defs.bzl", "wasm_validate")

# Validate component structure
wasm_validate(
    name = "calculator_validated",
    component = ":calculator",
)
```

### Runtime Testing with Wasmtime

```python title="BUILD.bazel"
load("@rules_wasm_component//wasm:defs.bzl", "wasm_test")

# Test component execution
wasm_test(
    name = "calculator_test",
    component = ":calculator",
    args = ["--test"],  # Passed to component
)
```

### Integration Testing

Test your C++ component from a host application:

```cpp title="tests/host_test.cpp"
#include <wasmtime.hh>
#include <cassert>

int main() {
    wasmtime::Engine engine;
    wasmtime::Store store(engine);

    // Load the component
    auto component = wasmtime::Component::from_file(
        engine, "bazel-bin/calculator.wasm"
    );

    // Instantiate and test
    wasmtime::Linker linker(engine);
    auto instance = linker.instantiate(store, component);

    // Call exported functions
    auto add = instance.get_func(store, "add");
    // ... test assertions
}
```

## Performance Optimization

### LOOM Optimization

Optimize your component with the LOOM WebAssembly optimizer:

```python title="BUILD.bazel"
load("@rules_wasm_component//wasm:defs.bzl", "wasm_optimize")

wasm_optimize(
    name = "calculator_optimized",
    component = ":calculator",
    stats = True,      # Show optimization statistics
    verify = False,    # Enable for Z3 formal verification
)
```

LOOM performs:
- **Constant folding** - Compile-time evaluation
- **Strength reduction** - Replace expensive ops (x * 8 → x << 3)
- **Function inlining** - Cross-function optimization

Typical results: 80-95% binary size reduction.

### AOT Compilation

Pre-compile for faster startup:

```python title="BUILD.bazel"
load("@rules_wasm_component//wasm:defs.bzl", "wasm_precompile")

wasm_precompile(
    name = "calculator_aot",
    component = ":calculator",
)
```

## Debugging

### Validate Component Structure

```bash
# Inspect component interfaces
wasm-tools component wit bazel-bin/my_component.wasm

# Validate component model compliance
wasm-tools validate bazel-bin/my_component.wasm
```

### Check Binary Size

```bash
# Check size
ls -lh bazel-bin/my_component.wasm

# Analyze sections
wasm-tools objdump bazel-bin/my_component.wasm
```

### Debug Build

```python
cpp_component(
    name = "my_component_debug",
    # ...
    optimize = False,
    copts = ["-g", "-O0"],  # Debug symbols
)
```

## Troubleshooting

### Common Issues

**Exception support error:**
```
error: exception handling not supported
```

Solution: Set `enable_exceptions = False`:
```python
cpp_component(
    enable_exceptions = False,
)
```

**Missing WIT bindings:**
```
error: 'calculator_cpp.h' file not found
```

Solution: Ensure WIT file is specified:
```python
cpp_component(
    wit = "calculator.wit",
    world = "calculator",
)
```

**Namespace mismatch:**
```
undefined reference to `exports::example::calc::Add'
```

Solution: Check WIT package name matches namespace:
```wit
package example:simple-calculator@1.0.0;  // Creates exports::example::simple_calculator
```

**Linking errors with stdlib:**
```
undefined reference to `__cxa_allocate_exception'
```

Solution: Use no-stdlib mode or disable exceptions:
```python
cpp_component(
    enable_exceptions = False,
    copts = ["-nostdlib"],
)
```

## Performance Tips

1. **Use `optimize = True`** for release builds
2. **Disable RTTI** with `enable_rtti = False` for smaller binaries
3. **Prefer stack allocation** over heap allocation
4. **Use fixed-size types** like `int32_t` instead of `int`
5. **Consider no-stdlib** for minimal components

## C vs C++ Bindings

| Feature | C Bindings | C++ Bindings |
|---------|------------|--------------|
| **Function names** | `example_calc_add` | `exports::example::calc::Add` |
| **Type safety** | Manual casting | Type-safe namespaces |
| **Code style** | C-compatible | Modern C++ idioms |
| **Interop** | Easier C library usage | Better with C++ deps |

Choose based on your codebase and team preferences.

<div class="demo-buttons">
  <a href="/examples/cpp/" class="demo-button">
    Full C++ Examples
  </a>
  <a href="/api/cpp_component/" class="demo-button">
    API Reference
  </a>
</div>

## Performance Characteristics

**Production-ready performance** out of the box:

<div class="perf-indicator">~1-2MB typical component size</div>
<div class="perf-indicator">Zero runtime overhead</div>
<div class="perf-indicator">No garbage collection</div>

C++ components offer excellent performance:

- **Predictable latency** - No GC pauses
- **Small binaries** - LTO and dead code elimination
- **Direct memory access** - Optimal data layout
- **WASI Preview 2** - Modern system interface support
