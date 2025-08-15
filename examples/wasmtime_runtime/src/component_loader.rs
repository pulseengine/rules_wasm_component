/*!
Component loading and management for Wasmtime runtime.

This module provides high-level abstractions for loading, instantiating, and
managing WebAssembly components with Wasmtime.
*/

use crate::{
    metrics::{ComponentMetrics, ExecutionMetrics},
    runtime_config::RuntimeConfig,
    WasmtimeError, WasmtimeResult,
};
use anyhow::{Context, Result};
use serde_json::Value;
use std::{
    collections::HashMap,
    path::Path,
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::time::timeout;
use tracing::{info, instrument, warn};
use wasmtime::{
    component::{Component, Instance, Linker},
    Config, Engine, Store,
};
use wasmtime_wasi::{WasiCtx, WasiCtxBuilder, WasiView};

/// Component loader for managing WebAssembly component lifecycle
pub struct ComponentLoader {
    engine: Engine,
    linker: Linker<WasiCtx>,
    config: RuntimeConfig,
    metrics: Arc<ComponentMetrics>,
}

/// A loaded WebAssembly component with its metadata
pub struct LoadedComponent {
    component: Component,
    metadata: ComponentMetadata,
    loader: Arc<ComponentLoader>,
}

/// Runtime instance of a component
pub struct ComponentInstance {
    instance: Instance,
    store: Store<WasiCtx>,
    metadata: ComponentMetadata,
    metrics: Arc<ComponentMetrics>,
}

/// Metadata about a loaded component
#[derive(Debug, Clone)]
pub struct ComponentMetadata {
    pub name: String,
    pub size_bytes: usize,
    pub load_time: Duration,
    pub exports: Vec<String>,
    pub imports: Vec<String>,
}

/// Host data structure for WASI integration
struct HostData {
    wasi_ctx: WasiCtx,
}

impl WasiView for HostData {
    fn ctx(&self) -> &WasiCtx {
        &self.wasi_ctx
    }
    fn ctx_mut(&mut self) -> &mut WasiCtx {
        &mut self.wasi_ctx
    }
}

impl ComponentLoader {
    /// Create a new component loader with the given configuration
    pub fn new(config: RuntimeConfig) -> WasmtimeResult<Self> {
        let engine = Engine::new(config.as_wasmtime_config())
            .map_err(|e| WasmtimeError::ConfigError(e.to_string()))?;

        let mut linker = Linker::new(&engine);

        // Add WASI Preview 2 support
        wasmtime_wasi::add_to_linker_sync(&mut linker)
            .map_err(|e| WasmtimeError::ConfigError(format!("WASI linker setup failed: {}", e)))?;

        let metrics = Arc::new(ComponentMetrics::new());

        Ok(Self {
            engine,
            linker,
            config,
            metrics,
        })
    }

    /// Load a component from a file path
    #[instrument(skip(self), fields(path = %path.as_ref().display()))]
    pub async fn load_component<P: AsRef<Path>>(&self, path: P) -> WasmtimeResult<LoadedComponent> {
        let start_time = Instant::now();
        let path = path.as_ref();

        info!("Loading component from {}", path.display());

        // Read component bytes
        let component_bytes = tokio::fs::read(path).await.map_err(|e| {
            WasmtimeError::ComponentLoadError(format!("Failed to read file: {}", e))
        })?;

        // Load component with timeout
        let component = timeout(
            self.config.instantiation_timeout(),
            self.load_component_from_bytes(&component_bytes, path.to_string_lossy().to_string()),
        )
        .await
        .map_err(|_| WasmtimeError::TimeoutError {
            duration: self.config.instantiation_timeout(),
        })?
        .map_err(|e| WasmtimeError::ComponentLoadError(e.to_string()))?;

        let load_time = start_time.elapsed();

        // Extract component metadata
        let metadata = self.extract_metadata(&component, component_bytes.len(), load_time)?;

        self.metrics.record_component_loaded(&metadata);

        info!(
            "Successfully loaded component '{}' ({} bytes) in {:?}",
            metadata.name, metadata.size_bytes, metadata.load_time
        );

        Ok(LoadedComponent {
            component,
            metadata,
            loader: Arc::new(ComponentLoader {
                engine: self.engine.clone(),
                linker: self.linker.clone(),
                config: self.config.clone(),
                metrics: self.metrics.clone(),
            }),
        })
    }

    /// Load component from byte array
    async fn load_component_from_bytes(&self, bytes: &[u8], name: String) -> Result<Component> {
        // Spawn blocking task for CPU-intensive parsing
        let engine = self.engine.clone();
        let bytes = bytes.to_vec();

        tokio::task::spawn_blocking(move || Component::from_binary(&engine, &bytes))
            .await?
            .context("Failed to parse component binary")
    }

    /// Extract metadata from a loaded component
    fn extract_metadata(
        &self,
        component: &Component,
        size_bytes: usize,
        load_time: Duration,
    ) -> WasmtimeResult<ComponentMetadata> {
        // For now, we'll use simplified metadata extraction
        // In a real implementation, you'd introspect the component's WIT interface
        let exports = vec!["add".to_string(), "subtract".to_string()]; // Placeholder
        let imports = vec!["wasi:cli/environment".to_string()]; // Placeholder

        Ok(ComponentMetadata {
            name: "component".to_string(), // Could extract from component name section
            size_bytes,
            load_time,
            exports,
            imports,
        })
    }

    /// Get metrics for loaded components
    pub fn metrics(&self) -> Arc<ComponentMetrics> {
        self.metrics.clone()
    }
}

impl LoadedComponent {
    /// Instantiate the component
    #[instrument(skip(self))]
    pub async fn instantiate(&self) -> WasmtimeResult<ComponentInstance> {
        let start_time = Instant::now();

        info!("Instantiating component '{}'", self.metadata.name);

        // Create WASI context
        let wasi_ctx = WasiCtxBuilder::new().inherit_stdio().inherit_env().build();

        let host_data = HostData { wasi_ctx };
        let mut store = Store::new(&self.loader.engine, host_data);

        // Set resource limits
        store.limiter(|_| {
            wasmtime::ResourceLimiter::new()
                .memory_size(64 * 1024 * 1024) // 64MB memory limit
                .table_elements(10_000) // Table elements limit
                .instances(100) // Instance limit
        });

        // Instantiate with timeout
        let instance = timeout(
            self.loader.config.instantiation_timeout(),
            self.loader
                .linker
                .instantiate_async(&mut store, &self.component),
        )
        .await
        .map_err(|_| WasmtimeError::TimeoutError {
            duration: self.loader.config.instantiation_timeout(),
        })?
        .map_err(|e| WasmtimeError::ComponentLoadError(format!("Instantiation failed: {}", e)))?;

        let instantiation_time = start_time.elapsed();

        self.loader
            .metrics
            .record_component_instantiated(&self.metadata, instantiation_time);

        info!(
            "Successfully instantiated component '{}' in {:?}",
            self.metadata.name, instantiation_time
        );

        Ok(ComponentInstance {
            instance,
            store,
            metadata: self.metadata.clone(),
            metrics: self.loader.metrics.clone(),
        })
    }

    /// Get component metadata
    pub fn metadata(&self) -> &ComponentMetadata {
        &self.metadata
    }
}

impl ComponentInstance {
    /// Call a function on the component
    #[instrument(skip(self, args), fields(function = %function_name))]
    pub async fn call_function(
        &mut self,
        function_name: &str,
        args: &[Value],
    ) -> WasmtimeResult<Value> {
        let start_time = Instant::now();

        info!(
            "Calling function '{}' on component '{}'",
            function_name, self.metadata.name
        );

        // This is a simplified implementation
        // In practice, you'd need to:
        // 1. Look up the exported function by name
        // 2. Convert JSON args to Wasmtime values
        // 3. Call the function
        // 4. Convert result back to JSON

        // For demonstration, we'll simulate function execution
        tokio::time::sleep(Duration::from_millis(10)).await;

        let execution_time = start_time.elapsed();
        let result = Value::Number(42.into()); // Placeholder result

        self.metrics.record_function_called(
            &self.metadata.name,
            function_name,
            execution_time,
            true, // success
        );

        info!(
            "Function '{}' completed in {:?}",
            function_name, execution_time
        );

        Ok(result)
    }

    /// Get execution metrics for this instance
    pub fn execution_metrics(&self) -> ExecutionMetrics {
        self.metrics.get_execution_metrics(&self.metadata.name)
    }

    /// Get component metadata
    pub fn metadata(&self) -> &ComponentMetadata {
        &self.metadata
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::runtime_config::RuntimeConfig;

    #[tokio::test]
    async fn test_component_loader_creation() {
        let config = RuntimeConfig::new().build().unwrap();
        let loader = ComponentLoader::new(config);
        assert!(loader.is_ok());
    }

    #[test]
    fn test_component_metadata() {
        let metadata = ComponentMetadata {
            name: "test".to_string(),
            size_bytes: 1024,
            load_time: Duration::from_millis(100),
            exports: vec!["test_function".to_string()],
            imports: vec!["wasi:cli/environment".to_string()],
        };

        assert_eq!(metadata.name, "test");
        assert_eq!(metadata.size_bytes, 1024);
        assert_eq!(metadata.exports.len(), 1);
        assert_eq!(metadata.imports.len(), 1);
    }
}
