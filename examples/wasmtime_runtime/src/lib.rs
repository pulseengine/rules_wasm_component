/*!
# Wasmtime Runtime Integration

Enhanced utilities for running and testing WebAssembly components with Wasmtime.

## Features

- **Component Loading**: Simplified component instantiation and management
- **Host Functions**: Custom host-provided functionality for components
- **Metrics**: Performance monitoring and measurement
- **Runtime Configuration**: Flexible Wasmtime engine configuration
- **Error Handling**: Comprehensive error types and handling
- **Async Support**: Tokio-based async runtime integration

## Quick Start

```rust
use wasmtime_runtime::{ComponentLoader, RuntimeConfig, Metrics};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Create runtime with optimized configuration
    let config = RuntimeConfig::production();
    let loader = ComponentLoader::new(config)?;

    // Load and run a component
    let component = loader.load_component("calculator.wasm").await?;
    let result = component.call_function("add", &[1.0, 2.0]).await?;

    println!("Result: {}", result);
    Ok(())
}
```

## Architecture

This library provides a high-level abstraction over Wasmtime's component model
APIs, making it easy to:

- Load and instantiate WebAssembly components
- Provide host functions to components
- Monitor component performance and resource usage
- Orchestrate multiple components
- Handle errors gracefully

## Performance

All operations are designed for production use with:
- Minimal overhead component loading
- Efficient memory management
- Async-first design for concurrency
- Built-in metrics and monitoring
*/

pub mod component_loader;
pub mod host_functions;
pub mod metrics;
pub mod runtime_config;

pub use component_loader::{ComponentLoader, ComponentInstance, LoadedComponent};
pub use host_functions::{HostFunction, HostFunctionRegistry};
pub use metrics::{ComponentMetrics, ExecutionMetrics, Metrics};
pub use runtime_config::{RuntimeConfig, SecurityPolicy};

use anyhow::{Context, Result};
use std::time::Duration;

/// Version information for the wasmtime runtime integration
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Default timeouts for component operations
pub const DEFAULT_INSTANTIATION_TIMEOUT: Duration = Duration::from_secs(30);
pub const DEFAULT_EXECUTION_TIMEOUT: Duration = Duration::from_secs(10);

/// Common error types for wasmtime operations
#[derive(Debug, thiserror::Error)]
pub enum WasmtimeError {
    #[error("Component loading failed: {0}")]
    ComponentLoadError(String),

    #[error("Function execution failed: {0}")]
    ExecutionError(String),

    #[error("Timeout occurred after {duration:?}")]
    TimeoutError { duration: Duration },

    #[error("Security policy violation: {0}")]
    SecurityError(String),

    #[error("Resource limit exceeded: {0}")]
    ResourceError(String),

    #[error("Configuration error: {0}")]
    ConfigError(String),
}

/// Result type alias for wasmtime operations
pub type WasmtimeResult<T> = Result<T, WasmtimeError>;

/// Initialize tracing for wasmtime operations
pub fn init_tracing() -> Result<()> {
    use tracing_subscriber::{fmt, EnvFilter};

    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("wasmtime_runtime=info"));

    fmt()
        .with_env_filter(filter)
        .with_target(false)
        .with_thread_ids(true)
        .with_line_number(true)
        .init();

    Ok(())
}

/// Utility function to create a basic runtime configuration
pub fn create_basic_config() -> Result<RuntimeConfig> {
    RuntimeConfig::new()
        .with_async_support(true)
        .with_wasi_preview2(true)
        .with_component_model(true)
        .build()
        .context("Failed to create basic runtime configuration")
}

/// Utility function to create a production-ready runtime configuration
pub fn create_production_config() -> Result<RuntimeConfig> {
    RuntimeConfig::production()
        .build()
        .context("Failed to create production runtime configuration")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_config_creation() {
        let config = create_basic_config();
        assert!(config.is_ok());
    }

    #[test]
    fn test_production_config_creation() {
        let config = create_production_config();
        assert!(config.is_ok());
    }

    #[test]
    fn test_version_constant() {
        assert!(!VERSION.is_empty());
    }
}
