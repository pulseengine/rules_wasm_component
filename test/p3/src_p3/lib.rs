// P3 test component — async on WASM, sync on host
use hello_p3_bindings::exports::hello::interfaces::greeting::Guest;

struct Component;

impl Guest for Component {
    #[cfg(target_arch = "wasm32")]
    async fn greet(name: String) -> String {
        format!("Hello, {}! (P3 async)", name)
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn greet(name: String) -> String {
        format!("Hello, {}! (P3 host)", name)
    }
}

hello_p3_bindings::export!(Component with_types_in hello_p3_bindings);
