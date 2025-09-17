// AOT compilation demonstration component

// Import the generated WIT bindings
use hello_component_bindings::exports::example::hello::greeting::Guest;

// Component implementation
struct Component;

impl Guest for Component {
    fn hello(name: String) -> String {
        // Expensive initialization that would benefit from AOT pre-compilation
        let greeting = format!("Hello from AOT, {}!", name);
        greeting
    }
}

// Export the component implementation
hello_component_bindings::export!(Component with_types_in hello_component_bindings);
