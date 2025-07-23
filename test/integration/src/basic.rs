use basic_component_bindings::exports::test::basic::calculator::Guest;

struct Component;

impl Guest for Component {
    fn add(a: u32, b: u32) -> u32 {
        a + b
    }
    
    fn multiply(a: u32, b: u32) -> u32 {
        a * b
    }
}

basic_component_bindings::export!(Component with_types_in basic_component_bindings);