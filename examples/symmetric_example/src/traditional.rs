//! Traditional component using separate guest and native-guest bindings
//!
//! This demonstrates the traditional approach where we have separate bindings
//! for WASM component implementation and host-side usage.

#[cfg(target_arch = "wasm32")]
use traditional_component_bindings::exports::example::symmetric::calculator::{Guest, Stats};

// Mock logger imports since they're not available in the generated bindings
#[cfg(target_arch = "wasm32")]
#[allow(dead_code)]
pub enum LogLevel {
    Debug,
    Info,
    Warn,
    Error,
}

#[cfg(target_arch = "wasm32")]
#[allow(dead_code)]
fn log(_level: LogLevel, message: &str) {
    // Mock implementation - in real scenario, this would be provided by the host
    eprintln!("LOG: {}", message);
}

#[cfg(target_arch = "wasm32")]
#[allow(dead_code)]
fn log_calculation(operation: &str, value: i32) {
    // Mock implementation
    eprintln!("CALC: {} = {}", operation, value);
}

struct TraditionalCalculator;

#[cfg(target_arch = "wasm32")]
impl Guest for TraditionalCalculator {
    fn add(a: i32, b: i32) -> i32 {
        let result = a + b;

        log_calculation(&format!("traditional_add({}, {})", a, b), result);
        log(
            LogLevel::Info,
            &format!("Traditional addition result: {}", result),
        );

        result
    }

    fn multiply(a: i32, b: i32) -> i32 {
        let result = a * b;

        log_calculation(&format!("traditional_multiply({}, {})", a, b), result);
        log(
            LogLevel::Info,
            &format!("Traditional multiplication result: {}", result),
        );

        result
    }

    fn calculate_stats(numbers: Vec<i32>) -> Stats {
        if numbers.is_empty() {
            log(
                LogLevel::Warn,
                "Empty list provided to traditional calculate_stats",
            );
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
                "Traditional calculated stats for {} numbers: sum={}, avg={:.2}, min={}, max={}",
                count, sum, average, min, max
            ),
        );

        stats
    }
}

#[cfg(target_arch = "wasm32")]
traditional_component_bindings::export!(TraditionalCalculator with_types_in traditional_component_bindings);

// Native stub implementation for compilation compatibility
#[cfg(not(target_arch = "wasm32"))]
pub fn main() {
    println!("Traditional component - WASM target required for full functionality");
}
