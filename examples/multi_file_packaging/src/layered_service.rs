//! OCI Image Layers Example
//! 
//! This example demonstrates accessing files from separate OCI image layers
//! at runtime using WASI filesystem interfaces. Files are not embedded in
//! the component but are available through the container runtime.

#[cfg(target_arch = "wasm32")]
use web_service_component_bindings::Guest;

struct Component;

#[cfg(target_arch = "wasm32")]
impl Component {
    /// Read configuration from mounted layer
    fn read_config() -> Result<serde_json::Value, String> {
        let config_path = std::env::var("CONFIG_PATH")
            .unwrap_or("/etc/service/config.json".to_string());
        
        match std::fs::read_to_string(&config_path) {
            Ok(content) => {
                serde_json::from_str(&content)
                    .map_err(|e| format!("Invalid config JSON: {}", e))
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
    fn process_request(input: String, options: web_service_component_bindings::RequestOptions) -> String {
        // Read configuration from layer
        let config = match Self::read_config() {
            Ok(config) => config,
            Err(e) => return format!("Configuration error: {}", e),
        };
        
        let timestamp = if options.include_timestamp {
            format!("{}", chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"))
        } else {
            "N/A".to_string()
        };
        
        match options.format {
            web_service_component_bindings::FormatType::Html => {
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
            web_service_component_bindings::FormatType::Json => {
                format!(r#"{{
                    "status": "success",
                    "data": "{}",
                    "timestamp": "{}",
                    "environment": "{}",
                    "source": "layered-files"
                }}"#, 
                input, 
                timestamp,
                config["environment"].as_str().unwrap_or("unknown")
                )
            },
            web_service_component_bindings::FormatType::Text => {
                format!("Status: Success (Layered)\nData: {}\nTimestamp: {}", input, timestamp)
            }
        }
    }
    
    fn get_config() -> web_service_component_bindings::ServiceConfig {
        // Read configuration from mounted layer
        let config = match Self::read_config() {
            Ok(config) => config,
            Err(_) => {
                // Fallback configuration if layer not available
                return web_service_component_bindings::ServiceConfig {
                    environment: "unknown".to_string(),
                    max_connections: 100,
                    timeout_seconds: 30,
                    features: vec!["fallback".to_string()],
                };
            }
        };
        
        let features = config["features"].as_object()
            .map(|obj| obj.keys().cloned().collect())
            .unwrap_or_default();
        
        web_service_component_bindings::ServiceConfig {
            environment: config["environment"].as_str().unwrap_or("unknown").to_string(),
            max_connections: config["max_connections"].as_u64().unwrap_or(100) as u32,
            timeout_seconds: config["timeout_seconds"].as_u64().unwrap_or(30) as u32,
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
                    .replace("{{timestamp}}", &format!("{}", chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC")))
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