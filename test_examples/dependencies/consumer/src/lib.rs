// Import the generated bindings
use consumer_component_bindings::exports::consumer::app::app::Guest;
use consumer_component_bindings::external::lib::utilities;

// Component implementation
struct Component;

impl Guest for Component {
    fn run() -> String {
        let formatted = utilities::format_message("Hello from consumer!");
        let timestamp = utilities::get_timestamp();
        format!("{} (timestamp: {})", formatted, timestamp)
    }
}

// Export the component
consumer_component_bindings::export!(Component with_types_in consumer_component_bindings);
