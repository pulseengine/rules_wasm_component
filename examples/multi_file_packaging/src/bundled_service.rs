//! Bundle Archive Example
//! 
//! This example demonstrates extracting and using files from a pre-packaged
//! archive that contains the component plus additional files. The bundle
//! is extracted at runtime to access the files.

#[cfg(target_arch = "wasm32")]
use web_service_component_bindings::Guest;

struct Component;

// In a real implementation, the bundle would be embedded as bytes
// const BUNDLE_DATA: &[u8] = include_bytes!("../service_bundle.tar");

#[cfg(target_arch = "wasm32")]
impl Component {
    /// Extract and cache bundle contents (simplified simulation)
    fn extract_bundle() -> Result<BundleContents, String> {
        // In a real implementation, this would:
        // 1. Read the embedded bundle data
        // 2. Extract using tar or zip library
        // 3. Parse configuration and templates
        // 4. Cache results for performance
        
        // Simulated bundle contents
        Ok(BundleContents {
            config: r#"{
                "environment": "production",
                "max_connections": 1000,
                "timeout_seconds": 30,
                "features": {
                    "logging": true,
                    "metrics": true,
                    "documentation": true
                }
            }"#.to_string(),
            
            template: r#"<!DOCTYPE html>
<html>
<head>
    <title>{{title}}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .response { background: #f0f0f0; padding: 20px; border-radius: 8px; }
        .status { color: green; font-weight: bold; }
        .bundle-info { color: #666; font-size: 0.9em; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="response">
        <h1>{{title}}</h1>
        <p class="status">Status: {{status}}</p>
        <p>Response: {{data}}</p>
        <p>Timestamp: {{timestamp}}</p>
        <div class="bundle-info">
            Source: Bundle Archive<br>
            Bundle includes: Configuration, Templates, Documentation, API Schema
        </div>
    </div>
</body>
</html>"#.to_string(),
            
            documentation: vec![
                ("README.md".to_string(), "# Web Service Component\n\nThis is a bundled component...".to_string()),
                ("API.md".to_string(), "# API Documentation\n\n## Endpoints...".to_string()),
                ("DEPLOYMENT.md".to_string(), "# Deployment Guide\n\n## Prerequisites...".to_string()),
            ],
            
            schema: r#"{
                "openapi": "3.0.0",
                "info": {
                    "title": "Bundled Web Service API",
                    "version": "1.0.0"
                }
            }"#.to_string(),
        })
    }
    
    /// Get cached bundle contents (with lazy initialization)
    fn get_bundle() -> &'static BundleContents {
        // In a real implementation, this would use std::sync::Once for thread-safe initialization
        // For simplicity, we'll simulate cached access
        static mut BUNDLE: Option<BundleContents> = None;
        
        unsafe {
            if BUNDLE.is_none() {
                BUNDLE = Some(Self::extract_bundle().unwrap_or_else(|_| BundleContents::default()));
            }
            BUNDLE.as_ref().unwrap()
        }
    }
}

/// Represents extracted bundle contents
#[derive(Clone)]
struct BundleContents {
    config: String,
    template: String,
    documentation: Vec<(String, String)>,
    schema: String,
}

impl Default for BundleContents {
    fn default() -> Self {
        Self {
            config: r#"{"environment": "fallback"}"#.to_string(),
            template: "<html><body>Fallback template</body></html>".to_string(),
            documentation: vec![],
            schema: "{}".to_string(),
        }
    }
}

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process_request(input: String, options: web_service_component_bindings::RequestOptions) -> String {
        let bundle = Self::get_bundle();
        
        // Parse configuration from bundle
        let config: serde_json::Value = serde_json::from_str(&bundle.config)
            .unwrap_or_else(|_| serde_json::json!({"environment": "unknown"}));
        
        let timestamp = if options.include_timestamp {
            format!("{}", chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"))
        } else {
            "N/A".to_string()
        };
        
        match options.format {
            web_service_component_bindings::FormatType::Html => {
                // Use template from bundle
                bundle.template
                    .replace("{{title}}", "Bundled Service Response")
                    .replace("{{status}}", "Success")
                    .replace("{{data}}", &input)
                    .replace("{{timestamp}}", &timestamp)
            },
            web_service_component_bindings::FormatType::Json => {
                format!(r#"{{
                    "status": "success",
                    "data": "{}",
                    "timestamp": "{}",
                    "environment": "{}",
                    "source": "bundle-archive",
                    "bundle_files": {}
                }}"#, 
                input, 
                timestamp,
                config["environment"].as_str().unwrap_or("unknown"),
                bundle.documentation.len()
                )
            },
            web_service_component_bindings::FormatType::Text => {
                format!("Status: Success (Bundle)\nData: {}\nTimestamp: {}\nBundle Files: {}", 
                       input, timestamp, bundle.documentation.len())
            }
        }
    }
    
    fn get_config() -> web_service_component_bindings::ServiceConfig {
        let bundle = Self::get_bundle();
        
        // Parse configuration from bundle
        let config: serde_json::Value = serde_json::from_str(&bundle.config)
            .unwrap_or_else(|_| serde_json::json!({
                "environment": "unknown",
                "max_connections": 100,
                "timeout_seconds": 30,
                "features": {}
            }));
        
        let features = config["features"].as_object()
            .map(|obj| obj.keys().cloned().collect())
            .unwrap_or_else(|| vec!["fallback".to_string()]);
        
        web_service_component_bindings::ServiceConfig {
            environment: config["environment"].as_str().unwrap_or("unknown").to_string(),
            max_connections: config["max_connections"].as_u64().unwrap_or(100) as u32,
            timeout_seconds: config["timeout_seconds"].as_u64().unwrap_or(30) as u32,
            features,
        }
    }
    
    fn validate_input(input: String) -> bool {
        let bundle = Self::get_bundle();
        
        // Validate against schema from bundle
        let schema: serde_json::Value = serde_json::from_str(&bundle.schema)
            .unwrap_or_else(|_| serde_json::json!({}));
        
        // Simple validation - check if input is valid JSON or non-empty text
        if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&input) {
            // Could validate against OpenAPI schema here
            parsed.get("input").is_some()
        } else {
            !input.trim().is_empty()
        }
    }
    
    fn render_template(template_name: String, data: String) -> String {
        let bundle = Self::get_bundle();
        
        // For bundle approach, we could support multiple templates
        // For simplicity, use the main template with customization
        let template = match template_name.as_str() {
            "response" => &bundle.template,
            _ => "<html><body><h1>Custom Template: {{title}}</h1><p>{{data}}</p></body></html>",
        };
        
        template
            .replace("{{title}}", &format!("Template: {}", template_name))
            .replace("{{status}}", "Rendered")
            .replace("{{data}}", &data)
            .replace("{{timestamp}}", &format!("{}", chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC")))
    }
    
    fn health_check() -> String {
        let bundle = Self::get_bundle();
        
        // List available documentation files
        let doc_files: Vec<&String> = bundle.documentation.iter().map(|(name, _)| name).collect();
        
        format!(r#"{{
            "status": "healthy",
            "service": "bundled-service",
            "bundle": {{
                "extracted": true,
                "config_loaded": {},
                "template_loaded": {},
                "documentation_files": {:?},
                "schema_loaded": {}
            }},
            "bundle_size": "estimated_5mb",
            "extraction_time": "runtime"
        }}"#, 
        !bundle.config.is_empty(),
        !bundle.template.is_empty(),
        doc_files,
        !bundle.schema.is_empty()
        )
    }
}

#[cfg(target_arch = "wasm32")]
web_service_component_bindings::export!(Component with_types_in web_service_component_bindings);

// Mock implementations for compilation without dependencies
#[cfg(not(target_arch = "wasm32"))]
mod serde_json {
    pub struct Value;
    impl Value {
        pub fn as_str(&self) -> Option<&str> { Some("mock") }
        pub fn as_u64(&self) -> Option<u64> { Some(100) }
        pub fn as_object(&self) -> Option<&std::collections::HashMap<String, Value>> { None }
        pub fn get(&self, _key: &str) -> Option<&Value> { Some(self) }
    }
    pub fn from_str<T>(_s: &str) -> Result<T, ()> where T: Default { Ok(T::default()) }
    pub fn json(_val: serde_json::Value) -> serde_json::Value { serde_json::Value }
}

#[cfg(not(target_arch = "wasm32"))]
mod chrono {
    pub struct DateTime;
    impl DateTime {
        pub fn format(&self, _fmt: &str) -> String { "2024-01-01 12:00:00 UTC".to_string() }
    }
    pub struct Utc;
    impl Utc {
        pub fn now() -> DateTime { DateTime }
    }
}