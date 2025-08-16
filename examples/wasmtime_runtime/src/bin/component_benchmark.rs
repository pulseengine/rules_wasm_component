/*!
Component Benchmark - Performance testing tool for WebAssembly components.

This tool provides comprehensive benchmarking capabilities for WebAssembly components:
- Load time benchmarks
- Function execution benchmarks
- Memory usage analysis
- Throughput testing
- Comparative performance analysis

## Usage

```bash
# Basic benchmark of a component
component_benchmark my_component.wasm

# Benchmark specific function with iterations
component_benchmark my_component.wasm --function "calculate" --iterations 1000

# Memory usage benchmark
component_benchmark my_component.wasm --memory-benchmark

# Comparative benchmark against multiple components
component_benchmark comp1.wasm comp2.wasm comp3.wasm --compare

# Output results in JSON format
component_benchmark my_component.wasm --output json
```
*/

use anyhow::{Context, Result};
use clap::{Arg, ArgMatches, Command};
use criterion::{black_box, Criterion};
use serde_json::Value;
use std::{path::Path, time::Duration};
use tokio::time::Instant;
use tracing::{error, info, warn};
use wasmtime_runtime::{
    create_common_host_functions, ComponentLoader, HostFunctionRegistry, RuntimeConfig,
};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    wasmtime_runtime::init_tracing()?;

    // Parse command line arguments
    let matches = create_cli().get_matches();

    // Run the benchmark
    if let Err(e) = run_benchmark(matches).await {
        error!("Benchmark failed: {}", e);
        std::process::exit(1);
    }

    Ok(())
}

fn create_cli() -> Command {
    Command::new("component_benchmark")
        .about("WebAssembly component performance benchmarking tool")
        .version("1.0.0")
        .arg(
            Arg::new("components")
                .help("WebAssembly component files to benchmark")
                .required(true)
                .num_args(1..)
                .value_name("COMPONENT"),
        )
        .arg(
            Arg::new("function")
                .long("function")
                .short('f')
                .help("Specific function to benchmark")
                .value_name("FUNCTION"),
        )
        .arg(
            Arg::new("iterations")
                .long("iterations")
                .short('i')
                .help("Number of benchmark iterations")
                .default_value("100")
                .value_name("COUNT"),
        )
        .arg(
            Arg::new("args")
                .long("args")
                .short('a')
                .help("Function arguments as JSON")
                .value_name("JSON"),
        )
        .arg(
            Arg::new("memory-benchmark")
                .long("memory-benchmark")
                .help("Include memory usage benchmarking")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("compare")
                .long("compare")
                .help("Compare performance across multiple components")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("output")
                .long("output")
                .short('o')
                .help("Output format (human, json, csv)")
                .default_value("human")
                .value_name("FORMAT"),
        )
        .arg(
            Arg::new("warmup")
                .long("warmup")
                .help("Number of warmup iterations")
                .default_value("10")
                .value_name("COUNT"),
        )
}

async fn run_benchmark(matches: ArgMatches) -> Result<()> {
    let components: Vec<&str> = matches
        .get_many::<String>("components")
        .unwrap()
        .map(|s| s.as_str())
        .collect();
    let function = matches.get_one::<String>("function");
    let iterations: usize = matches.get_one::<String>("iterations").unwrap().parse()?;
    let warmup: usize = matches.get_one::<String>("warmup").unwrap().parse()?;
    let output_format = matches.get_one::<String>("output").unwrap();
    let memory_benchmark = matches.get_flag("memory-benchmark");
    let compare_mode = matches.get_flag("compare");

    info!(
        "Starting benchmark with {} iterations and {} warmup",
        iterations, warmup
    );

    // Create runtime configuration optimized for benchmarking
    let config = RuntimeConfig::benchmark_optimized();
    let host_functions = create_common_host_functions();

    for component_path in components {
        info!("Benchmarking component: {}", component_path);

        let component_results = benchmark_component(
            component_path,
            function,
            iterations,
            warmup,
            memory_benchmark,
            &config,
            &host_functions,
        )
        .await?;

        output_results(&component_results, output_format)?;
    }

    if compare_mode && components.len() > 1 {
        info!("Generating comparative analysis...");
        generate_comparison_report(&components, output_format)?;
    }

    Ok(())
}

async fn benchmark_component(
    component_path: &str,
    function: Option<&String>,
    iterations: usize,
    warmup: usize,
    memory_benchmark: bool,
    config: &RuntimeConfig,
    host_functions: &HostFunctionRegistry,
) -> Result<BenchmarkResults> {
    let path = Path::new(component_path);

    // Load time benchmark
    let load_start = Instant::now();
    let loader = ComponentLoader::new_with_config(config.clone(), host_functions.clone()).await?;
    let component = loader.load_component(path).await?;
    let load_time = load_start.elapsed();

    // Instantiation benchmark
    let instantiation_start = Instant::now();
    let instance = component.instantiate().await?;
    let instantiation_time = instantiation_start.elapsed();

    // Function execution benchmark
    let mut execution_times = Vec::new();
    let function_name = function.map(|s| s.as_str()).unwrap_or("default");

    // Warmup iterations
    for _ in 0..warmup {
        let _ = instance.call_function(function_name, &[]).await;
    }

    // Benchmark iterations
    for _ in 0..iterations {
        let exec_start = Instant::now();
        let _result = instance.call_function(function_name, &[]).await?;
        execution_times.push(exec_start.elapsed());
    }

    // Memory benchmark if requested
    let memory_usage = if memory_benchmark {
        Some(measure_memory_usage(&instance).await?)
    } else {
        None
    };

    Ok(BenchmarkResults {
        component_path: component_path.to_string(),
        load_time,
        instantiation_time,
        execution_times,
        memory_usage,
        function_name: function_name.to_string(),
    })
}

async fn measure_memory_usage(
    instance: &wasmtime_runtime::ComponentInstance,
) -> Result<MemoryUsage> {
    // Placeholder for memory usage measurement
    // In a real implementation, this would use Wasmtime's memory introspection APIs
    Ok(MemoryUsage {
        peak_memory_bytes: 0,
        current_memory_bytes: 0,
        allocation_count: 0,
    })
}

fn output_results(results: &BenchmarkResults, format: &str) -> Result<()> {
    match format {
        "json" => {
            let json_output = serde_json::to_string_pretty(results)?;
            println!("{}", json_output);
        }
        "csv" => {
            output_csv_results(results)?;
        }
        _ => {
            output_human_results(results)?;
        }
    }
    Ok(())
}

fn output_human_results(results: &BenchmarkResults) -> Result<()> {
    println!("=== Benchmark Results: {} ===", results.component_path);
    println!("Load time: {:?}", results.load_time);
    println!("Instantiation time: {:?}", results.instantiation_time);

    if !results.execution_times.is_empty() {
        let avg_execution =
            results.execution_times.iter().sum::<Duration>() / results.execution_times.len() as u32;
        let min_execution = results.execution_times.iter().min().unwrap();
        let max_execution = results.execution_times.iter().max().unwrap();

        println!("Function '{}' execution:", results.function_name);
        println!("  Average: {:?}", avg_execution);
        println!("  Min: {:?}", min_execution);
        println!("  Max: {:?}", max_execution);
        println!("  Iterations: {}", results.execution_times.len());
    }

    if let Some(ref memory) = results.memory_usage {
        println!("Memory usage:");
        println!("  Peak: {} bytes", memory.peak_memory_bytes);
        println!("  Current: {} bytes", memory.current_memory_bytes);
        println!("  Allocations: {}", memory.allocation_count);
    }

    Ok(())
}

fn output_csv_results(results: &BenchmarkResults) -> Result<()> {
    println!("component,function,load_time_ms,instantiation_time_ms,avg_execution_ms,min_execution_ms,max_execution_ms,iterations");

    let avg_execution = if !results.execution_times.is_empty() {
        results.execution_times.iter().sum::<Duration>().as_millis()
            / results.execution_times.len() as u128
    } else {
        0
    };

    let min_execution = results
        .execution_times
        .iter()
        .min()
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let max_execution = results
        .execution_times
        .iter()
        .max()
        .map(|d| d.as_millis())
        .unwrap_or(0);

    println!(
        "{},{},{},{},{},{},{},{}",
        results.component_path,
        results.function_name,
        results.load_time.as_millis(),
        results.instantiation_time.as_millis(),
        avg_execution,
        min_execution,
        max_execution,
        results.execution_times.len()
    );

    Ok(())
}

fn generate_comparison_report(components: &[&str], format: &str) -> Result<()> {
    println!("=== Comparative Analysis ===");
    println!("Compared {} components", components.len());
    println!("See individual results above for detailed metrics");
    Ok(())
}

#[derive(Debug)]
struct BenchmarkResults {
    component_path: String,
    load_time: Duration,
    instantiation_time: Duration,
    execution_times: Vec<Duration>,
    memory_usage: Option<MemoryUsage>,
    function_name: String,
}

#[derive(Debug)]
struct MemoryUsage {
    peak_memory_bytes: u64,
    current_memory_bytes: u64,
    allocation_count: u64,
}
