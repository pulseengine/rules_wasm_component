/*!
Host function registry for providing custom functionality to WebAssembly components.

This module allows you to register host functions that components can import and call,
enabling bidirectional communication between the host and WebAssembly components.
*/

use anyhow::{Context, Result};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, instrument};

/// Function signature for host functions callable from components
pub type HostFunctionCallback = Arc<dyn Fn(&[Value]) -> Result<Value> + Send + Sync>;

/// Async function signature for host functions
pub type AsyncHostFunctionCallback = Arc<
    dyn Fn(&[Value]) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Value>> + Send>>
        + Send
        + Sync,
>;

/// A host function that can be called from WebAssembly components
#[derive(Clone)]
pub struct HostFunction {
    name: String,
    description: String,
    callback: HostFunctionCallback,
    parameter_types: Vec<String>,
    return_type: String,
}

/// Registry for managing host functions
pub struct HostFunctionRegistry {
    functions: Arc<RwLock<HashMap<String, HostFunction>>>,
    async_functions: Arc<RwLock<HashMap<String, AsyncHostFunctionCallback>>>,
}

impl HostFunction {
    /// Create a new host function
    pub fn new<F>(
        name: impl Into<String>,
        description: impl Into<String>,
        parameter_types: Vec<String>,
        return_type: impl Into<String>,
        callback: F,
    ) -> Self
    where
        F: Fn(&[Value]) -> Result<Value> + Send + Sync + 'static,
    {
        Self {
            name: name.into(),
            description: description.into(),
            callback: Arc::new(callback),
            parameter_types,
            return_type: return_type.into(),
        }
    }

    /// Get the function name
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Get the function description
    pub fn description(&self) -> &str {
        &self.description
    }

    /// Get parameter types
    pub fn parameter_types(&self) -> &[String] {
        &self.parameter_types
    }

    /// Get return type
    pub fn return_type(&self) -> &str {
        &self.return_type
    }

    /// Call the host function
    #[instrument(skip(self, args), fields(function = %self.name))]
    pub fn call(&self, args: &[Value]) -> Result<Value> {
        info!(
            "Calling host function '{}' with {} arguments",
            self.name,
            args.len()
        );

        // Validate argument count
        if args.len() != self.parameter_types.len() {
            anyhow::bail!(
                "Function '{}' expects {} arguments, got {}",
                self.name,
                self.parameter_types.len(),
                args.len()
            );
        }

        // Call the function
        (self.callback)(args)
            .with_context(|| format!("Failed to execute host function '{}'", self.name))
    }
}

impl HostFunctionRegistry {
    /// Create a new host function registry
    pub fn new() -> Self {
        Self {
            functions: Arc::new(RwLock::new(HashMap::new())),
            async_functions: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Register a host function
    pub async fn register_function(&self, function: HostFunction) -> Result<()> {
        let mut functions = self.functions.write().await;
        let name = function.name().to_string();

        info!(
            "Registering host function '{}': {}",
            name,
            function.description()
        );

        functions.insert(name, function);
        Ok(())
    }

    /// Register an async host function
    pub async fn register_async_function<F, Fut>(
        &self,
        name: impl Into<String>,
        callback: F,
    ) -> Result<()>
    where
        F: Fn(&[Value]) -> Fut + Send + Sync + 'static,
        Fut: std::future::Future<Output = Result<Value>> + Send + 'static,
    {
        let name = name.into();
        info!("Registering async host function '{}'", name);

        let wrapped_callback = Arc::new(move |args: &[Value]| {
            let args = args.to_vec();
            Box::pin(callback(&args))
                as std::pin::Pin<Box<dyn std::future::Future<Output = Result<Value>> + Send>>
        });

        let mut async_functions = self.async_functions.write().await;
        async_functions.insert(name, wrapped_callback);
        Ok(())
    }

    /// Call a registered host function
    pub async fn call_function(&self, name: &str, args: &[Value]) -> Result<Value> {
        let functions = self.functions.read().await;

        if let Some(function) = functions.get(name) {
            function.call(args)
        } else {
            anyhow::bail!("Host function '{}' not found", name);
        }
    }

    /// Call a registered async host function
    pub async fn call_async_function(&self, name: &str, args: &[Value]) -> Result<Value> {
        let async_functions = self.async_functions.read().await;

        if let Some(function) = async_functions.get(name) {
            function(args).await
        } else {
            anyhow::bail!("Async host function '{}' not found", name);
        }
    }

    /// List all registered functions
    pub async fn list_functions(&self) -> Vec<String> {
        let functions = self.functions.read().await;
        let async_functions = self.async_functions.read().await;

        let mut names: Vec<String> = functions.keys().cloned().collect();
        names.extend(async_functions.keys().cloned());
        names.sort();
        names
    }

    /// Get function metadata
    pub async fn get_function_info(&self, name: &str) -> Option<(String, Vec<String>, String)> {
        let functions = self.functions.read().await;

        functions.get(name).map(|f| {
            (
                f.description().to_string(),
                f.parameter_types().to_vec(),
                f.return_type().to_string(),
            )
        })
    }

    /// Remove a function from the registry
    pub async fn unregister_function(&self, name: &str) -> Result<()> {
        let mut functions = self.functions.write().await;
        let mut async_functions = self.async_functions.write().await;

        let removed_sync = functions.remove(name).is_some();
        let removed_async = async_functions.remove(name).is_some();

        if removed_sync || removed_async {
            info!("Unregistered host function '{}'", name);
            Ok(())
        } else {
            anyhow::bail!("Host function '{}' not found", name);
        }
    }

    /// Clear all registered functions
    pub async fn clear(&self) {
        let mut functions = self.functions.write().await;
        let mut async_functions = self.async_functions.write().await;

        functions.clear();
        async_functions.clear();

        info!("Cleared all host functions");
    }
}

impl Default for HostFunctionRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// Create a set of common utility host functions
pub fn create_common_host_functions() -> Vec<HostFunction> {
    vec![
        // Math functions
        HostFunction::new(
            "math_pow",
            "Calculate power of a number",
            vec!["number".to_string(), "number".to_string()],
            "number",
            |args| {
                let base = args[0].as_f64().unwrap_or(0.0);
                let exp = args[1].as_f64().unwrap_or(0.0);
                Ok(Value::Number(
                    serde_json::Number::from_f64(base.powf(exp)).unwrap(),
                ))
            },
        ),
        HostFunction::new(
            "math_sqrt",
            "Calculate square root",
            vec!["number".to_string()],
            "number",
            |args| {
                let value = args[0].as_f64().unwrap_or(0.0);
                Ok(Value::Number(
                    serde_json::Number::from_f64(value.sqrt()).unwrap(),
                ))
            },
        ),
        // String functions
        HostFunction::new(
            "string_length",
            "Get string length",
            vec!["string".to_string()],
            "number",
            |args| {
                let s = args[0].as_str().unwrap_or("");
                Ok(Value::Number(serde_json::Number::from(s.len())))
            },
        ),
        HostFunction::new(
            "string_upper",
            "Convert string to uppercase",
            vec!["string".to_string()],
            "string",
            |args| {
                let s = args[0].as_str().unwrap_or("");
                Ok(Value::String(s.to_uppercase()))
            },
        ),
        // Array functions
        HostFunction::new(
            "array_sum",
            "Sum array of numbers",
            vec!["array".to_string()],
            "number",
            |args| {
                let arr = args[0].as_array().unwrap_or(&vec![]);
                let sum: f64 = arr.iter().filter_map(|v| v.as_f64()).sum();
                Ok(Value::Number(serde_json::Number::from_f64(sum).unwrap()))
            },
        ),
        // Utility functions
        HostFunction::new(
            "current_timestamp",
            "Get current Unix timestamp",
            vec![],
            "number",
            |_args| {
                use std::time::{SystemTime, UNIX_EPOCH};
                let timestamp = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_secs();
                Ok(Value::Number(serde_json::Number::from(timestamp)))
            },
        ),
        HostFunction::new(
            "random_number",
            "Generate random number between 0 and 1",
            vec![],
            "number",
            |_args| {
                use std::collections::hash_map::DefaultHasher;
                use std::hash::{Hash, Hasher};

                // Simple pseudo-random number generator
                let mut hasher = DefaultHasher::new();
                std::time::SystemTime::now().hash(&mut hasher);
                let random = (hasher.finish() % 1000) as f64 / 1000.0;

                Ok(Value::Number(serde_json::Number::from_f64(random).unwrap()))
            },
        ),
        // Logging function
        HostFunction::new(
            "host_log",
            "Log message from component",
            vec!["string".to_string()],
            "null",
            |args| {
                let message = args[0].as_str().unwrap_or("");
                println!("[COMPONENT LOG] {}", message);
                Ok(Value::Null)
            },
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tokio_test;

    #[test]
    fn test_host_function_creation() {
        let func = HostFunction::new(
            "test_func",
            "A test function",
            vec!["number".to_string()],
            "number",
            |args| Ok(args[0].clone()),
        );

        assert_eq!(func.name(), "test_func");
        assert_eq!(func.description(), "A test function");
        assert_eq!(func.parameter_types().len(), 1);
        assert_eq!(func.return_type(), "number");
    }

    #[test]
    fn test_host_function_call() {
        let func = HostFunction::new(
            "double",
            "Double a number",
            vec!["number".to_string()],
            "number",
            |args| {
                let value = args[0].as_f64().unwrap_or(0.0);
                Ok(json!(value * 2.0))
            },
        );

        let result = func.call(&[json!(5.0)]).unwrap();
        assert_eq!(result, json!(10.0));
    }

    #[tokio::test]
    async fn test_host_function_registry() {
        let registry = HostFunctionRegistry::new();

        let func = HostFunction::new(
            "test",
            "Test function",
            vec!["number".to_string()],
            "number",
            |args| Ok(args[0].clone()),
        );

        registry.register_function(func).await.unwrap();

        let result = registry.call_function("test", &[json!(42)]).await.unwrap();
        assert_eq!(result, json!(42));

        let functions = registry.list_functions().await;
        assert_eq!(functions, vec!["test"]);
    }

    #[tokio::test]
    async fn test_async_host_function() {
        let registry = HostFunctionRegistry::new();

        registry
            .register_async_function("async_test", |args| async move {
                tokio::time::sleep(std::time::Duration::from_millis(1)).await;
                Ok(json!(args[0].as_f64().unwrap_or(0.0) * 2.0))
            })
            .await
            .unwrap();

        let result = registry
            .call_async_function("async_test", &[json!(21)])
            .await
            .unwrap();
        assert_eq!(result, json!(42.0));
    }

    #[test]
    fn test_common_host_functions() {
        let functions = create_common_host_functions();
        assert!(!functions.is_empty());

        // Test math_pow function
        let pow_func = functions.iter().find(|f| f.name() == "math_pow").unwrap();
        let result = pow_func.call(&[json!(2.0), json!(3.0)]).unwrap();
        assert_eq!(result, json!(8.0));

        // Test string_length function
        let len_func = functions
            .iter()
            .find(|f| f.name() == "string_length")
            .unwrap();
        let result = len_func.call(&[json!("hello")]).unwrap();
        assert_eq!(result, json!(5));
    }

    #[tokio::test]
    async fn test_function_unregister() {
        let registry = HostFunctionRegistry::new();

        let func = HostFunction::new("temp", "Temporary function", vec![], "null", |_| {
            Ok(json!(null))
        });

        registry.register_function(func).await.unwrap();
        assert_eq!(registry.list_functions().await.len(), 1);

        registry.unregister_function("temp").await.unwrap();
        assert_eq!(registry.list_functions().await.len(), 0);
    }
}
