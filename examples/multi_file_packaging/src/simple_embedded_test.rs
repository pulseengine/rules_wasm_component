//! Simple embedded service test to debug binding issues

#[cfg(target_arch = "wasm32")]
use simple_embedded_test_component_bindings::exports::example::simple_test::service::Guest;

struct Component;

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process(input: String) -> String {
        format!("Processed: {}", input)
    }
}

#[cfg(target_arch = "wasm32")]
simple_embedded_test_component_bindings::export!(Component with_types_in simple_embedded_test_component_bindings);