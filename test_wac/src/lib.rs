use simple_component_bindings::exports::test::simple::math::Guest;

struct Component;

impl Guest for Component {
    fn add(a: i32, b: i32) -> i32 {
        a + b
    }
}

simple_component_bindings::export!(Component with_types_in simple_component_bindings);
