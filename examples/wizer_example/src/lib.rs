use std::collections::HashMap;

// Import the generated WIT bindings
use expensive_init_component_bindings::exports::expensive_init::api::compute::Guest;

// Global state that gets initialized by Wizer
static mut EXPENSIVE_DATA: Option<HashMap<String, i32>> = None;

// Component implementation
struct Component;

impl Guest for Component {
    fn compute(input: i32) -> i32 {
        // Use the pre-computed data (initialized by Wizer)
        unsafe {
            if let Some(ref data) = EXPENSIVE_DATA {
                data.get("multiplier").unwrap_or(&1) * input
            } else {
                input // Fallback if not pre-initialized
            }
        }
    }
}

// Wizer initialization function - runs at build time
// Note: As of wasmtime v39.0.0, the default function name changed from
// "wizer.initialize" to "wizer-initialize" for better component compatibility
#[export_name = "wizer-initialize"]
pub extern "C" fn wizer_initialize() {
    // Expensive computation that would normally happen at runtime
    let mut data = HashMap::new();

    // Simulate expensive initialization work
    for i in 1..1000 {
        let key = format!("key_{}", i);
        let value = expensive_computation(i);
        data.insert(key, value);
    }

    // Store the pre-computed multiplier
    data.insert("multiplier".to_string(), 42);

    // Set global state (this gets captured by Wizer)
    unsafe {
        EXPENSIVE_DATA = Some(data);
    }
}

fn expensive_computation(n: i32) -> i32 {
    // Simulate expensive work
    (1..n).fold(1, |acc, x| acc + x * x)
}

// Export the component implementation
expensive_init_component_bindings::export!(Component with_types_in expensive_init_component_bindings);
