//! Simple layered service test demonstrating file access from layers

#[cfg(target_arch = "wasm32")]
use simple_layered_test_component_bindings::exports::example::simple_test::service::Guest;

struct Component;

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process(input: String) -> String {
        // Try to read configuration from a mounted layer
        let config_result = std::fs::read_to_string("/etc/service/config.json");
        
        // Try to read template from a mounted layer
        let template_result = std::fs::read_to_string("/etc/service/templates/response.html");
        
        match (config_result, template_result) {
            (Ok(config), Ok(template)) => {
                // Both files available from layers
                format!("Layered Service: {} | Config: {} | Template: {}", 
                       input, 
                       config.chars().take(50).collect::<String>(),
                       template.chars().take(50).collect::<String>())
            },
            (Ok(config), Err(_)) => {
                // Only config available
                format!("Layered Service (config only): {} | Config: {}", 
                       input,
                       config.chars().take(50).collect::<String>())
            },
            (Err(_), Ok(template)) => {
                // Only template available
                format!("Layered Service (template only): {} | Template: {}", 
                       input,
                       template.chars().take(50).collect::<String>())
            },
            (Err(_), Err(_)) => {
                // No layers mounted - fallback behavior
                format!("Layered Service (no layers): Processed {}", input)
            }
        }
    }
}

#[cfg(target_arch = "wasm32")]
simple_layered_test_component_bindings::export!(Component with_types_in simple_layered_test_component_bindings);