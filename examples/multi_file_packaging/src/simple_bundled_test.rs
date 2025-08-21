//! Simple bundled service test demonstrating bundle extraction approach

#[cfg(target_arch = "wasm32")]
use simple_bundled_test_component_bindings::exports::example::simple_test::service::Guest;

struct Component;

// Simulated bundle data (in real implementation would be include_bytes!)
const BUNDLE_CONFIG: &str = r#"{"environment":"bundled","connections":750}"#;
const BUNDLE_TEMPLATE: &str = r#"<html><body><h1>Bundle Template</h1><p>{{data}}</p></body></html>"#;
const BUNDLE_DOCS: &str = r#"# Bundle Documentation\nThis component includes bundled documentation files."#;

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process(input: String) -> String {
        // Simulate bundle extraction and processing
        let config_available = !BUNDLE_CONFIG.is_empty();
        let template_available = !BUNDLE_TEMPLATE.is_empty();
        let docs_available = !BUNDLE_DOCS.is_empty();
        
        // Process input using bundled resources
        let processed = if config_available && template_available {
            format!("Bundle Service: {} | Config: {} chars | Template: {} chars | Docs: {} chars",
                   input,
                   BUNDLE_CONFIG.len(),
                   BUNDLE_TEMPLATE.len(), 
                   BUNDLE_DOCS.len())
        } else {
            format!("Bundle Service (partial): {}", input)
        };
        
        processed
    }
}

#[cfg(target_arch = "wasm32")]
simple_bundled_test_component_bindings::export!(Component with_types_in simple_bundled_test_component_bindings);