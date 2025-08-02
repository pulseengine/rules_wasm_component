use std::collections::HashMap;

// Global state that gets initialized by Wizer
static mut EXPENSIVE_DATA: Option<HashMap<String, i32>> = None;

// Simple function that can be called without WIT bindings
#[no_mangle]
pub extern "C" fn compute(input: i32) -> i32 {
    // Use the pre-computed data (initialized by Wizer)
    unsafe {
        if let Some(ref data) = EXPENSIVE_DATA {
            data.get("multiplier").unwrap_or(&1) * input
        } else {
            input // Fallback if not pre-initialized
        }
    }
}

// Wizer initialization function - runs at build time
#[export_name = "wizer.initialize"]
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
