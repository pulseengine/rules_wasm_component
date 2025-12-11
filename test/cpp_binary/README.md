# C/C++ WASM Binary Tests

Tests for `cpp_wasm_binary` and `c_wasm_binary` rules that create WASI CLI executables
without requiring WIT interface definitions.

## What These Rules Do

- `cpp_wasm_binary`: Compiles C++ source to WASI CLI binary
- `c_wasm_binary`: Compiles C source to WASI CLI binary

Both produce standalone WebAssembly executables that can be run with:

```bash
wasmtime run bazel-bin/test/cpp_binary/hello_cpp.wasm
wasmtime run bazel-bin/test/cpp_binary/hello_c.wasm
```

## Difference from cpp_component

| Rule | WIT Required | Output | Use Case |
|------|--------------|--------|----------|
| `cpp_component` | Yes (mandatory) | Component with custom interface | Building composable components |
| `cpp_wasm_binary` | No | WASI CLI executable | Building standalone CLI tools |

## Running Tests

```bash
bazel test //test/cpp_binary:cpp_binary_tests
```
