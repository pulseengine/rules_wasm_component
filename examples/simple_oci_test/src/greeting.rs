// Simple greeting component implementation
use greeting_component_bindings::exports::simple::greeting::greet::Guest;

struct Greeting;

impl Guest for Greeting {
    fn greet(name: String) -> String {
        format!("Hello, {}! Welcome to the simple OCI test.", name)
    }
}

greeting_component_bindings::export!(Greeting with_types_in greeting_component_bindings);
