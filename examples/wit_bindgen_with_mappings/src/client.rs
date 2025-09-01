/*! 
Example client demonstrating wit-bindgen with interface mappings

This example shows how the enhanced wit_bindgen rule with with_mappings
enables sophisticated interface mapping patterns:

- Map WASI interfaces to existing crates (wasi::http::types)
- Generate only custom interfaces ("generate")
- Use ownership models (borrowing) 
- Add custom derives (Clone, Debug, PartialEq)
- Enable async interfaces for better ergonomics
*/

use anyhow::Result;

// Use the generated bindings with interface mappings
use advanced_bindings::exports::example::api::{
    auth::Guest as AuthGuest,
    logging::Guest as LoggingGuest, 
    service::Guest as ServiceGuest,
};

// Import the mapped types - these should resolve to existing crates
// instead of generated code thanks to with_mappings
use advanced_bindings::{
    example::api::{
        auth::{AuthToken, Session},
        logging::{LogEntry, LogLevel},
        service::{ApiConfig, Connection},
    },
    // These should map to existing wasi crate types via with_mappings:
    // "wasi:http/types": "wasi::http::types",
    // "wasi:io/poll": "wasi::io::poll", 
    // "wasi:filesystem/types": "wasi::filesystem::types",
};

/// Example API client using mapped interfaces
pub struct ApiClient {
    config: ApiConfig,
    connection: Option<Connection>,
}

impl ApiClient {
    pub fn new(endpoint: String, timeout_ms: u32) -> Self {
        let config = ApiConfig {
            endpoint,
            timeout_ms,
            retry_attempts: 3,
        };

        Self {
            config,
            connection: None,
        }
    }

    /// Connect using the resource from generated bindings
    pub fn connect(&mut self) -> Result<()> {
        // The Connection::new should be available thanks to wit-bindgen generation
        // with borrowing ownership model and custom derives (Clone, Debug, PartialEq)
        let connection = Connection::new(&self.config);
        self.connection = Some(connection);
        Ok(())
    }

    /// Example of using async interface (enabled via async_interfaces)
    pub async fn process_async(&self, input: &str) -> Result<String> {
        if let Some(ref connection) = self.connection {
            // This should be async thanks to async_interfaces = ["example:api/service#async-process"]
            match connection.async_process(input).await {
                Ok(result) => Ok(result),
                Err(e) => Err(anyhow::anyhow!("Processing failed: {}", e)),
            }
        } else {
            Err(anyhow::anyhow!("Not connected"))
        }
    }

    /// Example sync method
    pub fn send_request(&self, data: &[u8]) -> Result<Vec<u8>> {
        if let Some(ref connection) = self.connection {
            match connection.send_request(data) {
                Ok(response) => Ok(response),
                Err(e) => Err(anyhow::anyhow!("Request failed: {}", e)),
            }
        } else {
            Err(anyhow::anyhow!("Not connected"))
        }
    }
}

/// Example logging client using generated interface
pub struct LoggingClient;

impl LoggingClient {
    pub fn log_info(&self, message: &str, module: Option<&str>) {
        let entry = LogEntry {
            level: LogLevel::Info,
            message: message.to_string(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            module: module.map(|s| s.to_string()),
        };

        // This calls the generated log function
        advanced_bindings::example::api::logging::log(&entry);
    }

    pub fn set_debug_level(&self) {
        advanced_bindings::example::api::logging::set_level(&LogLevel::Debug);
    }
}

/// Example auth client demonstrating resource usage with custom derives
pub struct AuthClient {
    session: Option<Session>,
}

impl AuthClient {
    pub fn new() -> Self {
        Self { session: None }
    }

    pub fn login_with_token(&mut self, token: AuthToken) -> Result<()> {
        // AuthToken should have Clone, Debug, PartialEq derives thanks to additional_derives
        let cloned_token = token.clone();
        println!("Logging in with token: {:?}", cloned_token);
        
        // Create session resource
        let session = Session::new(&token);
        self.session = Some(session);
        Ok(())
    }

    pub fn validate_session(&self) -> Result<bool> {
        if let Some(ref session) = self.session {
            match session.validate() {
                Ok(valid) => Ok(valid),
                Err(e) => Err(anyhow::anyhow!("Validation failed: {}", e)),
            }
        } else {
            Ok(false)
        }
    }

    pub async fn load_credentials_from_file(&self, path: &str) -> Result<AuthToken> {
        // This function uses filesystem interface, which should be mapped via with_mappings
        // "wasi:filesystem/types": "wasi::filesystem::types"
        match advanced_bindings::example::api::auth::load_credentials(path) {
            Ok(token) => Ok(token),
            Err(e) => Err(anyhow::anyhow!("Failed to load credentials: {}", e)),
        }
    }
}

/// Example demonstrating that types have the expected derives
pub fn demonstrate_custom_derives() {
    let config1 = ApiConfig {
        endpoint: "https://api.example.com".to_string(),
        timeout_ms: 5000,
        retry_attempts: 3,
    };

    let config2 = config1.clone(); // Clone derive working
    
    println!("Config: {:?}", config1); // Debug derive working
    println!("Configs equal: {}", config1 == config2); // PartialEq derive working

    let token1 = AuthToken {
        value: "secret".to_string(),
        expires_at: 1234567890,
        scopes: vec!["read".to_string(), "write".to_string()],
    };

    let token2 = token1.clone(); // Clone derive working
    println!("Token: {:?}", token1); // Debug derive working  
    println!("Tokens equal: {}", token1 == token2); // PartialEq derive working
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_api_client_creation() {
        let client = ApiClient::new("https://test.example.com".to_string(), 1000);
        assert_eq!(client.config.endpoint, "https://test.example.com");
        assert_eq!(client.config.timeout_ms, 1000);
        assert_eq!(client.config.retry_attempts, 3);
    }

    #[test] 
    fn test_custom_derives() {
        // Test that custom derives are working
        demonstrate_custom_derives();
    }

    #[tokio::test]
    async fn test_async_interface() {
        let mut client = ApiClient::new("https://test.example.com".to_string(), 1000);
        client.connect().unwrap();
        
        // This should work thanks to async_interfaces configuration
        let result = client.process_async("test input").await;
        // Result depends on actual implementation, but interface should be async
    }
}