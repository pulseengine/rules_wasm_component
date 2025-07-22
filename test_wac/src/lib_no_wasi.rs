#![no_std]

use nowasi_component_bindings::exports::test::nowasi::math::Guest;

struct Component;

impl Guest for Component {
    fn add(a: i32, b: i32) -> i32 {
        a + b
    }
}

nowasi_component_bindings::export!(Component with_types_in nowasi_component_bindings);