// Example host application for macro-generated component
//
// This demonstrates a simple host that would interact with the WASM component.
// In a full implementation, this would use wasmtime or similar runtime.

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("wit-bindgen macro example host application");
    println!();
    println!("This host application demonstrates the macro-based approach.");
    println!("The WASM component (macro_component) was built using:");
    println!("  - wit-bindgen's generate!() macro directly in source");
    println!("  - WIT files provided via CARGO_MANIFEST_DIR from Bazel");
    println!();
    println!("In a full implementation, this host would:");
    println!("  1. Load the macro_component.wasm file");
    println!("  2. Provide a logger implementation to the component");
    println!("  3. Call the calculator's add() and multiply() functions");

    Ok(())
}
