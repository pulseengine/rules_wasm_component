# Basic WebAssembly Component Example

This example demonstrates the simplest possible WebAssembly component using Rust.

## Files

- `src/lib.rs` - Rust component implementation
- `wit/hello.wit` - WIT interface definition
- `BUILD.bazel` - Bazel build configuration

## Building

```bash
# Build the component
bazel build //examples/basic:hello_component

# Test the component
bazel test //examples/basic:hello_component_test
```

## WIT Interface

The component exports a simple `hello` function:

```wit
package hello:world;

world hello {
  export hello: func(name: string) -> string;
}
```

## Running

```bash
# Test with wasmtime
wasmtime run --wasi preview2 bazel-bin/examples/basic/hello_component.wasm

# Or use the built-in test
bazel test //examples/basic:hello_component_test
```

This demonstrates the minimal setup required for a WebAssembly component with rules_wasm_component.
