# Go WebAssembly Components Example

This example demonstrates how to build WebAssembly components from Go source code using wit-bindgen-go and the Go component rules.

## Overview

The Go component rules provide:

1. **`go_component`** - Compiles Go code to WebAssembly components
2. **`go_wit_bindgen`** - Generates Go bindings from WIT interfaces
3. **`go_mod_download`** - Manages Go module dependencies

## Example Structure

```
examples/go_component/
├── BUILD.bazel           # Build configuration
├── go.mod               # Go module definition
├── main.go              # Calculator component main
├── calculator.go        # Calculator utilities
├── service.go           # HTTP service component main
├── handlers.go          # HTTP request handlers
├── wit/                 # WIT interface definitions
│   ├── calculator.wit   # Calculator interface
│   └── http-service.wit # HTTP service interface
└── README.md           # This file
```

## Building Components

### Calculator Component

```starlark
go_component(
    name = "calculator_go_component",
    srcs = [
        "main.go",
        "calculator.go",
    ],
    wit = "wit/calculator.wit",
    go_mod = "go.mod",
    go_package = "github.com/example/calculator",
    main_file = "main.go",
    world = "calculator",
    package_name = "example:calculator@1.0.0",
)
```

### HTTP Service Component

```starlark
go_component(
    name = "http_service_component",
    srcs = [
        "service.go",
        "handlers.go",
    ],
    wit = "wit/http-service.wit",
    go_mod = "go.mod",
    go_package = "github.com/example/httpservice",
    main_file = "service.go",
    world = "http-service",
    package_name = "example:http-service@1.0.0",
)
```

## Toolchain Configuration

The Go WebAssembly toolchain can be configured using different strategies:

### System Installation
```starlark
# MODULE.bazel
go_wasm = use_extension("@rules_wasm_component//wasm:extensions.bzl", "go_wasm")
go_wasm.register(strategy = "system")
```

### Build from Source
```starlark
# MODULE.bazel
go_wasm = use_extension("@rules_wasm_component//wasm:extensions.bzl", "go_wasm")
go_wasm.register(strategy = "build", wit_bindgen_go_version = "0.1.0")
```

### Download Prebuilt
```starlark
# MODULE.bazel
go_wasm = use_extension("@rules_wasm_component//wasm:extensions.bzl", "go_wasm")
go_wasm.register(strategy = "download", wit_bindgen_go_version = "0.1.0")
```

## Go Module Setup

Create a `go.mod` file for your component:

```go
module github.com/example/calculator

go 1.21

require (
    github.com/bytecodealliance/wasm-tools-go v0.1.1
)
```

## Component Implementation

### Interface Implementation

Components implement WIT interfaces through Go structs:

```go
// CalculatorImpl implements the calculator interface
type CalculatorImpl struct{}

func (c *CalculatorImpl) Add(a, b float64) float64 {
    return a + b
}

func (c *CalculatorImpl) Divide(a, b float64) bindings.CalculationResult {
    if b == 0 {
        return bindings.CalculationResult{
            Success: false,
            Error:   bindings.Some("Division by zero is not allowed"),
            Result:  bindings.None[float64](),
        }
    }
    
    return bindings.CalculationResult{
        Success: true,
        Error:   bindings.None[string](),
        Result:  bindings.Some(a / b),
    }
}
```

### Component Initialization

Initialize the component in your main function:

```go
func main() {
    // Initialize the component
    bindings.SetExports(&CalculatorImpl{})
}
```

## Generated Bindings

The `go_wit_bindgen` rule generates Go bindings from WIT files:

```starlark
go_wit_bindgen(
    name = "calculator_bindings", 
    wit = "wit/calculator.wit",
    go_package = "github.com/example/calculator",
    world = "calculator",
)
```

This generates Go types and interfaces that match your WIT definitions:

```go
// Generated types
type Operation struct {
    Op OperationType
    A  float64
    B  float64
}

type CalculationResult struct {
    Success bool
    Error   Option[string]
    Result  Option[float64]
}

// Generated interface
type Calculator interface {
    Add(a, b float64) float64
    Subtract(a, b float64) float64 
    Multiply(a, b float64) float64
    Divide(a, b float64) CalculationResult
    Calculate(operation Operation) CalculationResult
    GetCalculatorInfo() ComponentInfo
}
```

## Building

```bash
# Build calculator component
bazel build //examples/go_component:calculator_go_component

# Build HTTP service component  
bazel build //examples/go_component:http_service_component

# Generate Go bindings
bazel build //examples/go_component:calculator_bindings

# Download Go dependencies
bazel build //examples/go_component:go_deps
```

## Features

### Go Module Support
Components can use Go modules and external dependencies:

```go
import (
    "math"
    "fmt"
    "github.com/some/external/package"
)
```

### Type Safety
Generated bindings provide full type safety:

```go
// Option types for nullable values
type Option[T any] struct {
    // Implementation details...
}

func Some[T any](value T) Option[T] { /* ... */ }
func None[T any]() Option[T] { /* ... */ }
```

### Error Handling
Idiomatic Go error handling with WIT result types:

```go
func (c *CalculatorImpl) Divide(a, b float64) bindings.CalculationResult {
    if b == 0 {
        return bindings.CalculationResult{
            Success: false,
            Error:   bindings.Some("Division by zero"),
            Result:  bindings.None[float64](),
        }
    }
    
    return bindings.CalculationResult{
        Success: true,
        Error:   bindings.None[string](),
        Result:  bindings.Some(a / b),
    }
}
```

### Standard Library Support
Components can use Go standard library packages that are compatible with WASI:

```go
import (
    "fmt"
    "time"
    "encoding/json"
    "strconv"
    "strings"
)
```

## Requirements

- **Go**: Go compiler (1.21 or later)
- **wit-bindgen-go**: Go bindings generator for WIT
- **wasm-tools**: WebAssembly component tools

## Installation

Install wit-bindgen-go:

```bash
go install github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest
```

Or use the automatic toolchain setup in your MODULE.bazel file.

## Integration with Other Components

Go components can be used with other rules in the ecosystem:

```starlark
# Compose with other components
wac_compose(
    name = "full_system",
    components = {
        "calculator": ":calculator_go_component",
        "frontend": "//js:ui_component",
    },
)

# Use in remote compositions
wac_remote_compose(
    name = "distributed_calc",
    local_components = {
        "backend": ":calculator_go_component",
    },
    remote_components = {
        "auth": "registry/auth@1.0.0",
    },
)
```

## Troubleshooting

- Ensure Go 1.21+ is installed and in PATH
- Check that GOPATH and GOROOT are properly configured
- Verify wit-bindgen-go is available (for system strategy)
- Make sure WIT interfaces match Go implementations
- Use `GOOS=wasip1 GOARCH=wasm` for manual compilation testing
- Check that all imports are WASI-compatible

## Performance Considerations

- Go components compile to efficient WASM bytecode
- Standard library functions are optimized for WASI
- Consider using build tags for WASM-specific optimizations:

```go
//go:build wasm

package main

// WASM-specific implementations
```