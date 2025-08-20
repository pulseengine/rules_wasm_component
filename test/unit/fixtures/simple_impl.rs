#[cfg(target_arch = "wasm32")]
use test_component_simple_bindings::exports::test::simple::math::Guest;

struct Component;

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn add(a: u32, b: u32) -> u32 {
        a + b
    }
}

#[cfg(target_arch = "wasm32")]
test_component_simple_bindings::export!(Component with_types_in test_component_simple_bindings);
