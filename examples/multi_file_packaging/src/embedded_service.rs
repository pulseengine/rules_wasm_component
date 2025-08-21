//! Embedded Resources Example
//!
//! This example demonstrates packaging additional files directly into the
//! WebAssembly component using Rust's include_str! and include_bytes! macros.
//! All files are embedded at compile time and included in the component signature.

#[cfg(target_arch = "wasm32")]
use embedded_service_component_bindings::exports::example::web_service::web_service::{
    FormatType, Guest, RequestOptions, ServiceConfig,
};

// Embedded configuration (in real implementation, this would use include_str!)
const CONFIG_JSON: &str = r#"{"environment":"production","max_connections":1000,"timeout_seconds":30,"features":{"logging":true,"metrics":true,"tracing":false}}"#;

// Embedded HTML template
const RESPONSE_TEMPLATE: &str = r#"<html><head><title>{{title}}</title></head><body><h1>{{title}}</h1><p>Status: {{status}}</p><p>{{data}}</p><p>{{timestamp}}</p></body></html>"#;

// Embedded API schema
const API_SCHEMA: &str =
    r#"{"openapi":"3.0.0","info":{"title":"Web Service API","version":"1.0.0"}}"#;

struct Component;

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process_request(input: String, options: RequestOptions) -> String {
        // Parse embedded configuration (mock implementation)
        let config = MockConfig::new();

        let timestamp = if options.include_timestamp {
            "2024-01-01 12:00:00 UTC".to_string()
        } else {
            "N/A".to_string()
        };

        match options.format {
            FormatType::Html => {
                // Use embedded template
                let response = RESPONSE_TEMPLATE
                    .replace("{{title}}", "Embedded Service Response")
                    .replace("{{status}}", "Success")
                    .replace("{{data}}", &input)
                    .replace("{{timestamp}}", &timestamp);
                response
            }
            FormatType::Json => {
                format!(
                    r#"{{
                    "status": "success",
                    "data": "{}",
                    "timestamp": "{}",
                    "environment": "{}"
                }}"#,
                    input,
                    timestamp,
                    config.environment()
                )
            }
            FormatType::Text => {
                format!("Status: Success\nData: {}\nTimestamp: {}", input, timestamp)
            }
        }
    }

    fn get_config() -> ServiceConfig {
        // Parse embedded configuration (mock implementation)
        let config = MockConfig::new();

        let features = vec!["logging".to_string(), "metrics".to_string()];

        ServiceConfig {
            environment: config.environment().to_string(),
            max_connections: config.max_connections(),
            timeout_seconds: config.timeout_seconds(),
            features,
        }
    }

    fn validate_input(input: String) -> bool {
        // Simple validation without external dependencies
        if input.starts_with('{') && input.ends_with('}') {
            // Basic JSON validation - check for input field
            input.contains("\"input\"")
        } else {
            // Allow plain text input
            !input.trim().is_empty()
        }
    }

    fn render_template(template_name: String, data: String) -> String {
        match template_name.as_str() {
            "response" => RESPONSE_TEMPLATE
                .replace("{{title}}", "Custom Template")
                .replace("{{status}}", "Rendered")
                .replace("{{data}}", &data)
                .replace("{{timestamp}}", "2024-01-01 12:00:00 UTC"),
            _ => {
                format!(
                    "<html><body><h1>Unknown Template: {}</h1><p>{}</p></body></html>",
                    template_name, data
                )
            }
        }
    }

    fn health_check() -> String {
        let config = MockConfig::new();

        format!(
            r#"{{
            "status": "healthy",
            "service": "embedded-resource-service",
            "environment": "{}",
            "embedded_files": ["config/production.json", "templates/response.html", "schemas/api.json"],
            "uptime": "unknown"
        }}"#,
            config.environment()
        )
    }
}

#[cfg(target_arch = "wasm32")]
embedded_service_component_bindings::export!(Component with_types_in embedded_service_component_bindings);

// Mock configuration struct to avoid external dependencies
struct MockConfig;

impl MockConfig {
    fn new() -> Self {
        MockConfig
    }

    fn environment(&self) -> &str {
        "production"
    }

    fn max_connections(&self) -> u32 {
        1000
    }

    fn timeout_seconds(&self) -> u32 {
        30
    }
}
