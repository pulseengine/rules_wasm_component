/// MoonBit WebAssembly CLI Binary Example
///
/// A simple "Hello, World!" program that demonstrates building MoonBit code
/// as a WebAssembly CLI binary using the moonbit_wasm_binary rule.
///
/// Run with: wasmtime run bazel-bin/examples/moonbit_component/hello_cli.wasm

fn main {
  println("Hello from MoonBit WebAssembly!")
  println("This is a WASI CLI component built with rules_wasm_component.")
}
