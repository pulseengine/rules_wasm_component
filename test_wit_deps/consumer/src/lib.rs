use consumer_component_bindings::exports::consumer::app::app::Guest;

struct Component;

impl Guest for Component {
    fn run() -> String {
        "Hello from consumer".to_string()
    }
}

consumer_component_bindings::export!(Component with_types_in consumer_component_bindings);