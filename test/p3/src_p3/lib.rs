// P3 test component
use hello_p3_bindings::exports::hello::interfaces::greeting::Guest;

struct Component;

impl Guest for Component {
    fn greet(name: String) -> String {
        format!("Hello, {}! (P3)", name)
    }
}

hello_p3_bindings::export!(Component with_types_in hello_p3_bindings);
