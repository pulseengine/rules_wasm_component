"""Python WebAssembly Component Model rules - PUBLIC API

STABILITY: Public API
The rules in this file are the public API of rules_wasm_component for Python.
They are subject to semantic versioning guarantees.

Python support uses componentize-py from Bytecode Alliance to build
Python code into WebAssembly components. componentize-py bundles Python
source with a WASM interpreter to create WASI Preview 2 components.

Two rules are provided:

1. python_wasm_component - Library component with custom WIT exports
2. python_wasm_binary - CLI executable targeting wasi:cli/command

Limitations:
- Pure Python only (no native extensions)
- Runtime is bundled in the WASM component (~25-40MB overhead)
- Best suited for business logic and glue code

Example usage:

    load("@rules_wasm_component//python:defs.bzl", "python_wasm_component", "python_wasm_binary")

    # Library component with custom interface
    python_wasm_component(
        name = "calculator",
        srcs = ["calculator.py"],
        wit = "calculator.wit",
        world = "calculator",
    )

    # CLI executable
    python_wasm_binary(
        name = "hello",
        srcs = ["app.py"],
    )

    # Run CLI with: wasmtime run bazel-bin/path/to/hello.wasm
"""

load(
    "//python/private:python_wasm_binary.bzl",
    _python_wasm_binary = "python_wasm_binary",
)
load(
    "//python/private:python_wasm_component.bzl",
    _python_wasm_component = "python_wasm_component",
)

# Re-export public rules
python_wasm_component = _python_wasm_component
python_wasm_binary = _python_wasm_binary
