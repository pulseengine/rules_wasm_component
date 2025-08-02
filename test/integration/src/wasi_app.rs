use wasi_component_bindings::exports::test::wasi_app::app::Guest;

struct Component;

impl Guest for Component {
    fn run() -> u32 {
        // Simple application that always succeeds
        42
    }

    fn process_data(input: String) -> String {
        // Simple data processing
        format!("Processed: {}", input.to_uppercase())
    }
}

wasi_component_bindings::export!(Component with_types_in wasi_component_bindings);
