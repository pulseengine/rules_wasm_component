/*!
Component Runner - A command-line tool for executing and testing WebAssembly components.

This tool demonstrates how to use the wasmtime runtime integration to:
- Load and instantiate WebAssembly components
- Execute component functions
- Monitor performance metrics
- Provide host functions to components

## Usage

```bash
# Run a component with default configuration
component_runner my_component.wasm

# Run with custom function and arguments
component_runner my_component.wasm --function "add" --args "[1, 2]"

# Run with production configuration
component_runner my_component.wasm --config production --timeout 5s

# Interactive mode for multiple function calls
component_runner my_component.wasm --interactive

# Enable debug logging
RUST_LOG=debug component_runner my_component.wasm
```
*/

use anyhow::{Context, Result};
use clap::{Arg, ArgMatches, Command};
use serde_json::Value;
use std::{path::Path, time::Duration};
use tokio::time::timeout;
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

    // Run the component runner
    if let Err(e) = run_component_runner(matches).await {
        error!("Component runner failed: {}", e);
        std::process::exit(1);
    }

    Ok(())
}

/// Create the CLI interface
fn create_cli() -> Command {
    Command::new("component_runner")
        .version(wasmtime_runtime::VERSION)
        .about("Execute and test WebAssembly components with Wasmtime")
        .arg(
            Arg::new("component")
                .help("Path to the WebAssembly component file")
                .required(true)
                .index(1),
        )
        .arg(
            Arg::new("function")
                .long("function")
                .short('f')
                .help("Function name to call")
                .default_value("main"),
        )
        .arg(
            Arg::new("args")
                .long("args")
                .short('a')
                .help("Function arguments as JSON array")
                .default_value("[]"),
        )
        .arg(
            Arg::new("config")
                .long("config")
                .short('c')
                .help("Runtime configuration preset")
                .value_parser(["development", "production", "sandbox"])
                .default_value("development"),
        )
        .arg(
            Arg::new("timeout")
                .long("timeout")
                .short('t')
                .help("Execution timeout (e.g., '10s', '1m')")
                .default_value("30s"),
        )
        .arg(
            Arg::new("interactive")
                .long("interactive")
                .short('i')
                .help("Run in interactive mode")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("metrics")
                .long("metrics")
                .short('m')
                .help("Show detailed metrics after execution")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("host-functions")
                .long("host-functions")
                .help("Enable common host functions")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("validate-only")
                .long("validate-only")
                .help("Only validate the component, don't execute")
                .action(clap::ArgAction::SetTrue),
        )
}

/// Main runner logic
async fn run_component_runner(matches: ArgMatches) -> Result<()> {
    let component_path = matches.get_one::<String>("component").unwrap();
    let function_name = matches.get_one::<String>("function").unwrap();
    let args_json = matches.get_one::<String>("args").unwrap();
    let config_preset = matches.get_one::<String>("config").unwrap();
    let timeout_str = matches.get_one::<String>("timeout").unwrap();
    let interactive = matches.get_flag("interactive");
    let show_metrics = matches.get_flag("metrics");
    let enable_host_functions = matches.get_flag("host-functions");
    let validate_only = matches.get_flag("validate-only");

    info!(
        "Starting component runner with component: {}",
        component_path
    );

    // Parse timeout
    let execution_timeout = parse_duration(timeout_str)
        .with_context(|| format!("Invalid timeout format: {}", timeout_str))?;

    // Parse function arguments
    let args: Vec<Value> = serde_json::from_str(args_json)
        .with_context(|| format!("Invalid JSON arguments: {}", args_json))?;

    // Create runtime configuration
    let config = create_runtime_config(config_preset, execution_timeout)?;

    // Create component loader
    let loader = ComponentLoader::new(config).context("Failed to create component loader")?;

    // Set up host functions if requested
    let host_registry = if enable_host_functions {
        let registry = HostFunctionRegistry::new();
        for func in create_common_host_functions() {
            registry.register_function(func).await?;
        }
        info!(
            "Registered {} host functions",
            registry.list_functions().await.len()
        );
        Some(registry)
    } else {
        None
    };

    // Load the component
    info!("Loading component from: {}", component_path);
    let loaded_component = loader
        .load_component(component_path)
        .await
        .with_context(|| format!("Failed to load component: {}", component_path))?;

    info!(
        "Component loaded successfully: {} ({} bytes)",
        loaded_component.metadata().name,
        loaded_component.metadata().size_bytes
    );

    if validate_only {
        info!("Component validation successful - exiting without execution");
        return Ok(());
    }

    // Instantiate the component
    info!("Instantiating component...");
    let mut instance = loaded_component
        .instantiate()
        .await
        .context("Failed to instantiate component")?;

    info!("Component instantiated successfully");

    if interactive {
        // Run interactive mode
        run_interactive_mode(&mut instance, &host_registry).await?;
    } else {
        // Execute single function
        execute_function(&mut instance, function_name, &args, execution_timeout).await?;
    }

    // Show metrics if requested
    if show_metrics {
        show_execution_metrics(&instance, &loader).await;
    }

    info!("Component runner completed successfully");
    Ok(())
}

/// Create runtime configuration based on preset
fn create_runtime_config(preset: &str, execution_timeout: Duration) -> Result<RuntimeConfig> {
    let builder = match preset {
        "development" => RuntimeConfig::development(),
        "production" => RuntimeConfig::production(),
        "sandbox" => RuntimeConfig::sandbox(),
        _ => return Err(anyhow::anyhow!("Unknown configuration preset: {}", preset)),
    };

    builder
        .with_execution_timeout(execution_timeout)
        .build()
        .with_context(|| format!("Failed to create {} configuration", preset))
}

/// Execute a single function with timeout
async fn execute_function(
    instance: &mut wasmtime_runtime::ComponentInstance,
    function_name: &str,
    args: &[Value],
    execution_timeout: Duration,
) -> Result<()> {
    info!(
        "Executing function '{}' with {} arguments",
        function_name,
        args.len()
    );

    let start_time = std::time::Instant::now();

    let result = timeout(
        execution_timeout,
        instance.call_function(function_name, args),
    )
    .await
    .context("Function execution timed out")?
    .with_context(|| format!("Function '{}' execution failed", function_name))?;

    let execution_time = start_time.elapsed();

    info!(
        "Function '{}' completed in {:?}",
        function_name, execution_time
    );

    // Pretty print the result
    match result {
        Value::Null => println!("Result: null"),
        Value::Bool(b) => println!("Result: {}", b),
        Value::Number(n) => println!("Result: {}", n),
        Value::String(s) => println!("Result: \"{}\"", s),
        _ => println!("Result: {}", serde_json::to_string_pretty(&result)?),
    }

    Ok(())
}

/// Run interactive mode for multiple function calls
async fn run_interactive_mode(
    instance: &mut wasmtime_runtime::ComponentInstance,
    _host_registry: &Option<HostFunctionRegistry>,
) -> Result<()> {
    info!("Entering interactive mode. Type 'help' for commands, 'quit' to exit.");

    loop {
        // Read user input
        print!("wasmtime> ");
        use std::io::{self, Write};
        io::stdout().flush().unwrap();

        let mut input = String::new();
        if io::stdin().read_line(&mut input).is_err() {
            break;
        }

        let input = input.trim();
        if input.is_empty() {
            continue;
        }

        match input {
            "quit" | "exit" => break,
            "help" => show_interactive_help(),
            "metrics" => {
                let metrics = instance.execution_metrics();
                println!(
                    "Execution metrics: {}",
                    serde_json::to_string_pretty(&metrics)?
                );
            }
            _ => {
                // Parse command as "function_name arg1 arg2 ..."
                let parts: Vec<&str> = input.split_whitespace().collect();
                if parts.is_empty() {
                    continue;
                }

                let function_name = parts[0];
                let args: Vec<Value> = parts[1..]
                    .iter()
                    .map(|&s| {
                        // Try to parse as number first, then as string
                        if let Ok(n) = s.parse::<f64>() {
                            Value::Number(serde_json::Number::from_f64(n).unwrap())
                        } else {
                            Value::String(s.to_string())
                        }
                    })
                    .collect();

                match instance.call_function(function_name, &args).await {
                    Ok(result) => {
                        println!("→ {}", serde_json::to_string(&result)?);
                    }
                    Err(e) => {
                        warn!("Function call failed: {}", e);
                    }
                }
            }
        }
    }

    info!("Exiting interactive mode");
    Ok(())
}

/// Show help for interactive mode
fn show_interactive_help() {
    println!("Interactive mode commands:");
    println!("  function_name [args...]  - Call a function with arguments");
    println!("  metrics                  - Show execution metrics");
    println!("  help                     - Show this help");
    println!("  quit, exit               - Exit interactive mode");
    println!();
    println!("Examples:");
    println!("  add 1 2                  - Call add(1, 2)");
    println!("  hello world              - Call hello(\"world\")");
}

/// Show execution metrics
async fn show_execution_metrics(
    instance: &wasmtime_runtime::ComponentInstance,
    loader: &ComponentLoader,
) {
    println!("\n=== Execution Metrics ===");

    // Component-specific metrics
    let exec_metrics = instance.execution_metrics();
    println!("Component: {}", exec_metrics.component_name);
    println!("Total calls: {}", exec_metrics.total_calls);
    println!("Successful calls: {}", exec_metrics.successful_calls);
    println!("Failed calls: {}", exec_metrics.failed_calls);
    println!(
        "Total execution time: {:?}",
        exec_metrics.total_execution_time
    );
    println!(
        "Average execution time: {:?}",
        exec_metrics.average_execution_time
    );

    if !exec_metrics.functions.is_empty() {
        println!("\nFunction statistics:");
        for (name, stats) in &exec_metrics.functions {
            println!(
                "  {}: {} calls, avg {:?}",
                name, stats.call_count, stats.average_execution_time
            );
        }
    }

    // Global metrics
    let global_metrics = loader.metrics().get_summary();
    println!("\n=== Global Metrics ===");
    println!(
        "Total components loaded: {}",
        global_metrics.total_components_loaded
    );
    println!(
        "Total functions called: {}",
        global_metrics.total_functions_called
    );
    println!("Average load time: {:?}", global_metrics.average_load_time);
    println!(
        "Average execution time: {:?}",
        global_metrics.average_execution_time
    );
}

/// Parse duration string (e.g., "10s", "1m", "500ms")
fn parse_duration(s: &str) -> Result<Duration> {
    let s = s.trim();

    if s.ends_with("ms") {
        let ms: u64 = s[..s.len() - 2].parse()?;
        Ok(Duration::from_millis(ms))
    } else if s.ends_with('s') {
        let secs: u64 = s[..s.len() - 1].parse()?;
        Ok(Duration::from_secs(secs))
    } else if s.ends_with('m') {
        let mins: u64 = s[..s.len() - 1].parse()?;
        Ok(Duration::from_secs(mins * 60))
    } else if s.ends_with('h') {
        let hours: u64 = s[..s.len() - 1].parse()?;
        Ok(Duration::from_secs(hours * 3600))
    } else {
        // Default to seconds
        let secs: u64 = s.parse()?;
        Ok(Duration::from_secs(secs))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_duration() {
        assert_eq!(parse_duration("10s").unwrap(), Duration::from_secs(10));
        assert_eq!(parse_duration("500ms").unwrap(), Duration::from_millis(500));
        assert_eq!(parse_duration("2m").unwrap(), Duration::from_secs(120));
        assert_eq!(parse_duration("1h").unwrap(), Duration::from_secs(3600));
        assert_eq!(parse_duration("30").unwrap(), Duration::from_secs(30));
    }

    #[test]
    fn test_create_runtime_config() {
        let config = create_runtime_config("development", Duration::from_secs(10));
        assert!(config.is_ok());

        let config = create_runtime_config("production", Duration::from_secs(5));
        assert!(config.is_ok());

        let config = create_runtime_config("invalid", Duration::from_secs(10));
        assert!(config.is_err());
    }
}
