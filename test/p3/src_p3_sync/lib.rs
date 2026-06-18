// P3 component exposing a SYNC export via the async_interfaces override (#526).
//
// `greet` has a plain-sync WIT signature. Under the p3 default (--async all) it
// becomes an async-lift export, and this sync `fn greet` would fail to compile
// with "method should be `async` or return a future, but it is synchronous" —
// the exact friction reported in #526. The bindgen target forces it sync with
//   async_interfaces = ["all", "-export:hello:interfaces/greeting#greet"]
// so a call-return consumer (e.g. a witness MC/DC harness) can invoke it.
use hello_p3_sync_bindings::exports::hello::interfaces::greeting::Guest;

struct Component;

impl Guest for Component {
    fn greet(name: String) -> String {
        format!("Hello, {}! (P3 sync export)", name)
    }
}

hello_p3_sync_bindings::export!(Component with_types_in hello_p3_sync_bindings);
