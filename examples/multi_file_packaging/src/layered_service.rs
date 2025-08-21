//! OCI Image Layers Example
//! 
//! This example demonstrates accessing files from separate OCI image layers
//! at runtime using WASI filesystem interfaces. Files are not embedded in
//! the component but are available through the container runtime.

#[cfg(target_arch = "wasm32")]
use layered_service_component_bindings::exports::example::web_service::web_service::{
    Guest, RequestOptions, FormatType, ServiceConfig
};

struct Component;

#[cfg(target_arch = "wasm32")]
impl Component {
    /// Read configuration from mounted layer
    fn read_config() -> Result<MockConfig, String> {
        let config_path = std::env::var("CONFIG_PATH")
            .unwrap_or("/etc/service/config.json".to_string());
        
        match std::fs::read_to_string(&config_path) {
            Ok(_content) => {
                // In real implementation, would parse JSON content
                Ok(MockConfig::new())
            },
            Err(e) => Err(format!("Failed to read config from {}: {}", config_path, e))
        }
    }
    
    /// Read template from mounted layer
    fn read_template(template_name: &str) -> Result<String, String> {
        let templates_path = std::env::var("TEMPLATES_PATH")
            .unwrap_or("/etc/service/templates".to_string());
        
        let template_path = format!("{}/{}.html", templates_path, template_name);
        
        std::fs::read_to_string(&template_path)
            .map_err(|e| format!("Failed to read template {}: {}", template_path, e))
    }
    
    /// Read static asset from mounted layer
    fn read_asset(asset_name: &str) -> Result<Vec<u8>, String> {
        let assets_path = std::env::var("ASSETS_PATH")
            .unwrap_or("/var/www/static".to_string());
        
        let asset_path = format!("{}/{}", assets_path, asset_name);
        
        std::fs::read(&asset_path)
            .map_err(|e| format!("Failed to read asset {}: {}", asset_path, e))
    }
}

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process_request(input: String, options: RequestOptions) -> String {
        // Read configuration from layer
        let config = match Self::read_config() {
            Ok(config) => config,
            Err(e) => return format!("Configuration error: {}", e),
        };
        
        let timestamp = if options.include_timestamp {
            "2024-01-01 12:00:00 UTC".to_string()
        } else {
            "N/A".to_string()
        };
        
        match options.format {
            FormatType::Html => {
                // Read template from layer
                let template_name = options.template_name.unwrap_or("response".to_string());
                match Self::read_template(&template_name) {
                    Ok(template) => {
                        template
                            .replace("{{title}}", "Layered Service Response")
                            .replace("{{status}}", "Success")
                            .replace("{{data}}", &input)
                            .replace("{{timestamp}}", &timestamp)
                    },
                    Err(e) => format!("<html><body><h1>Template Error</h1><p>{}</p></body></html>", e),
                }
            },
            FormatType::Json => {
                format!(r#"{{
                    "status": "success",
                    "data": "{}",
                    "timestamp": "{}",
                    "environment": "{}",
                    "source": "layered-files"
                }}"#, 
                input, 
                timestamp,
                config.environment()
                )
            },
            FormatType::Text => {
                format!("Status: Success (Layered)\nData: {}\nTimestamp: {}", input, timestamp)
            }
        }
    }
    
    fn get_config() -> ServiceConfig {
        // Read configuration from mounted layer
        let config = match Self::read_config() {
            Ok(config) => config,
            Err(_) => {
                // Fallback configuration if layer not available
                return ServiceConfig {
                    environment: "unknown".to_string(),
                    max_connections: 100,
                    timeout_seconds: 30,
                    features: vec!["fallback".to_string()],
                };
            }
        };
        
        let features = vec!["layered".to_string(), "filesystem".to_string()];
        
        ServiceConfig {
            environment: config.environment().to_string(),
            max_connections: config.max_connections(),
            timeout_seconds: config.timeout_seconds(),
            features,
        }
    }
    
    fn validate_input(input: String) -> bool {
        // For layered approach, we could read schema from layer
        // but for simplicity, use basic validation
        !input.trim().is_empty()
    }
    
    fn render_template(template_name: String, data: String) -> String {
        match Self::read_template(&template_name) {
            Ok(template) => {
                template
                    .replace("{{title}}", "Custom Template")
                    .replace("{{status}}", "Rendered")
                    .replace("{{data}}", &data)
                    .replace("{{timestamp}}", "2024-01-01 12:00:00 UTC")
            },
            Err(e) => {
                format!("<html><body><h1>Template Error: {}</h1><p>Data: {}</p></body></html>", 
                       template_name, data)
            }
        }
    }
    
    fn health_check() -> String {
        // Check if layered files are accessible
        let config_available = Self::read_config().is_ok();
        let template_available = Self::read_template("response").is_ok();
        
        // List available assets
        let assets_path = std::env::var("ASSETS_PATH")
            .unwrap_or("/var/www/static".to_string());
        
        let available_assets = match std::fs::read_dir(&assets_path) {
            Ok(entries) => {
                entries
                    .filter_map(|entry| entry.ok())
                    .filter_map(|entry| entry.file_name().into_string().ok())
                    .collect::<Vec<String>>()
            },
            Err(_) => vec!["assets-layer-not-mounted".to_string()],
        };
        
        format!(r#"{{
            "status": "{}",
            "service": "layered-service",
            "layers": {{
                "config_available": {},
                "templates_available": {},
                "assets_available": {}
            }},
            "assets": {:?},
            "mount_points": {{
                "config": "{}",
                "templates": "{}",
                "assets": "{}"
            }}
        }}"#, 
        if config_available && template_available { "healthy" } else { "degraded" },
        config_available,
        template_available,
        !available_assets.is_empty(),
        available_assets,
        std::env::var("CONFIG_PATH").unwrap_or("/etc/service/config.json".to_string()),
        std::env::var("TEMPLATES_PATH").unwrap_or("/etc/service/templates".to_string()),
        assets_path
        )
    }
}

#[cfg(target_arch = "wasm32")]
layered_service_component_bindings::export!(Component with_types_in layered_service_component_bindings);

// Mock configuration struct to avoid external dependencies
struct MockConfig;

impl MockConfig {
    fn new() -> Self {
        MockConfig
    }
    
    fn environment(&self) -> &str {
        "layered"
    }
    
    fn max_connections(&self) -> u32 {
        500
    }
    
    fn timeout_seconds(&self) -> u32 {
        60
    }
}