// Tiny greeter component used to demonstrate the PulseEngine attestation
// pipeline: build -> sign -> attest -> verify_chain -> show_chain.

use greeter_component_bindings::exports::example::greet::greeter::Guest;

struct Component;

impl Guest for Component {
    fn greet(name: String) -> String {
        format!("Hello, {name}!")
    }
}

greeter_component_bindings::export!(Component with_types_in greeter_component_bindings);
