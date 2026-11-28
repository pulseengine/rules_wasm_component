// P3 component that spawns a task with wit_bindgen::spawn_local. This compiles
// only when the @crates hub enables wit-bindgen's `async-spawn` feature.
use hello_p3_spawn_bindings::exports::hello::interfaces::greeting::Guest;

struct Component;

impl Guest for Component {
    #[cfg(target_arch = "wasm32")]
    async fn greet(name: String) -> String {
        let handle = wit_bindgen::spawn_local(async move { format!("Hello, {}! (P3 spawned)", name) });
        handle.await.unwrap_or_default()
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn greet(name: String) -> String {
        format!("Hello, {}! (P3 host)", name)
    }
}

hello_p3_spawn_bindings::export!(Component with_types_in hello_p3_spawn_bindings);
