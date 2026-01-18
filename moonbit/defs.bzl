"""MoonBit WebAssembly Component Model rules - PUBLIC API

STABILITY: Public API
The rules in this file are the public API of rules_wasm_component for MoonBit.
They are subject to semantic versioning guarantees.

STATUS: Work-in-Progress
    These rules are correctly implemented but depend on rules_moonbit producing
    actual .wasm files. Currently rules_moonbit needs a hermetic toolchain
    that downloads and runs the MoonBit compiler.

    See: https://github.com/pulseengine/rules_moonbit

MoonBit support uses the existing moonbit_wasm rule from rules_moonbit to compile
MoonBit source code to core WebAssembly, then wraps the output with Component Model
metadata using wit-bindgen and wasm-tools.

Two rules are provided:

1. moonbit_wasm_component - Library component with custom WIT exports
2. moonbit_wasm_binary - CLI executable targeting wasi:cli/command

Example usage:

    load("@rules_moonbit//moonbit:defs.bzl", "moonbit_wasm")
    load("@rules_wasm_component//moonbit:defs.bzl", "moonbit_wasm_component", "moonbit_wasm_binary")

    # Step 1: Compile MoonBit to core WASM (using rules_moonbit)
    moonbit_wasm(
        name = "calculator_core",
        srcs = ["calculator.mbt"],
    )

    # Step 2: Wrap as a component (using rules_wasm_component)
    moonbit_wasm_component(
        name = "calculator",
        lib = ":calculator_core",
        wit = "calculator.wit",
        world = "calculator",
    )

    # Or create a CLI binary:
    moonbit_wasm(
        name = "hello_core",
        srcs = ["hello.mbt"],
        is_main = True,
    )

    moonbit_wasm_binary(
        name = "hello",
        lib = ":hello_core",
    )

    # Run CLI with: wasmtime run bazel-bin/path/to/hello.wasm

Key advantages of MoonBit for WebAssembly:
- WASM-native: Compiles directly to WebAssembly (no interpreter overhead)
- 25x faster compilation than Rust
- ML-family syntax with strong type system
- wit-bindgen has native MoonBit support
"""

load(
    "//moonbit/private:moonbit_wasm_binary.bzl",
    _moonbit_wasm_binary = "moonbit_wasm_binary",
)
load(
    "//moonbit/private:moonbit_wasm_component.bzl",
    _moonbit_wasm_component = "moonbit_wasm_component",
)

# Re-export public rules
moonbit_wasm_component = _moonbit_wasm_component
moonbit_wasm_binary = _moonbit_wasm_binary
