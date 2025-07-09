// Test that the export! macro is accessible from user code
use test_component_bindings::exports::test::visibility::greeter::Guest;

struct Component;

impl Guest for Component {
    fn greet(name: String) -> String {
        format!("Hello, {}!", name)
    }
}

// This is the critical test - the export! macro must be accessible
test_component_bindings::export!(Component with_types_in test_component_bindings);