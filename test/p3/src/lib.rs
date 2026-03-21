// P2 test component
use hello_p2_bindings::exports::hello::interfaces::greeting::Guest;

struct Component;

impl Guest for Component {
    fn greet(name: String) -> String {
        format!("Hello, {}!", name)
    }
}

hello_p2_bindings::export!(Component with_types_in hello_p2_bindings);
