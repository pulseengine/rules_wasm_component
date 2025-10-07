# Go WebAssembly Components with TinyGo + WASI Preview 2

This example demonstrates **state-of-the-art Go support** for WebAssembly Component Model using TinyGo v0.38.0 with proper component transformation.

## Architecture

- **TinyGo v0.38.0**: Compiler with dual-step component generation (WASI → Component)
- **go.bytecodealliance.org**: Official BytecodeAlliance Go modules for WIT bindings
- **WASI Adapter**: Preview 1 to Preview 2 transformation using official adapter
- **Production Ready**: Optimized builds with proper component transformation

## Features

✅ **WASI Preview 2**: Native support for latest WASI specification
✅ **Component Model**: Full WebAssembly Component Model compatibility
✅ **WIT Bindings**: Automatic Go code generation from WIT definitions
✅ **Cross Platform**: Works on Linux, macOS, and Windows
✅ **Production Optimized**: Release builds with size/performance optimization

## Prerequisites

1. **TinyGo v0.38.0** (automatically downloaded by Bazel)
2. **Go 1.24+** (for wit-bindgen-go and module management)
3. **wasm-tools** (for component transformation)
4. **WASI Preview 1 Adapter** (automatically provided by Bazel)

The Bazel toolchain automatically handles tool downloads and setup.

## Building Components

### Basic Component

```bash
# Build calculator component (release)
bazel build //examples/go_component:calculator_component

# Build with debug symbols
bazel build //examples/go_component:calculator_component_debug
```

### HTTP Service Component

```bash
# Build HTTP service component
bazel build //examples/go_component:http_service_component
```

### Generate Bindings Only

```bash
# Generate Go bindings from WIT
bazel build //examples/go_component:calculator_bindings
```

## Component Architecture

### Workflow

1. **WIT Definition** → Define component interfaces in `wit/*.wit`
2. **Go Bindings** → `wit-bindgen-go` generates Go code from WIT
3. **TinyGo Compilation** → Compile to WASM module with `--target=wasi --scheduler=none`
4. **Component Transformation** → `wasm-tools component new` with WASI adapter creates final component

### Example Structure

```
examples/go_component/
├── BUILD.bazel              # Bazel build configuration
├── go.mod                   # Go module definition
├── main.go                  # Component entry point
├── calculator.go            # Business logic
├── service.go              # HTTP service implementation
├── handlers.go             # Request handlers
└── wit/
    ├── calculator.wit       # Calculator interface definition
    └── http-service.wit     # HTTP service interface definition
```

## Implementation Details

### TinyGo Configuration

```starlark
go_wasm_component(
    name = "my_component",
    srcs = ["main.go", "logic.go"],
    wit = "wit/component.wit",
    world = "my-world",
    go_mod = "go.mod",
    optimization = "release",  # or "debug"
    adapter = "//wasm/adapters:wasi_snapshot_preview1",  # Required
)
```

### WASI Preview 2 Features

- **Networking**: Full TCP/UDP socket support
- **Filesystem**: WASI filesystem APIs
- **Environment**: Environment variables and command-line args
- **Clocks**: Monotonic and wall-clock time
- **Random**: Cryptographically secure random numbers

### Component Model Benefits

- **Interface Types**: Rich type system with records, variants, resources
- **Capability Security**: Fine-grained permission model
- **Composability**: Link multiple components together
- **Language Interop**: Call between Go, Rust, C++, JavaScript components

## TinyGo WASI Runtime Requirement

### Why TinyGo Components Always Need WASI

Unlike C/C++ or Rust, **TinyGo reactor components (even with empty `main()`) require WASI imports**. This is due to TinyGo's Go runtime architecture, not a Component Model limitation.

**TinyGo Runtime Architecture:**
- TinyGo's Go runtime is built on WASI primitives for system operations
- Even reactor components with `func main() {}` trigger runtime initialization
- Runtime initialization performs memory management, goroutine setup, and I/O configuration
- This is an architectural decision in TinyGo's design

**Required WASI Imports:**

All TinyGo components (both command and reactor) require these WASI Preview 2 interfaces:

```wit
world tinygo-component {
    // I/O streams for runtime initialization
    import wasi:io/streams@0.2.0;

    // CLI interfaces for stdout/stderr/stdin
    import wasi:cli/stdout@0.2.0;
    import wasi:cli/stderr@0.2.0;
    import wasi:cli/stdin@0.2.0;

    // Clock for time operations (time.Now(), etc.)
    import wasi:clocks/wall-clock@0.2.0;

    // Filesystem for runtime initialization
    import wasi:filesystem/types@0.2.0;
    import wasi:filesystem/preopens@0.2.0;

    // Your component's exports
    export my-interface;
}
```

**Contrast with Other Languages:**

| Language | Pure Reactor (No WASI) | Why? |
|----------|------------------------|------|
| C/C++    | ✅ Possible | Can compile with `-nostdlib`, no runtime dependencies |
| Rust     | ✅ Possible | `#![no_std]` removes runtime, pure library mode |
| **TinyGo** | ❌ Not Possible | Runtime always initializes with WASI dependencies |

**What TinyGo's Compiler Generates:**

Even for a minimal reactor component:
```go
package main

func main() {}  // Empty, reactor mode

//export my_function
func my_function() int32 {
    return 42
}
```

The TinyGo compiler still generates:
1. Runtime initialization code that calls WASI filesystem APIs
2. I/O stream setup for panic/error handling
3. Clock initialization for time operations
4. Memory allocator setup using WASI primitives

**Practical Implications:**

- **Component Composition**: Your Go component will have WASI import requirements
- **Host Requirements**: The runtime (wasmtime, wasmer) must provide WASI Preview 2
- **Performance**: The imports are lightweight and don't impact performance significantly
- **Deployment**: This is transparent in most scenarios - modern runtimes provide WASI by default

**No Workarounds Available:**

There are no practical workarounds. TinyGo components always require WASI. However:
- Most component hosts (wasmtime, wasmer, etc.) provide WASI Preview 2 by default
- The WASI overhead is minimal and doesn't affect component composability
- This is a known and accepted characteristic of TinyGo's design

**Upstream Tracking:**

See [TinyGo Issue #2703](https://github.com/tinygo-org/tinygo/issues/2703) for discussions about making the runtime more modular.

## Testing Components

```bash
# Test with wasmtime (WASI Preview 2 runtime)
wasmtime run --wasi preview2 bazel-bin/examples/go_component/calculator_component_component.wasm

# Test with wac (WebAssembly Composition)
wac run bazel-bin/examples/go_component/calculator_component_component.wasm
```

## Performance

TinyGo with WASI Preview 2 provides:

- **Small binaries**: Optimized for size with `-gc=leaking` in release mode
- **Fast startup**: Minimal runtime overhead
- **Memory efficient**: Conservative GC in debug, leaking GC in release
- **Native performance**: Direct WebAssembly compilation

## Migration from wit-bindgen-go

This replaces the old broken `wit-bindgen-go` binary approach with:

- ✅ **Official Go modules**: `go.bytecodealliance.org`
- ✅ **TinyGo native support**: No external dependencies
- ✅ **WASI Preview 2**: Latest WASI specification
- ✅ **Component Model**: Full CM support

## Development Workflow

1. **Define Interface**: Write WIT files describing your component
2. **Generate Bindings**: Use `go_wit_bindgen` to create Go interfaces
3. **Implement Logic**: Write Go code implementing the WIT world
4. **Build Component**: Use `go_wasm_component` for final WASM component
5. **Test & Deploy**: Run with WASI Preview 2 compatible runtimes

This approach provides **production-ready** Go WebAssembly components with full WASI Preview 2 and Component Model support! 🚀
