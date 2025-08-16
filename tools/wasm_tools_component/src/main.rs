//! Command-line interface for the WASM Tools Integration Component
//!
//! This CLI provides unified access to wasm-tools operations from Bazel rules,
//! replacing direct tool invocations with a consistent interface.

use std::env;
use std::fs;
use std::process;

use anyhow::{Context, Result as AnyhowResult};

// Use the library functions
#[path = "lib.rs"]
mod lib;

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {}", e);
        process::exit(1);
    }
}

fn run() -> AnyhowResult<()> {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        print_usage(&args[0]);
        process::exit(1);
    }

    let operation = &args[1];

    match operation.as_str() {
        "validate" => {
            let (wasm_path, features) = parse_validate_args(&args[2..])?;
            let info = lib::validate_wasm(&wasm_path, &features)?;
            println!("Validation result: {:?}", info);
        }
        "inspect" => {
            let wasm_path = parse_single_path_arg(&args[2..])?;
            let info = lib::inspect_wasm(&wasm_path)?;
            println!("WASM info: {:?}", info);
        }
        "is-component" => {
            let wasm_path = parse_single_path_arg(&args[2..])?;
            let is_component = lib::check_is_component(&wasm_path)?;
            println!("{}", is_component);
        }
        "component-new" => {
            let config_file = parse_config_arg(&args[2..])?;
            let config = load_component_config(&config_file)?;
            let result = lib::component_new(&config)?;
            println!("Created component: {}", result);
        }
        "component-embed" => {
            let config_file = parse_config_arg(&args[2..])?;
            let config = load_embed_config(&config_file)?;
            let result = lib::component_embed(&config)?;
            println!("Embedded component: {}", result);
        }
        "component-wit" => {
            let (component_path, output_path) = parse_two_path_args(&args[2..])?;
            let result = lib::component_wit(&component_path, &output_path)?;
            println!("Extracted WIT: {}", result);
        }
        "compose" => {
            let config_file = parse_config_arg(&args[2..])?;
            let config = load_compose_config(&config_file)?;
            let result = lib::compose_components(&config)?;
            println!("Composed components: {}", result);
        }
        "to-js" => {
            let (component_path, output_dir, options) = parse_to_js_args(&args[2..])?;
            let result = lib::to_js(&component_path, &output_dir, &options)?;
            println!("Generated JS bindings: {}", result);
        }
        "strip" => {
            let (input_path, output_path) = parse_two_path_args(&args[2..])?;
            let result = lib::strip_component(&input_path, &output_path)?;
            println!("Stripped component: {}", result);
        }
        "validate-batch" => {
            let config_file = parse_config_arg(&args[2..])?;
            let config = load_batch_validation_config(&config_file)?;
            let results = lib::validate_batch(&config)?;
            println!(
                "Batch validation results: {} files processed",
                results.len()
            );
            for result in results {
                println!("  {}: {:?}", result.path, result.validation_status);
            }
        }
        "batch-component-new" => {
            let (input_dir, output_dir, adapter) = parse_batch_new_args(&args[2..])?;
            let input_files = discover_wasm_modules(&input_dir)?;
            let results = lib::batch_component_new(&input_files, &output_dir, adapter.as_deref())?;
            println!(
                "Batch conversion results: {} components created",
                results.len()
            );
            for result in results {
                println!("  {}", result);
            }
        }
        _ => {
            return Err(anyhow::anyhow!("Unknown operation: {}", operation));
        }
    }

    Ok(())
}

fn print_usage(program_name: &str) {
    eprintln!("Usage: {} <operation> [args...]", program_name);
    eprintln!("Operations:");
    eprintln!("  validate <wasm-file> [--features <feature>...]     - Validate WASM file");
    eprintln!("  inspect <wasm-file>                               - Get WASM file information");
    eprintln!("  is-component <wasm-file>                          - Check if file is a component");
    eprintln!("  component-new --config <config-file>              - Create component from module");
    eprintln!("  component-embed --config <config-file>            - Embed WIT into module");
    eprintln!("  component-wit <component> <output>                - Extract WIT from component");
    eprintln!("  compose --config <config-file>                    - Compose multiple components");
    eprintln!("  to-js <component> <output-dir> [options...]       - Generate JS bindings");
    eprintln!("  strip <input> <output>                            - Strip debug information");
    eprintln!("  validate-batch --config <config-file>             - Batch validate files");
    eprintln!("  batch-component-new <input-dir> <output-dir> [adapter] - Batch convert modules");
}

fn parse_validate_args(args: &[String]) -> AnyhowResult<(String, Vec<String>)> {
    if args.is_empty() {
        return Err(anyhow::anyhow!("validate requires a WASM file path"));
    }

    let wasm_path = args[0].clone();
    let mut features = Vec::new();

    let mut i = 1;
    while i < args.len() {
        if args[i] == "--features" && i + 1 < args.len() {
            features.push(args[i + 1].clone());
            i += 2;
        } else {
            i += 1;
        }
    }

    Ok((wasm_path, features))
}

fn parse_single_path_arg(args: &[String]) -> AnyhowResult<String> {
    if args.is_empty() {
        return Err(anyhow::anyhow!("Operation requires a file path"));
    }
    Ok(args[0].clone())
}

fn parse_two_path_args(args: &[String]) -> AnyhowResult<(String, String)> {
    if args.len() < 2 {
        return Err(anyhow::anyhow!("Operation requires two file paths"));
    }
    Ok((args[0].clone(), args[1].clone()))
}

fn parse_config_arg(args: &[String]) -> AnyhowResult<String> {
    if args.len() < 2 || args[0] != "--config" {
        return Err(anyhow::anyhow!("Expected --config <config-file>"));
    }
    Ok(args[1].clone())
}

fn parse_to_js_args(args: &[String]) -> AnyhowResult<(String, String, Vec<String>)> {
    if args.len() < 2 {
        return Err(anyhow::anyhow!(
            "to-js requires component path and output directory"
        ));
    }

    let component_path = args[0].clone();
    let output_dir = args[1].clone();
    let options = args[2..].to_vec();

    Ok((component_path, output_dir, options))
}

fn parse_batch_new_args(args: &[String]) -> AnyhowResult<(String, String, Option<String>)> {
    if args.len() < 2 {
        return Err(anyhow::anyhow!(
            "batch-component-new requires input and output directories"
        ));
    }

    let input_dir = args[0].clone();
    let output_dir = args[1].clone();
    let adapter = if args.len() > 2 {
        Some(args[2].clone())
    } else {
        None
    };

    Ok((input_dir, output_dir, adapter))
}

fn load_component_config(config_file: &str) -> AnyhowResult<lib::ComponentConfig> {
    let content = fs::read_to_string(config_file)
        .with_context(|| format!("Failed to read config file: {}", config_file))?;

    serde_json::from_str(&content)
        .with_context(|| format!("Failed to parse component config: {}", config_file))
}

fn load_embed_config(config_file: &str) -> AnyhowResult<lib::EmbedConfig> {
    let content = fs::read_to_string(config_file)
        .with_context(|| format!("Failed to read config file: {}", config_file))?;

    serde_json::from_str(&content)
        .with_context(|| format!("Failed to parse embed config: {}", config_file))
}

fn load_compose_config(config_file: &str) -> AnyhowResult<lib::ComposeConfig> {
    let content = fs::read_to_string(config_file)
        .with_context(|| format!("Failed to read config file: {}", config_file))?;

    serde_json::from_str(&content)
        .with_context(|| format!("Failed to parse compose config: {}", config_file))
}

fn load_batch_validation_config(config_file: &str) -> AnyhowResult<lib::BatchValidationConfig> {
    let content = fs::read_to_string(config_file)
        .with_context(|| format!("Failed to read config file: {}", config_file))?;

    serde_json::from_str(&content)
        .with_context(|| format!("Failed to parse batch validation config: {}", config_file))
}

fn discover_wasm_modules(input_dir: &str) -> AnyhowResult<Vec<String>> {
    let mut wasm_files = Vec::new();

    for entry in fs::read_dir(input_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("wasm") {
            if let Some(path_str) = path.to_str() {
                wasm_files.push(path_str.to_string());
            }
        }
    }

    Ok(wasm_files)
}
