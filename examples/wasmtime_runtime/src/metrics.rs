/*!
Metrics collection and monitoring for Wasmtime runtime operations.

This module provides comprehensive metrics for monitoring component loading,
instantiation, execution, and resource usage.
*/

use crate::component_loader::ComponentMetadata;
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

/// Metrics collector for component operations
#[derive(Debug)]
pub struct ComponentMetrics {
    inner: Arc<Mutex<MetricsInner>>,
}

/// Thread-safe inner metrics data
#[derive(Debug)]
struct MetricsInner {
    components_loaded: u64,
    components_instantiated: u64,
    functions_called: u64,
    total_load_time: Duration,
    total_instantiation_time: Duration,
    total_execution_time: Duration,
    component_stats: HashMap<String, ComponentStats>,
    function_stats: HashMap<String, FunctionStats>,
}

/// Statistics for a specific component
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComponentStats {
    pub name: String,
    pub size_bytes: usize,
    pub load_count: u64,
    pub instantiation_count: u64,
    pub total_load_time: Duration,
    pub total_instantiation_time: Duration,
    pub average_load_time: Duration,
    pub average_instantiation_time: Duration,
    pub last_used: Instant,
}

/// Statistics for function calls
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionStats {
    pub function_name: String,
    pub component_name: String,
    pub call_count: u64,
    pub success_count: u64,
    pub failure_count: u64,
    pub total_execution_time: Duration,
    pub average_execution_time: Duration,
    pub min_execution_time: Duration,
    pub max_execution_time: Duration,
    pub last_called: Instant,
}

/// Execution metrics for a component instance
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionMetrics {
    pub component_name: String,
    pub total_calls: u64,
    pub successful_calls: u64,
    pub failed_calls: u64,
    pub total_execution_time: Duration,
    pub average_execution_time: Duration,
    pub functions: HashMap<String, FunctionStats>,
}

/// Overall metrics summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsSummary {
    pub total_components_loaded: u64,
    pub total_components_instantiated: u64,
    pub total_functions_called: u64,
    pub total_load_time: Duration,
    pub total_instantiation_time: Duration,
    pub total_execution_time: Duration,
    pub average_load_time: Duration,
    pub average_instantiation_time: Duration,
    pub average_execution_time: Duration,
    pub active_components: usize,
    pub uptime: Duration,
    pub start_time: Instant,
}

/// Public metrics trait for easy mocking in tests
pub trait Metrics {
    fn record_component_loaded(&self, metadata: &ComponentMetadata);
    fn record_component_instantiated(&self, metadata: &ComponentMetadata, duration: Duration);
    fn record_function_called(
        &self,
        component_name: &str,
        function_name: &str,
        duration: Duration,
        success: bool,
    );
    fn get_summary(&self) -> MetricsSummary;
    fn get_component_stats(&self, component_name: &str) -> Option<ComponentStats>;
    fn get_function_stats(
        &self,
        component_name: &str,
        function_name: &str,
    ) -> Option<FunctionStats>;
}

impl ComponentMetrics {
    /// Create a new metrics collector
    pub fn new() -> Self {
        Self {
            inner: Arc::new(Mutex::new(MetricsInner {
                components_loaded: 0,
                components_instantiated: 0,
                functions_called: 0,
                total_load_time: Duration::ZERO,
                total_instantiation_time: Duration::ZERO,
                total_execution_time: Duration::ZERO,
                component_stats: HashMap::new(),
                function_stats: HashMap::new(),
            })),
        }
    }

    /// Get execution metrics for a specific component
    pub fn get_execution_metrics(&self, component_name: &str) -> ExecutionMetrics {
        let inner = self.inner.lock().unwrap();

        let component_functions: HashMap<String, FunctionStats> = inner
            .function_stats
            .iter()
            .filter(|(_, stats)| stats.component_name == component_name)
            .map(|(key, stats)| (stats.function_name.clone(), stats.clone()))
            .collect();

        let total_calls = component_functions.values().map(|s| s.call_count).sum();
        let successful_calls = component_functions.values().map(|s| s.success_count).sum();
        let failed_calls = component_functions.values().map(|s| s.failure_count).sum();
        let total_execution_time = component_functions
            .values()
            .map(|s| s.total_execution_time)
            .fold(Duration::ZERO, |acc, d| acc + d);

        let average_execution_time = if total_calls > 0 {
            total_execution_time / total_calls as u32
        } else {
            Duration::ZERO
        };

        ExecutionMetrics {
            component_name: component_name.to_string(),
            total_calls,
            successful_calls,
            failed_calls,
            total_execution_time,
            average_execution_time,
            functions: component_functions,
        }
    }

    /// Export metrics to JSON format
    pub fn export_json(&self) -> serde_json::Result<String> {
        let summary = self.get_summary();
        serde_json::to_string_pretty(&summary)
    }

    /// Clear all metrics (useful for testing)
    pub fn clear(&self) {
        let mut inner = self.inner.lock().unwrap();
        *inner = MetricsInner {
            components_loaded: 0,
            components_instantiated: 0,
            functions_called: 0,
            total_load_time: Duration::ZERO,
            total_instantiation_time: Duration::ZERO,
            total_execution_time: Duration::ZERO,
            component_stats: HashMap::new(),
            function_stats: HashMap::new(),
        };
    }
}

impl Metrics for ComponentMetrics {
    fn record_component_loaded(&self, metadata: &ComponentMetadata) {
        let mut inner = self.inner.lock().unwrap();

        inner.components_loaded += 1;
        inner.total_load_time += metadata.load_time;

        let stats = inner
            .component_stats
            .entry(metadata.name.clone())
            .or_insert_with(|| ComponentStats {
                name: metadata.name.clone(),
                size_bytes: metadata.size_bytes,
                load_count: 0,
                instantiation_count: 0,
                total_load_time: Duration::ZERO,
                total_instantiation_time: Duration::ZERO,
                average_load_time: Duration::ZERO,
                average_instantiation_time: Duration::ZERO,
                last_used: Instant::now(),
            });

        stats.load_count += 1;
        stats.total_load_time += metadata.load_time;
        stats.average_load_time = stats.total_load_time / stats.load_count as u32;
        stats.last_used = Instant::now();
    }

    fn record_component_instantiated(&self, metadata: &ComponentMetadata, duration: Duration) {
        let mut inner = self.inner.lock().unwrap();

        inner.components_instantiated += 1;
        inner.total_instantiation_time += duration;

        if let Some(stats) = inner.component_stats.get_mut(&metadata.name) {
            stats.instantiation_count += 1;
            stats.total_instantiation_time += duration;
            stats.average_instantiation_time =
                stats.total_instantiation_time / stats.instantiation_count as u32;
            stats.last_used = Instant::now();
        }
    }

    fn record_function_called(
        &self,
        component_name: &str,
        function_name: &str,
        duration: Duration,
        success: bool,
    ) {
        let mut inner = self.inner.lock().unwrap();

        inner.functions_called += 1;
        inner.total_execution_time += duration;

        let key = format!("{}::{}", component_name, function_name);
        let stats = inner
            .function_stats
            .entry(key)
            .or_insert_with(|| FunctionStats {
                function_name: function_name.to_string(),
                component_name: component_name.to_string(),
                call_count: 0,
                success_count: 0,
                failure_count: 0,
                total_execution_time: Duration::ZERO,
                average_execution_time: Duration::ZERO,
                min_execution_time: Duration::from_secs(u64::MAX),
                max_execution_time: Duration::ZERO,
                last_called: Instant::now(),
            });

        stats.call_count += 1;
        if success {
            stats.success_count += 1;
        } else {
            stats.failure_count += 1;
        }

        stats.total_execution_time += duration;
        stats.average_execution_time = stats.total_execution_time / stats.call_count as u32;

        if duration < stats.min_execution_time {
            stats.min_execution_time = duration;
        }
        if duration > stats.max_execution_time {
            stats.max_execution_time = duration;
        }

        stats.last_called = Instant::now();
    }

    fn get_summary(&self) -> MetricsSummary {
        let inner = self.inner.lock().unwrap();

        let average_load_time = if inner.components_loaded > 0 {
            inner.total_load_time / inner.components_loaded as u32
        } else {
            Duration::ZERO
        };

        let average_instantiation_time = if inner.components_instantiated > 0 {
            inner.total_instantiation_time / inner.components_instantiated as u32
        } else {
            Duration::ZERO
        };

        let average_execution_time = if inner.functions_called > 0 {
            inner.total_execution_time / inner.functions_called as u32
        } else {
            Duration::ZERO
        };

        let start_time = Instant::now() - Duration::from_secs(60); // Placeholder

        MetricsSummary {
            total_components_loaded: inner.components_loaded,
            total_components_instantiated: inner.components_instantiated,
            total_functions_called: inner.functions_called,
            total_load_time: inner.total_load_time,
            total_instantiation_time: inner.total_instantiation_time,
            total_execution_time: inner.total_execution_time,
            average_load_time,
            average_instantiation_time,
            average_execution_time,
            active_components: inner.component_stats.len(),
            uptime: Instant::now() - start_time,
            start_time,
        }
    }

    fn get_component_stats(&self, component_name: &str) -> Option<ComponentStats> {
        let inner = self.inner.lock().unwrap();
        inner.component_stats.get(component_name).cloned()
    }

    fn get_function_stats(
        &self,
        component_name: &str,
        function_name: &str,
    ) -> Option<FunctionStats> {
        let inner = self.inner.lock().unwrap();
        let key = format!("{}::{}", component_name, function_name);
        inner.function_stats.get(&key).cloned()
    }
}

impl Default for ComponentMetrics {
    fn default() -> Self {
        Self::new()
    }
}

impl Clone for ComponentMetrics {
    fn clone(&self) -> Self {
        Self {
            inner: self.inner.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::component_loader::ComponentMetadata;

    #[test]
    fn test_metrics_creation() {
        let metrics = ComponentMetrics::new();
        let summary = metrics.get_summary();
        assert_eq!(summary.total_components_loaded, 0);
        assert_eq!(summary.total_functions_called, 0);
    }

    #[test]
    fn test_component_loaded_metrics() {
        let metrics = ComponentMetrics::new();
        let metadata = ComponentMetadata {
            name: "test_component".to_string(),
            size_bytes: 1024,
            load_time: Duration::from_millis(100),
            exports: vec![],
            imports: vec![],
        };

        metrics.record_component_loaded(&metadata);

        let summary = metrics.get_summary();
        assert_eq!(summary.total_components_loaded, 1);
        assert_eq!(summary.total_load_time, Duration::from_millis(100));

        let stats = metrics.get_component_stats("test_component").unwrap();
        assert_eq!(stats.load_count, 1);
        assert_eq!(stats.size_bytes, 1024);
    }

    #[test]
    fn test_function_call_metrics() {
        let metrics = ComponentMetrics::new();

        metrics.record_function_called(
            "test_component",
            "test_function",
            Duration::from_millis(50),
            true,
        );

        let summary = metrics.get_summary();
        assert_eq!(summary.total_functions_called, 1);
        assert_eq!(summary.total_execution_time, Duration::from_millis(50));

        let stats = metrics
            .get_function_stats("test_component", "test_function")
            .unwrap();
        assert_eq!(stats.call_count, 1);
        assert_eq!(stats.success_count, 1);
        assert_eq!(stats.failure_count, 0);
    }

    #[test]
    fn test_execution_metrics() {
        let metrics = ComponentMetrics::new();

        metrics.record_function_called("comp1", "func1", Duration::from_millis(10), true);
        metrics.record_function_called("comp1", "func2", Duration::from_millis(20), false);
        metrics.record_function_called("comp2", "func1", Duration::from_millis(15), true);

        let exec_metrics = metrics.get_execution_metrics("comp1");
        assert_eq!(exec_metrics.total_calls, 2);
        assert_eq!(exec_metrics.successful_calls, 1);
        assert_eq!(exec_metrics.failed_calls, 1);
        assert_eq!(exec_metrics.functions.len(), 2);
    }

    #[test]
    fn test_metrics_clear() {
        let metrics = ComponentMetrics::new();

        metrics.record_function_called("test", "func", Duration::from_millis(10), true);
        assert_eq!(metrics.get_summary().total_functions_called, 1);

        metrics.clear();
        assert_eq!(metrics.get_summary().total_functions_called, 0);
    }

    #[test]
    fn test_metrics_json_export() {
        let metrics = ComponentMetrics::new();
        let json = metrics.export_json();
        assert!(json.is_ok());

        let json_str = json.unwrap();
        assert!(json_str.contains("total_components_loaded"));
        assert!(json_str.contains("total_functions_called"));
    }
}
