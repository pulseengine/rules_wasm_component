/*!
Runtime configuration for Wasmtime engine.

This module provides a builder pattern for configuring the Wasmtime engine
with production-ready settings, security policies, and performance optimizations.
*/

use crate::{
    WasmtimeError, WasmtimeResult, DEFAULT_EXECUTION_TIMEOUT, DEFAULT_INSTANTIATION_TIMEOUT,
};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use wasmtime::Config;

/// Runtime configuration for the Wasmtime engine
#[derive(Debug, Clone)]
pub struct RuntimeConfig {
    inner: Config,
    security_policy: SecurityPolicy,
    instantiation_timeout: Duration,
    execution_timeout: Duration,
}

/// Security policy for component execution
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityPolicy {
    /// Maximum memory size in bytes (default: 64MB)
    pub max_memory_size: u64,

    /// Maximum number of table elements (default: 10,000)
    pub max_table_elements: u32,

    /// Maximum number of instances (default: 100)
    pub max_instances: u32,

    /// Whether to allow network access (default: false)
    pub allow_network: bool,

    /// Whether to allow file system access (default: false)
    pub allow_filesystem: bool,

    /// Whether to allow environment variable access (default: true)
    pub allow_env_vars: bool,

    /// Maximum execution time per function call
    pub max_execution_time: Duration,
}

/// Builder for creating runtime configurations
pub struct RuntimeConfigBuilder {
    config: Config,
    security_policy: SecurityPolicy,
    instantiation_timeout: Duration,
    execution_timeout: Duration,
}

impl Default for SecurityPolicy {
    fn default() -> Self {
        Self {
            max_memory_size: 64 * 1024 * 1024, // 64MB
            max_table_elements: 10_000,
            max_instances: 100,
            allow_network: false,
            allow_filesystem: false,
            allow_env_vars: true,
            max_execution_time: Duration::from_secs(10),
        }
    }
}

impl SecurityPolicy {
    /// Create a permissive security policy for development
    pub fn development() -> Self {
        Self {
            allow_network: true,
            allow_filesystem: true,
            max_memory_size: 128 * 1024 * 1024, // 128MB
            max_execution_time: Duration::from_secs(30),
            ..Default::default()
        }
    }

    /// Create a restrictive security policy for production
    pub fn production() -> Self {
        Self {
            max_memory_size: 32 * 1024 * 1024, // 32MB
            max_table_elements: 1_000,
            max_instances: 10,
            max_execution_time: Duration::from_secs(5),
            allow_network: false,
            allow_filesystem: false,
            allow_env_vars: false,
        }
    }

    /// Create a sandbox security policy (most restrictive)
    pub fn sandbox() -> Self {
        Self {
            max_memory_size: 16 * 1024 * 1024, // 16MB
            max_table_elements: 100,
            max_instances: 1,
            max_execution_time: Duration::from_secs(1),
            allow_network: false,
            allow_filesystem: false,
            allow_env_vars: false,
        }
    }
}

impl RuntimeConfig {
    /// Create a new runtime configuration builder
    pub fn new() -> RuntimeConfigBuilder {
        RuntimeConfigBuilder::new()
    }

    /// Create a production-ready configuration
    pub fn production() -> RuntimeConfigBuilder {
        RuntimeConfigBuilder::new()
            .with_async_support(true)
            .with_wasi_preview2(true)
            .with_component_model(true)
            .with_cranelift_optimizations(true)
            .with_parallel_compilation(true)
            .with_security_policy(SecurityPolicy::production())
            .with_memory_protection(true)
    }

    /// Create a development configuration with more permissive settings
    pub fn development() -> RuntimeConfigBuilder {
        RuntimeConfigBuilder::new()
            .with_async_support(true)
            .with_wasi_preview2(true)
            .with_component_model(true)
            .with_debug_info(true)
            .with_security_policy(SecurityPolicy::development())
    }

    /// Create a sandbox configuration for untrusted code
    pub fn sandbox() -> RuntimeConfigBuilder {
        RuntimeConfigBuilder::new()
            .with_async_support(true)
            .with_wasi_preview2(true)
            .with_component_model(true)
            .with_security_policy(SecurityPolicy::sandbox())
            .with_memory_protection(true)
            .with_guard_pages(true)
    }

    /// Get the underlying Wasmtime configuration
    pub fn as_wasmtime_config(&self) -> &Config {
        &self.inner
    }

    /// Get the security policy
    pub fn security_policy(&self) -> &SecurityPolicy {
        &self.security_policy
    }

    /// Get the instantiation timeout
    pub fn instantiation_timeout(&self) -> Duration {
        self.instantiation_timeout
    }

    /// Get the execution timeout
    pub fn execution_timeout(&self) -> Duration {
        self.execution_timeout
    }
}

impl RuntimeConfigBuilder {
    /// Create a new builder with default settings
    pub fn new() -> Self {
        let mut config = Config::new();

        // Basic safe defaults
        config.wasm_component_model(true);
        config.async_support(false); // Will be enabled explicitly if needed

        Self {
            config,
            security_policy: SecurityPolicy::default(),
            instantiation_timeout: DEFAULT_INSTANTIATION_TIMEOUT,
            execution_timeout: DEFAULT_EXECUTION_TIMEOUT,
        }
    }

    /// Enable async support for the runtime
    pub fn with_async_support(mut self, enabled: bool) -> Self {
        self.config.async_support(enabled);
        self
    }

    /// Enable WASI Preview 2 support
    pub fn with_wasi_preview2(mut self, enabled: bool) -> Self {
        if enabled {
            // WASI Preview 2 requires component model
            self.config.wasm_component_model(true);
        }
        self
    }

    /// Enable WebAssembly component model
    pub fn with_component_model(mut self, enabled: bool) -> Self {
        self.config.wasm_component_model(enabled);
        self
    }

    /// Enable debug information preservation
    pub fn with_debug_info(mut self, enabled: bool) -> Self {
        self.config.debug_info(enabled);
        self
    }

    /// Enable Cranelift optimizations
    pub fn with_cranelift_optimizations(mut self, enabled: bool) -> Self {
        if enabled {
            self.config.cranelift_opt_level(wasmtime::OptLevel::Speed);
        } else {
            self.config.cranelift_opt_level(wasmtime::OptLevel::None);
        }
        self
    }

    /// Enable parallel compilation
    pub fn with_parallel_compilation(mut self, enabled: bool) -> Self {
        self.config.parallel_compilation(enabled);
        self
    }

    /// Enable memory protection (guards against bounds violations)
    pub fn with_memory_protection(mut self, enabled: bool) -> Self {
        if enabled {
            self.config.memory_init_cow(false); // Disable copy-on-write for security
            self.config.memory_guaranteed_dense_image_size(1024 * 1024); // 1MB
        }
        self
    }

    /// Enable guard pages for stack overflow protection
    pub fn with_guard_pages(mut self, enabled: bool) -> Self {
        if enabled {
            self.config.guard_before_linear_memory(true);
        }
        self
    }

    /// Set the security policy
    pub fn with_security_policy(mut self, policy: SecurityPolicy) -> Self {
        self.security_policy = policy;
        self
    }

    /// Set the instantiation timeout
    pub fn with_instantiation_timeout(mut self, timeout: Duration) -> Self {
        self.instantiation_timeout = timeout;
        self
    }

    /// Set the execution timeout
    pub fn with_execution_timeout(mut self, timeout: Duration) -> Self {
        self.execution_timeout = timeout;
        self
    }

    /// Set custom fuel consumption for execution limits
    pub fn with_fuel_consumption(mut self, enabled: bool) -> Self {
        self.config.consume_fuel(enabled);
        self
    }

    /// Set epoch interruption for preemptive scheduling
    pub fn with_epoch_interruption(mut self, enabled: bool) -> Self {
        self.config.epoch_interruption(enabled);
        self
    }

    /// Build the final runtime configuration
    pub fn build(self) -> WasmtimeResult<RuntimeConfig> {
        // Validate configuration
        self.validate()?;

        Ok(RuntimeConfig {
            inner: self.config,
            security_policy: self.security_policy,
            instantiation_timeout: self.instantiation_timeout,
            execution_timeout: self.execution_timeout,
        })
    }

    /// Validate the configuration for common issues
    fn validate(&self) -> WasmtimeResult<()> {
        // Check for reasonable timeout values
        if self.instantiation_timeout > Duration::from_secs(300) {
            return Err(WasmtimeError::ConfigError(
                "Instantiation timeout too large (max 5 minutes)".to_string(),
            ));
        }

        if self.execution_timeout > Duration::from_secs(3600) {
            return Err(WasmtimeError::ConfigError(
                "Execution timeout too large (max 1 hour)".to_string(),
            ));
        }

        // Check for reasonable memory limits
        if self.security_policy.max_memory_size > 1024 * 1024 * 1024 {
            return Err(WasmtimeError::ConfigError(
                "Memory limit too large (max 1GB)".to_string(),
            ));
        }

        Ok(())
    }
}

impl Default for RuntimeConfigBuilder {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_security_policy() {
        let policy = SecurityPolicy::default();
        assert_eq!(policy.max_memory_size, 64 * 1024 * 1024);
        assert_eq!(policy.max_table_elements, 10_000);
        assert!(!policy.allow_network);
        assert!(!policy.allow_filesystem);
        assert!(policy.allow_env_vars);
    }

    #[test]
    fn test_production_security_policy() {
        let policy = SecurityPolicy::production();
        assert_eq!(policy.max_memory_size, 32 * 1024 * 1024);
        assert!(!policy.allow_network);
        assert!(!policy.allow_filesystem);
        assert!(!policy.allow_env_vars);
    }

    #[test]
    fn test_development_security_policy() {
        let policy = SecurityPolicy::development();
        assert_eq!(policy.max_memory_size, 128 * 1024 * 1024);
        assert!(policy.allow_network);
        assert!(policy.allow_filesystem);
        assert!(policy.allow_env_vars);
    }

    #[test]
    fn test_basic_config_build() {
        let config = RuntimeConfig::new().build();
        assert!(config.is_ok());
    }

    #[test]
    fn test_production_config_build() {
        let config = RuntimeConfig::production().build();
        assert!(config.is_ok());
    }

    #[test]
    fn test_config_validation_timeout() {
        let result = RuntimeConfig::new()
            .with_instantiation_timeout(Duration::from_secs(400))
            .build();
        assert!(result.is_err());
    }

    #[test]
    fn test_config_validation_memory() {
        let policy = SecurityPolicy {
            max_memory_size: 2 * 1024 * 1024 * 1024, // 2GB
            ..Default::default()
        };

        let result = RuntimeConfig::new().with_security_policy(policy).build();
        assert!(result.is_err());
    }
}
