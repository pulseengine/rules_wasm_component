#[cfg(target_arch = "wasm32")]
use greeting_component_bindings::exports::example::greeting::greet::Guest;

struct Component;

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn greet(name: String) -> String {
        format!(
            "🔒 Secure hello, {}! This component is dual-layer signed.",
            name
        )
    }
}

#[cfg(target_arch = "wasm32")]
greeting_component_bindings::export!(Component with_types_in greeting_component_bindings);
