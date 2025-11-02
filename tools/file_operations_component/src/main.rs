//! Command-line interface for the File Operations Component
//!
//! This CLI allows the File Operations Component to be invoked from Bazel
//! rules as a standard executable, bridging the gap between Bazel's execution
//! model and cross-platform file operations.

use std::env;
use std::fs;
use std::process;

use anyhow::{Context, Result as AnyhowResult};

// Include the library functions directly
mod lib;

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {}", e);
        process::exit(1);
    }
}

fn run() -> AnyhowResult<()> {
    let args: Vec<String> = env::args().collect();

    // Special case: If first arg is a file path ending in .json, treat it as JSON batch operations
    if args.len() == 2 && args[1].ends_with(".json") {
        process_json_batch_file(&args[1])?;
        return Ok(());
    }

    if args.len() < 2 {
        eprintln!("Usage: {} <operation> [args...]", args[0]);
        eprintln!("       {} <config.json>", args[0]);
        eprintln!("Operations:");
        eprintln!("  copy_file --src <src> --dest <dest>");
        eprintln!("  copy_directory --src <src> --dest <dest>");
        eprintln!("  create_directory --path <path>");
        eprintln!("  prepare_workspace --config <config_file>");
        eprintln!("  <config.json>  - Process JSON batch operations");
        process::exit(1);
    }

    let operation = &args[1];

    match operation.as_str() {
        "copy_file" => {
            let (src, dest) = parse_copy_args(&args[2..])?;
            lib::copy_file(&src, &dest)?;
        }
        "copy_directory" => {
            let (src, dest) = parse_copy_args(&args[2..])?;
            lib::copy_directory(&src, &dest)?;
        }
        "create_directory" => {
            let path = parse_path_arg(&args[2..])?;
            lib::create_directory(&path)?;
        }
        "prepare_workspace" => {
            let config_file = parse_config_arg(&args[2..])?;
            prepare_workspace_from_file(&config_file)?;
        }
        _ => {
            return Err(anyhow::anyhow!("Unknown operation: {}", operation));
        }
    }

    Ok(())
}

fn parse_copy_args(args: &[String]) -> AnyhowResult<(String, String)> {
    let mut src = None;
    let mut dest = None;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--src" => {
                if i + 1 < args.len() {
                    src = Some(args[i + 1].clone());
                    i += 2;
                } else {
                    return Err(anyhow::anyhow!("--src requires a value"));
                }
            }
            "--dest" => {
                if i + 1 < args.len() {
                    dest = Some(args[i + 1].clone());
                    i += 2;
                } else {
                    return Err(anyhow::anyhow!("--dest requires a value"));
                }
            }
            _ => {
                return Err(anyhow::anyhow!("Unknown argument: {}", args[i]));
            }
        }
    }

    let src = src.ok_or_else(|| anyhow::anyhow!("--src is required"))?;
    let dest = dest.ok_or_else(|| anyhow::anyhow!("--dest is required"))?;

    Ok((src, dest))
}

fn parse_path_arg(args: &[String]) -> AnyhowResult<String> {
    if args.len() < 2 || args[0] != "--path" {
        return Err(anyhow::anyhow!("Expected --path <path>"));
    }
    Ok(args[1].clone())
}

fn parse_config_arg(args: &[String]) -> AnyhowResult<String> {
    if args.len() < 2 || args[0] != "--config" {
        return Err(anyhow::anyhow!("Expected --config <config_file>"));
    }
    Ok(args[1].clone())
}

fn prepare_workspace_from_file(config_file: &str) -> AnyhowResult<()> {
    // Read configuration file
    let config_content = fs::read_to_string(config_file)
        .with_context(|| format!("Failed to read config file: {}", config_file))?;

    let config: lib::WorkspaceConfig = serde_json::from_str(&config_content)
        .with_context(|| format!("Failed to parse config file: {}", config_file))?;

    // Call the library function
    let result = lib::prepare_workspace(&config)?;

    println!("Workspace prepared successfully:");
    println!("  Path: {}", result.workspace_path);
    println!("  Files: {}", result.prepared_files.len());
    println!("  Time: {}ms", result.preparation_time_ms);
    println!("  Message: {}", result.message);

    Ok(())
}

fn process_json_batch_file(json_file: &str) -> AnyhowResult<()> {
    // Read JSON batch operations file
    let json_content = fs::read_to_string(json_file)
        .with_context(|| format!("Failed to read JSON file: {}", json_file))?;

    // Process batch operations
    let response_json = lib::process_json_batch(&json_content)
        .with_context(|| format!("Failed to process JSON batch operations"))?;

    // Parse response
    let response: lib::JsonBatchResponse = serde_json::from_str(&response_json)
        .with_context(|| format!("Failed to parse JSON batch response"))?;

    // Print results
    for (i, result) in response.results.iter().enumerate() {
        if result.success {
            println!("[{}] ✓ {}", i + 1, result.message);
            if let Some(ref output) = result.output {
                println!("    Output: {}", output);
            }
        } else {
            eprintln!("[{}] ✗ {}", i + 1, result.message);
        }
    }

    if !response.success {
        return Err(anyhow::anyhow!("Some operations failed"));
    }

    Ok(())
}
