// P3 test component — async interface
use hello_p3_bindings::exports::hello::interfaces::greeting::Guest;

struct Component;

impl Guest for Component {
    async fn greet(name: String) -> String {
        format!("Hello, {}! (P3 async)", name)
    }
}

hello_p3_bindings::export!(Component with_types_in hello_p3_bindings);
