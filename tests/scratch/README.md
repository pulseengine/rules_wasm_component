# Scratch Test Files

This directory contains temporary test files used during development and debugging.

## Purpose

These files are for:

- Quick TinyGo compilation tests
- Manual toolchain validation
- Debugging build issues
- Temporary experimental code

## Usage

```bash
# Build a test with TinyGo
tinygo build -target=wasip2 -o test.wasm test_tinygo.go

# Run with wasmtime
wasmtime run test.wasm
```

## Note

Files in this directory are temporary and should not be committed to the repository.
Use the proper `test/` directory structure for permanent test cases.
