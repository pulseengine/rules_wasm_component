// Simple WASM module (not a component)
// This demonstrates basic WASM functionality without component model complexity

#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn multiply(a: i32, b: i32) -> i32 {
    a * b
}

#[no_mangle]
pub extern "C" fn get_answer() -> i32 {
    42
}

// Export memory for the host to use
#[no_mangle]
pub static mut GLOBAL_COUNTER: i32 = 0;

#[no_mangle]
pub extern "C" fn increment_counter() -> i32 {
    unsafe {
        GLOBAL_COUNTER += 1;
        GLOBAL_COUNTER
    }
}
