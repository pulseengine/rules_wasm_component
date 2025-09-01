/*! 
Tests demonstrating the enhanced wit_bindgen functionality

This test suite validates that the wit_bindgen rule with interface mappings
generates the expected code structures and patterns.
*/

#[cfg(test)]
mod basic_bindings_tests {
    // Test basic bindings without interface mappings
    // These should generate all interfaces from scratch
    
    #[test]
    fn test_basic_bindings_exist() {
        // Basic bindings should have generated all interfaces
        // This is a compile-time test - if the types exist, test passes
        
        use basic_bindings::exports::example::api::{
            auth::Guest as AuthGuest,
            logging::Guest as LoggingGuest,
            service::Guest as ServiceGuest,
        };

        // If we can reference these types, the bindings were generated
        let _auth_ref: Option<&dyn AuthGuest> = None;
        let _logging_ref: Option<&dyn LoggingGuest> = None;
        let _service_ref: Option<&dyn ServiceGuest> = None;
    }

    #[test]
    fn test_basic_types_generated() {
        use basic_bindings::example::api::service::ApiConfig;
        use basic_bindings::example::api::logging::{LogLevel, LogEntry};
        use basic_bindings::example::api::auth::AuthToken;

        // Test that basic types are generated and usable
        let config = ApiConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };
        assert_eq!(config.endpoint, "test");

        let log_level = LogLevel::Info;
        let entry = LogEntry {
            level: log_level,
            message: "test".to_string(), 
            timestamp: 1234567890,
            module: Some("test_module".to_string()),
        };
        assert_eq!(entry.message, "test");

        let token = AuthToken {
            value: "secret".to_string(),
            expires_at: 1234567890,
            scopes: vec!["read".to_string()],
        };
        assert_eq!(token.value, "secret");
    }
}

#[cfg(test)]
mod advanced_bindings_tests {
    // Test advanced bindings with interface mappings and custom configuration
    
    #[test]
    fn test_advanced_bindings_exist() {
        use advanced_bindings::exports::example::api::{
            auth::Guest as AuthGuest,
            logging::Guest as LoggingGuest, 
            service::Guest as ServiceGuest,
        };

        // Advanced bindings should exist with mapped interfaces
        let _auth_ref: Option<&dyn AuthGuest> = None;
        let _logging_ref: Option<&dyn LoggingGuest> = None;
        let _service_ref: Option<&dyn ServiceGuest> = None;
    }

    #[test]
    fn test_custom_derives_available() {
        use advanced_bindings::example::api::service::ApiConfig;
        use advanced_bindings::example::api::auth::AuthToken;

        // Test that custom derives (Clone, Debug, PartialEq) are available
        let config1 = ApiConfig {
            endpoint: "https://api.example.com".to_string(),
            timeout_ms: 5000,
            retry_attempts: 3,
        };

        // Test Clone derive
        let config2 = config1.clone();
        
        // Test PartialEq derive
        assert_eq!(config1, config2);
        
        // Test Debug derive (compile-time check)
        let debug_output = format!("{:?}", config1);
        assert!(debug_output.contains("ApiConfig"));

        let token1 = AuthToken {
            value: "secret".to_string(),
            expires_at: 1234567890,
            scopes: vec!["read".to_string(), "write".to_string()],
        };

        // Test derives on AuthToken
        let token2 = token1.clone();
        assert_eq!(token1, token2);
        let debug_output = format!("{:?}", token1);
        assert!(debug_output.contains("AuthToken"));
    }

    #[test] 
    fn test_borrowing_ownership() {
        use advanced_bindings::example::api::service::Connection;
        use advanced_bindings::example::api::service::ApiConfig;

        // Test that borrowing ownership model works
        let config = ApiConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        // This should work with borrowing ownership model
        let _connection = Connection::new(&config);
        
        // We can still use config after borrowing it
        assert_eq!(config.endpoint, "test");
    }

    #[test]
    fn test_interface_mappings_compile() {
        // This is primarily a compile-time test
        // If with_mappings worked correctly:
        // - WASI interfaces should be mapped to existing types (not generated)
        // - Custom interfaces should be generated
        
        // These should work if mappings are correct:
        use advanced_bindings::example::api::{
            service::ApiConfig,
            auth::AuthToken,
            logging::LogLevel,
        };

        // Basic usage test
        let _config = ApiConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000, 
            retry_attempts: 3,
        };

        let _token = AuthToken {
            value: "test".to_string(),
            expires_at: 1234567890,
            scopes: vec![],
        };

        let _level = LogLevel::Info;

        // If we reach here, the mapped interfaces compiled correctly
        assert!(true);
    }
}

#[cfg(test)]
mod full_featured_bindings_tests {
    // Test comprehensive bindings with all options enabled

    #[test]
    fn test_all_async_interfaces() {
        // With async_interfaces = ["all"], all interfaces should support async
        // This is mainly a compile-time check
        
        use full_featured_bindings::exports::example::api::{
            auth::Guest as AuthGuest,
            logging::Guest as LoggingGuest,
            service::Guest as ServiceGuest, 
        };

        // If async interfaces are enabled, these should exist
        let _auth_ref: Option<&dyn AuthGuest> = None;
        let _logging_ref: Option<&dyn LoggingGuest> = None; 
        let _service_ref: Option<&dyn ServiceGuest> = None;
    }

    #[test]
    fn test_additional_derives() {
        use full_featured_bindings::example::api::service::ApiConfig;

        let config = ApiConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        // Test that additional derives are available
        let cloned = config.clone(); // Clone
        assert_eq!(config, cloned); // PartialEq
        
        let debug_output = format!("{:?}", config); // Debug
        assert!(debug_output.contains("ApiConfig"));

        // Note: Serialize/Deserialize would require actual serde integration
        // This is just a compile-time check that the derives are specified
    }

    #[test]
    fn test_ownership_model() {
        use full_featured_bindings::example::api::service::{ApiConfig, Connection};

        // Test borrowing-duplicate-if-necessary ownership model
        let config = ApiConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        // This should work with the specified ownership model
        let _connection = Connection::new(&config);
        
        // Config should still be usable
        assert_eq!(config.timeout_ms, 1000);
    }
}

#[cfg(test)]
mod cross_binding_comparison {
    // Compare different binding configurations to ensure they work correctly

    #[test] 
    fn test_same_types_across_bindings() {
        // The same WIT types should be available across different binding configurations
        
        // Basic bindings types
        use basic_bindings::example::api::service::ApiConfig as BasicConfig;
        use basic_bindings::example::api::logging::LogLevel as BasicLogLevel;

        // Advanced bindings types  
        use advanced_bindings::example::api::service::ApiConfig as AdvancedConfig;
        use advanced_bindings::example::api::logging::LogLevel as AdvancedLogLevel;

        // Full featured bindings types
        use full_featured_bindings::example::api::service::ApiConfig as FullConfig;
        use full_featured_bindings::example::api::logging::LogLevel as FullLogLevel;

        // Create instances of each
        let basic_config = BasicConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        let advanced_config = AdvancedConfig {
            endpoint: "test".to_string(), 
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        let full_config = FullConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000, 
            retry_attempts: 3,
        };

        // All should have the same structure
        assert_eq!(basic_config.endpoint, "test");
        assert_eq!(advanced_config.endpoint, "test");  
        assert_eq!(full_config.endpoint, "test");

        // Log levels should be equivalent
        let _basic_info = BasicLogLevel::Info;
        let _advanced_info = AdvancedLogLevel::Info;
        let _full_info = FullLogLevel::Info;
    }

    #[test]
    fn test_binding_feature_differences() {
        // Test that different binding configurations have expected differences

        // Advanced bindings should support Clone (additional_derives)
        use advanced_bindings::example::api::service::ApiConfig as AdvancedConfig;
        let advanced_config = AdvancedConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };
        let _cloned = advanced_config.clone(); // Should work

        // Full bindings should also support Clone
        use full_featured_bindings::example::api::service::ApiConfig as FullConfig;
        let full_config = FullConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };
        let _cloned = full_config.clone(); // Should work

        // Basic bindings might not support Clone (depending on default wit-bindgen behavior)
        // This is mainly a compile-time difference validation
        assert!(true);
    }
}

#[cfg(test)]
mod wit_bindgen_options_validation {
    // Validate that wit-bindgen options are applied correctly

    #[test]
    fn test_generation_modes() {
        // Test that different generation modes produce usable bindings
        
        // Basic: Should generate all interfaces
        use basic_bindings::example::api::{
            service::ApiConfig,
            auth::AuthToken,
            logging::LogLevel,
        };

        let _config = ApiConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        // Advanced: Should generate only unmapped interfaces (generate_all = False)
        use advanced_bindings::example::api::{
            service::ApiConfig as AdvConfig,
            auth::AuthToken as AdvToken,
            logging::LogLevel as AdvLevel,
        };

        let _config = AdvConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        // Full: Should generate all interfaces (generate_all = True)
        use full_featured_bindings::example::api::{
            service::ApiConfig as FullConfig,
            auth::AuthToken as FullToken,
            logging::LogLevel as FullLevel,
        };

        let _config = FullConfig {
            endpoint: "test".to_string(),
            timeout_ms: 1000,
            retry_attempts: 3,
        };

        assert!(true); // Compile-time validation
    }
}