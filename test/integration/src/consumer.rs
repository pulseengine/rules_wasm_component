use consumer_component_bindings::exports::test::consumer::processor::Guest;
use consumer_component_bindings::external::lib::utilities;

struct Component;

impl Guest for Component {
    fn process_data(input: String, number: u32) -> String {
        let hash = utilities::hash_string(&input);
        let formatted = utilities::format_number(number);
        format!(
            "Processed: {} (hash: {}, formatted: {})",
            input, hash, formatted
        )
    }
}

consumer_component_bindings::export!(Component with_types_in consumer_component_bindings);
