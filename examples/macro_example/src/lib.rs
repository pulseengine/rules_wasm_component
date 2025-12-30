// Example of using wit-bindgen generate!() macro directly in source code
//
// Note: The macro approach works but requires careful path configuration.
// For Bazel builds, the `rust_wasm_component_bindgen` rule is recommended
// as it handles WIT paths automatically.

use wit_bindgen::generate;

// Generate bindings using the macro approach
// The WIT files are made available via CARGO_MANIFEST_DIR environment variable
// which points to the wit_library output directory
generate!({
    world: "macro-world",
    path: ".",  // Points to wit_library output directory (set via CARGO_MANIFEST_DIR)
});

// Use generated imports
use exports::macro_::example::calculator::Guest as CalculatorGuest;
use macro_::example::logger;

// Implement the exported calculator interface
struct CalculatorImpl;

impl CalculatorGuest for CalculatorImpl {
    fn add(a: f64, b: f64) -> f64 {
        let result = a + b;

        // Use imported logger interface
        logger::log("info", &format!("Adding {} + {} = {}", a, b, result));

        result
    }

    fn multiply(a: f64, b: f64) -> f64 {
        let result = a * b;

        // Use imported logger interface
        logger::log("info", &format!("Multiplying {} * {} = {}", a, b, result));

        result
    }
}

// Export the component implementation
export!(CalculatorImpl);
