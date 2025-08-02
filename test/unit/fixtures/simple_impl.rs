use test_component_simple_bindings::exports::test::simple::math::Guest;

struct Component;

impl Guest for Component {
    fn add(a: u32, b: u32) -> u32 {
        a + b
    }
}

test_component_simple_bindings::export!(Component with_types_in test_component_simple_bindings);
