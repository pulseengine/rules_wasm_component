/*!
Example CLI tool using rust_wasm_component.

This demonstrates a component that uses WASI capabilities but doesn't
export custom interfaces - perfect for the lower-level rust_wasm_component rule.
*/

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde_json::{json, Value};
use std::fs;
use std::path::PathBuf;

/// File processor CLI tool
#[derive(Parser)]
#[command(name = "file-processor")]
#[command(about = "A simple file processing tool running in WebAssembly")]
#[command(version = "1.0.0")]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Enable verbose output
    #[arg(short, long, global = true)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Convert file to uppercase
    Upper {
        /// Input file path
        #[arg(short, long)]
        input: PathBuf,
        /// Output file path
        #[arg(short, long)]
        output: PathBuf,
    },
    /// Count words in file
    Count {
        /// Input file path
        #[arg(short, long)]
        input: PathBuf,
    },
    /// Convert file to JSON
    JsonWrap {
        /// Input file path
        #[arg(short, long)]
        input: PathBuf,
        /// Output file path
        #[arg(short, long)]
        output: PathBuf,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Upper { input, output } => {
            let content = fs::read_to_string(&input)
                .with_context(|| format!("Failed to read file: {:?}", input))?;

            let upper_content = content.to_uppercase();

            fs::write(&output, upper_content)
                .with_context(|| format!("Failed to write file: {:?}", output))?;

            if cli.verbose {
                println!("Converted {:?} to uppercase -> {:?}", input, output);
            }
        }
        Commands::Count { input } => {
            let content = fs::read_to_string(&input)
                .with_context(|| format!("Failed to read file: {:?}", input))?;

            let word_count = content.split_whitespace().count();
            let char_count = content.chars().count();
            let line_count = content.lines().count();

            println!("File: {:?}", input);
            println!("Lines: {}", line_count);
            println!("Words: {}", word_count);
            println!("Characters: {}", char_count);
        }
        Commands::JsonWrap { input, output } => {
            let content = fs::read_to_string(&input)
                .with_context(|| format!("Failed to read file: {:?}", input))?;

            let json_output = json!({
                "source_file": input.to_string_lossy(),
                "content": content,
                "processed_at": chrono::Utc::now().to_rfc3339(),
                "length": content.len()
            });

            fs::write(&output, serde_json::to_string_pretty(&json_output)?)
                .with_context(|| format!("Failed to write JSON file: {:?}", output))?;

            if cli.verbose {
                println!("Wrapped {:?} as JSON -> {:?}", input, output);
            }
        }
    }

    Ok(())
}

/*
This component demonstrates rust_wasm_component usage:

1. WASI-only: Uses filesystem, stdio - no custom component interfaces
2. CLI tool: Designed to be run from command line, not called by other components
3. Self-contained: Doesn't export functions for other components to use
4. Simple build: No WIT binding generation needed

Perfect for rust_wasm_component because:
- No custom WIT interfaces to generate bindings for
- Uses standard WASI capabilities only
- Allows custom rustc flags for optimization
- Simpler build process for utilities

Usage:
wasmtime run file_processor_cli.wasm -- upper -i input.txt -o output.txt
wasmtime run file_processor_cli.wasm -- count -i document.txt
wasmtime run file_processor_cli.wasm -- json-wrap -i data.txt -o data.json
*/
