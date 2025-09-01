// Example of using wit-bindgen generate!() macro directly in source code
use wit_bindgen::generate;

// Generate bindings using the macro approach
// The WIT files are made available via CARGO_MANIFEST_DIR environment variable
generate!({
    world: "macro-world",
    path: "../wit",  // Relative to CARGO_MANIFEST_DIR set by Bazel
});

// Implement the exported interface
struct Component;

impl Guest for Component {
    type Calculator = Calculator;
}

struct Calculator;

impl GuestCalculator for Calculator {
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
export!(Component);

// For testing and demonstration
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculator() {
        // Mock the logger for testing
        // In practice, this would be provided by the host

        let calc = Calculator;
        assert_eq!(GuestCalculator::add(&calc, 2.0, 3.0), 5.0);
        assert_eq!(GuestCalculator::multiply(&calc, 4.0, 5.0), 20.0);
    }
}
