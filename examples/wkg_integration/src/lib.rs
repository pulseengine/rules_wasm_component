// Import the generated WIT bindings
use example_component_bindings::exports::example::component::example_service::{Guest, ServiceInfo};

// Component implementation
struct Component;

impl Guest for Component {
    fn process_request(request: String) -> String {
        format!("Processed: {}", request)
    }
    
    fn get_metadata() -> ServiceInfo {
        ServiceInfo {
            name: "Example Component".to_string(),
            version: "1.0.0".to_string(),
            description: "A sample WebAssembly component for wkg integration".to_string(),
        }
    }
}

// Export the component implementation
example_component_bindings::export!(Component with_types_in example_component_bindings);