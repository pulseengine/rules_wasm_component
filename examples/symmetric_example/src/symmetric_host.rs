//! Host application that can use symmetric component bindings
//!
//! This demonstrates how the same component logic can be used from a host application
//! when using symmetric wit-bindgen mode.

use symmetric_component_bindings::example::symmetric::calculator::{
    add, calculate_stats, multiply,
};
use symmetric_component_bindings::example::symmetric::logger::LogLevel;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Symmetric Host Application");
    println!("=========================");

    // Use the symmetric component's calculator functions directly
    // This is the same code that runs in the WASM component!

    println!("\nBasic arithmetic:");
    let sum = add(15, 25);
    println!("15 + 25 = {}", sum);

    let product = multiply(6, 9);
    println!("6 * 9 = {}", product);

    println!("\nStatistics calculation:");
    let numbers = vec![10, 20, 5, 8, 15, 3, 12, 25, 7];
    let stats = calculate_stats(numbers.clone());

    println!("Input numbers: {:?}", numbers);
    println!("Sum: {}", stats.sum);
    println!("Count: {}", stats.count);
    println!("Average: {:.2}", stats.average);
    println!("Min: {}", stats.min);
    println!("Max: {}", stats.max);

    println!("\nSymmetric mode benefits:");
    println!("- Same source code runs natively and as WASM component");
    println!("- No separate host bindings needed");
    println!("- Unified development and testing workflow");
    println!("- Direct function calls without WASM overhead for native execution");

    Ok(())
}

// Mock logger implementation for native execution
#[cfg(not(target_arch = "wasm32"))]
mod mock_logger {
    use super::*;

    pub fn log(level: LogLevel, message: &str) {
        let level_str = match level {
            LogLevel::Debug => "DEBUG",
            LogLevel::Info => "INFO",
            LogLevel::Warn => "WARN",
            LogLevel::Error => "ERROR",
        };
        println!("[{}] {}", level_str, message);
    }

    pub fn log_calculation(operation: &str, result: i32) {
        println!("[CALC] {} = {}", operation, result);
    }
}
