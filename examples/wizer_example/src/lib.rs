use std::collections::HashMap;
use std::sync::OnceLock;

// Import the generated WIT bindings
use expensive_init_component_bindings::exports::expensive_init::api::compute::Guest;

// Global state that gets initialized once at startup
// Using OnceLock for safe, lazy initialization (Rust 2024 compatible)
// Note: Wizer pre-initialization would capture this state at build time,
// but wasmtime wizer currently has limitations with component model exports.
static EXPENSIVE_DATA: OnceLock<HashMap<String, i32>> = OnceLock::new();

// Component implementation
struct Component;

impl Guest for Component {
    fn compute(input: i32) -> i32 {
        // Get or initialize the data (would be pre-initialized with Wizer)
        let data = EXPENSIVE_DATA.get_or_init(initialize_data);
        data.get("multiplier").unwrap_or(&1) * input
    }
}

/// Initialize expensive data
/// In a full Wizer setup, this would run at build time via wizer-initialize export
fn initialize_data() -> HashMap<String, i32> {
    let mut data = HashMap::new();

    // Simulate expensive initialization work
    for i in 1..1000 {
        let key = format!("key_{}", i);
        let value = expensive_computation(i);
        data.insert(key, value);
    }

    // Store the pre-computed multiplier
    data.insert("multiplier".to_string(), 42);

    data
}

fn expensive_computation(n: i32) -> i32 {
    // Simulate expensive work
    (1..n).fold(1, |acc, x| acc + x * x)
}

// Export the component implementation
expensive_init_component_bindings::export!(Component with_types_in expensive_init_component_bindings);
