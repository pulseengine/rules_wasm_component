use test_component_with_deps_bindings::exports::test::consumer::advanced::Guest;
use test_component_with_deps_bindings::test::simple::math;

struct Component;

impl Guest for Component {
    fn compute(x: u32, y: u32) -> u32 {
        let sum = math::add(x, y);
        sum * 2
    }
}

test_component_with_deps_bindings::export!(Component with_types_in test_component_with_deps_bindings);