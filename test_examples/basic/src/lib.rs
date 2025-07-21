// Import the generated WIT bindings
use hello_component_bindings::exports::example::hello::greeting::Guest;

// Component implementation
struct Component;

impl Guest for Component {
    fn say_hello(name: String) -> String {
        format!("Hello, {}!", name)
    }
}

// Export the component implementation
hello_component_bindings::export!(Component with_types_in hello_component_bindings);