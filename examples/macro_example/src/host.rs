// Example host application using the macro-generated bindings
use wit_bindgen::generate;

// Generate host-side bindings using the same macro
// This demonstrates how the same WIT interface can be used from both sides
generate!({
    world: "macro-world",
    path: "../wit",
});

// Implement the imported interface (logger) that the component expects
struct HostLogger;

impl HostLogger {
    fn log(level: &str, message: &str) {
        println!("[{}] {}", level.to_uppercase(), message);
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("wit-bindgen macro example host application");

    // In a real application, this would load and instantiate the WASM component
    // For now, we'll just demonstrate that the bindings compile and work

    println!("Host-side calculator bindings generated successfully!");
    println!("In a full implementation, this would:");
    println!("1. Load the WASM component");
    println!("2. Instantiate it with logger implementation");
    println!("3. Call calculator functions");

    // Simulate logger calls that the component would make
    HostLogger::log("info", "Host application started");
    HostLogger::log("debug", "Calculator component would be loaded here");

    Ok(())
}
