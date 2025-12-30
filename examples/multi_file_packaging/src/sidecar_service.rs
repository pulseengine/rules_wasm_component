//! Sidecar Artifacts Example
//!
//! This example demonstrates a component designed to work with separate
//! sidecar artifacts that provide configuration, assets, and other files
//! through external coordination mechanisms.

#[cfg(target_arch = "wasm32")]
use sidecar_service_component_bindings::exports::example::web_service::web_service::{
    FormatType, Guest, RequestOptions, ServiceConfig,
};

struct Component;

#[cfg(target_arch = "wasm32")]
impl Component {
    /// Check if sidecar artifacts are available
    fn check_sidecar_availability() -> SidecarStatus {
        // In a real implementation, this would check:
        // - Service discovery endpoints
        // - Mounted volumes from sidecar containers
        // - Shared memory or message queues
        // - Environment variables indicating sidecar presence

        let config_endpoint = std::env::var("CONFIG_SIDECAR_ENDPOINT");
        let assets_endpoint = std::env::var("ASSETS_SIDECAR_ENDPOINT");

        SidecarStatus {
            config_available: config_endpoint.is_ok(),
            config_endpoint: config_endpoint.unwrap_or("not-configured".to_string()),
            assets_available: assets_endpoint.is_ok(),
            assets_endpoint: assets_endpoint.unwrap_or("not-configured".to_string()),
            documentation_available: std::env::var("DOCS_SIDECAR_ENDPOINT").is_ok(),
        }
    }

    /// Get configuration from config sidecar
    fn get_config_from_sidecar() -> Result<serde_json::Value, String> {
        let status = Self::check_sidecar_availability();

        if !status.config_available {
            return Ok(serde_json::json!({
                "environment": "standalone",
                "max_connections": 100,
                "timeout_seconds": 30,
                "features": {
                    "standalone_mode": true
                },
                "sidecar_mode": false
            }));
        }

        // In a real implementation, this would:
        // 1. Make HTTP request to config sidecar
        // 2. Read from shared volume
        // 3. Use inter-process communication

        // Simulated config from sidecar
        Ok(serde_json::json!({
            "environment": "production",
            "max_connections": 2000,
            "timeout_seconds": 60,
            "features": {
                "logging": true,
                "metrics": true,
                "distributed_config": true,
                "sidecar_coordination": true
            },
            "sidecar_mode": true,
            "config_source": "sidecar-artifact"
        }))
    }

    /// Get template from assets sidecar
    fn get_template_from_sidecar(template_name: &str) -> Result<String, String> {
        let status = Self::check_sidecar_availability();

        if !status.assets_available {
            return Ok(format!(
                "<html><body><h1>Standalone Mode</h1><p>Template: {}</p><p>{{{{data}}}}</p></body></html>",
                template_name
            ));
        }

        // In a real implementation, this would fetch from assets sidecar
        Ok(r#"<!DOCTYPE html>
<html>
<head>
    <title>{{title}}</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .sidecar-response { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 16px rgba(0,0,0,0.1); }
        .status { color: #28a745; font-weight: bold; font-size: 1.1em; }
        .sidecar-info { background: #e7f3ff; padding: 15px; border-radius: 8px; margin-top: 20px; border-left: 4px solid #007bff; }
    </style>
</head>
<body>
    <div class="sidecar-response">
        <h1>{{title}}</h1>
        <p class="status">Status: {{status}}</p>
        <p>Response: {{data}}</p>
        <p>Timestamp: {{timestamp}}</p>
        <div class="sidecar-info">
            <strong>Sidecar Architecture:</strong><br>
            ✅ Configuration from dedicated config sidecar<br>
            ✅ Templates from dedicated assets sidecar<br>
            ✅ Independent artifact lifecycle management<br>
            ✅ Team-based ownership and updates
        </div>
    </div>
</body>
</html>"#.to_string())
    }
}

/// Status of sidecar artifact availability
struct SidecarStatus {
    config_available: bool,
    config_endpoint: String,
    assets_available: bool,
    assets_endpoint: String,
    documentation_available: bool,
}

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process_request(
        input: String,
        options: RequestOptions,
    ) -> String {
        let config = Self::get_config_from_sidecar()
            .unwrap_or_else(|_| serde_json::json!({"environment": "error"}));

        let timestamp = if options.include_timestamp {
            format!("{}", chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"))
        } else {
            "N/A".to_string()
        };

        match options.format {
            FormatType::Html => {
                let template_name = options.template_name.unwrap_or("response".to_string());
                match Self::get_template_from_sidecar(&template_name) {
                    Ok(template) => template
                        .replace("{{title}}", "Sidecar Service Response")
                        .replace("{{status}}", "Success")
                        .replace("{{data}}", &input)
                        .replace("{{timestamp}}", &timestamp),
                    Err(e) => {
                        format!("<html><body><h1>Sidecar Error</h1><p>{}</p><p>Data: {}</p></body></html>", e, input)
                    }
                }
            }
            FormatType::Json => {
                let sidecar_status = Self::check_sidecar_availability();
                format!(
                    r#"{{
                    "status": "success",
                    "data": "{}",
                    "timestamp": "{}",
                    "environment": "{}",
                    "source": "sidecar-coordination",
                    "sidecars": {{
                        "config_available": {},
                        "assets_available": {},
                        "docs_available": {}
                    }}
                }}"#,
                    input,
                    timestamp,
                    config["environment"].as_str().unwrap_or("unknown"),
                    sidecar_status.config_available,
                    sidecar_status.assets_available,
                    sidecar_status.documentation_available
                )
            }
            FormatType::Text => {
                format!(
                    "Status: Success (Sidecar)\nData: {}\nTimestamp: {}\nSidecars Active: {}",
                    input,
                    timestamp,
                    if Self::check_sidecar_availability().config_available {
                        "Yes"
                    } else {
                        "No"
                    }
                )
            }
        }
    }

    fn get_config() -> ServiceConfig {
        let config = Self::get_config_from_sidecar().unwrap_or_else(|_| {
            serde_json::json!({
                "environment": "fallback",
                "max_connections": 50,
                "timeout_seconds": 15,
                "features": {"fallback": true}
            })
        });

        let features = config["features"]
            .as_object()
            .map(|obj| obj.keys().cloned().collect())
            .unwrap_or_else(|| vec!["standalone".to_string()]);

        ServiceConfig {
            environment: config["environment"]
                .as_str()
                .unwrap_or("unknown")
                .to_string(),
            max_connections: config["max_connections"].as_u64().unwrap_or(100) as u32,
            timeout_seconds: config["timeout_seconds"].as_u64().unwrap_or(30) as u32,
            features,
        }
    }

    fn validate_input(input: String) -> bool {
        // For sidecar approach, validation logic could come from config sidecar
        let config = Self::get_config_from_sidecar().unwrap_or_default();

        // Check if validation is enabled in sidecar config
        let validation_enabled = config["features"]["validation"].as_bool().unwrap_or(true);

        if !validation_enabled {
            return true;
        }

        // Basic validation
        !input.trim().is_empty() && input.len() <= 10000
    }

    fn render_template(template_name: String, data: String) -> String {
        match Self::get_template_from_sidecar(&template_name) {
            Ok(template) => template
                .replace("{{title}}", &format!("Sidecar Template: {}", template_name))
                .replace("{{status}}", "Rendered")
                .replace("{{data}}", &data)
                .replace(
                    "{{timestamp}}",
                    &format!("{}", chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC")),
                ),
            Err(e) => {
                format!("<html><body><h1>Sidecar Template Error</h1><p>Template: {}</p><p>Error: {}</p><p>Data: {}</p></body></html>",
                       template_name, e, data)
            }
        }
    }

    fn health_check() -> String {
        let sidecar_status = Self::check_sidecar_availability();
        let config = Self::get_config_from_sidecar().unwrap_or_default();

        format!(
            r#"{{
            "status": "{}",
            "service": "sidecar-service",
            "architecture": "sidecar-pattern",
            "sidecars": {{
                "configuration": {{
                    "available": {},
                    "endpoint": "{}",
                    "healthy": {}
                }},
                "assets": {{
                    "available": {},
                    "endpoint": "{}",
                    "healthy": {}
                }},
                "documentation": {{
                    "available": {},
                    "healthy": true
                }}
            }},
            "coordination": {{
                "service_discovery": "{}",
                "config_sync": {},
                "deployment_manifest": "sidecar_deployment.yaml"
            }},
            "environment": "{}"
        }}"#,
            if sidecar_status.config_available && sidecar_status.assets_available {
                "healthy"
            } else {
                "degraded"
            },
            sidecar_status.config_available,
            sidecar_status.config_endpoint,
            sidecar_status.config_available,
            sidecar_status.assets_available,
            sidecar_status.assets_endpoint,
            sidecar_status.assets_available,
            sidecar_status.documentation_available,
            std::env::var("SERVICE_DISCOVERY_MODE").unwrap_or("environment-variables".to_string()),
            config["sidecar_mode"].as_bool().unwrap_or(false),
            config["environment"].as_str().unwrap_or("unknown")
        )
    }
}

#[cfg(target_arch = "wasm32")]
sidecar_service_component_bindings::export!(Component with_types_in sidecar_service_component_bindings);

// Mock implementations for compilation without dependencies
#[cfg(not(target_arch = "wasm32"))]
mod serde_json {
    pub struct Value;
    impl Value {
        pub fn as_str(&self) -> Option<&str> {
            Some("mock")
        }
        pub fn as_u64(&self) -> Option<u64> {
            Some(100)
        }
        pub fn as_bool(&self) -> Option<bool> {
            Some(true)
        }
        pub fn as_object(&self) -> Option<&std::collections::HashMap<String, Value>> {
            None
        }
        pub fn get(&self, _key: &str) -> Option<&Value> {
            Some(self)
        }
    }
    impl Default for Value {
        fn default() -> Self {
            Value
        }
    }
    pub fn from_str<T>(_s: &str) -> Result<T, ()>
    where
        T: Default,
    {
        Ok(T::default())
    }
    #[macro_export]
    macro_rules! json {
        ($($tt:tt)*) => { $crate::serde_json::Value }
    }
    pub use json;
}

#[cfg(not(target_arch = "wasm32"))]
mod chrono {
    pub struct DateTime;
    impl DateTime {
        pub fn format(&self, _fmt: &str) -> String {
            "2024-01-01 12:00:00 UTC".to_string()
        }
    }
    pub struct Utc;
    impl Utc {
        pub fn now() -> DateTime {
            DateTime
        }
    }
}
