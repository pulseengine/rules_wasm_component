//! Simple sidecar service test demonstrating coordination with external artifacts

#[cfg(target_arch = "wasm32")]
use simple_sidecar_test_component_bindings::exports::example::simple_test::service::Guest;

struct Component;

#[cfg(target_arch = "wasm32")]
impl Component {
    /// Check if sidecar endpoints are configured
    fn check_sidecar_status() -> SidecarStatus {
        SidecarStatus {
            config_available: std::env::var("CONFIG_SIDECAR_ENDPOINT").is_ok(),
            assets_available: std::env::var("ASSETS_SIDECAR_ENDPOINT").is_ok(),
            docs_available: std::env::var("DOCS_SIDECAR_ENDPOINT").is_ok(),
        }
    }
    
    /// Get configuration from sidecar (simulated)
    fn get_sidecar_config() -> String {
        if std::env::var("CONFIG_SIDECAR_ENDPOINT").is_ok() {
            // Simulated config from sidecar
            "production-sidecar-config".to_string()
        } else {
            // Fallback standalone config
            "standalone-config".to_string()
        }
    }
}

struct SidecarStatus {
    config_available: bool,
    assets_available: bool,
    docs_available: bool,
}

#[cfg(target_arch = "wasm32")]
impl Guest for Component {
    fn process(input: String) -> String {
        let status = Self::check_sidecar_status();
        let config = Self::get_sidecar_config();
        
        if status.config_available && status.assets_available {
            format!("Sidecar Service (full): {} | Config: {} | Sidecars: Config✓ Assets✓ Docs{}",
                   input,
                   config,
                   if status.docs_available { "✓" } else { "✗" })
        } else if status.config_available || status.assets_available {
            format!("Sidecar Service (partial): {} | Config: {} | Available: {}{}{}",
                   input,
                   config,
                   if status.config_available { "Config " } else { "" },
                   if status.assets_available { "Assets " } else { "" },
                   if status.docs_available { "Docs" } else { "" })
        } else {
            format!("Sidecar Service (standalone): {} | Config: {} | No sidecars detected",
                   input,
                   config)
        }
    }
}

#[cfg(target_arch = "wasm32")]
simple_sidecar_test_component_bindings::export!(Component with_types_in simple_sidecar_test_component_bindings);