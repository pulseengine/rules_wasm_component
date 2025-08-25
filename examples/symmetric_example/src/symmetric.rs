//! Symmetric component demonstrating same source code for native and WASM execution
//!
//! This component uses cpetig's symmetric wit-bindgen fork to enable the same
//! source code to be compiled for both native execution and WebAssembly components.

// Import the generated bindings
// In symmetric mode, these bindings work for both native and WASM targets
use symmetric_component_bindings::example::symmetric::logger::{log, log_calculation, LogLevel};
use symmetric_component_bindings::exports::example::symmetric::calculator::{Guest, Stats};

struct SymmetricCalculator;

impl Guest for SymmetricCalculator {
    fn add(a: i32, b: i32) -> i32 {
        let result = a + b;

        // Log the operation (works in both native and WASM)
        log_calculation(&format!("add({}, {})", a, b), result);
        log(LogLevel::Info, &format!("Addition result: {}", result));

        result
    }

    fn multiply(a: i32, b: i32) -> i32 {
        let result = a * b;

        // Log the operation
        log_calculation(&format!("multiply({}, {})", a, b), result);
        log(
            LogLevel::Info,
            &format!("Multiplication result: {}", result),
        );

        result
    }

    fn calculate_stats(numbers: Vec<i32>) -> Stats {
        if numbers.is_empty() {
            log(LogLevel::Warn, "Empty list provided to calculate_stats");
            return Stats {
                sum: 0,
                count: 0,
                average: 0.0,
                min: 0,
                max: 0,
            };
        }

        let sum: i32 = numbers.iter().sum();
        let count = numbers.len() as u32;
        let average = sum as f64 / count as f64;
        let min = *numbers.iter().min().unwrap();
        let max = *numbers.iter().max().unwrap();

        let stats = Stats {
            sum,
            count,
            average,
            min,
            max,
        };

        log(
            LogLevel::Info,
            &format!(
                "Calculated stats for {} numbers: sum={}, avg={:.2}, min={}, max={}",
                count, sum, average, min, max
            ),
        );

        stats
    }
}

// This macro works in both symmetric (native) and canonical (WASM) modes
symmetric_component_bindings::export!(SymmetricCalculator with_types_in symmetric_component_bindings);

#[cfg(feature = "symmetric")]
pub fn main() {
    // When compiled with symmetric feature, this can run natively
    println!("Running symmetric calculator natively");

    // Test the calculator functions directly
    let result = SymmetricCalculator::add(5, 3);
    println!("5 + 3 = {}", result);

    let result = SymmetricCalculator::multiply(4, 7);
    println!("4 * 7 = {}", result);

    let numbers = vec![1, 2, 3, 4, 5, 10];
    let stats = SymmetricCalculator::calculate_stats(numbers);
    println!(
        "Stats: sum={}, count={}, avg={:.2}",
        stats.sum, stats.count, stats.average
    );
}

#[cfg(not(feature = "symmetric"))]
pub fn main() {
    // In canonical (WASM) mode, this would be handled by the component runtime
    println!("Component compiled for WebAssembly execution");
}
