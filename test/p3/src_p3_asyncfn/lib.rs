// P3 component whose WIT declares `async func` (#720). Guest-only: the
// native-guest host bindings cannot represent async functions.
use hello_p3_asyncfn_bindings::exports::hello::asyncfn::greeting::Guest;

struct Component;

impl Guest for Component {
    async fn greet(name: String) -> String {
        format!("Hello, {}! (P3 async func)", name)
    }
}

hello_p3_asyncfn_bindings::export!(Component with_types_in hello_p3_asyncfn_bindings);
