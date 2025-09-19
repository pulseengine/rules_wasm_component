use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::fs;
use std::path::PathBuf;
use wasm_encoder::{CustomSection, Module};
use wasmparser::{Parser as WasmParser, Payload};

#[derive(Parser)]
#[command(name = "wasm-embed-aot")]
#[command(about = "Embed and extract AOT artifacts in WebAssembly components")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Embed AOT artifacts as custom sections
    Embed {
        /// Input WebAssembly component
        #[arg(short, long)]
        input: PathBuf,

        /// Output WebAssembly component with embedded AOT
        #[arg(short, long)]
        output: PathBuf,

        /// AOT artifacts to embed (format: "name:path")
        artifacts: Vec<String>,
    },
    /// Extract AOT artifact from component
    Extract {
        /// Input WebAssembly component with embedded AOT
        #[arg(short, long)]
        input: PathBuf,

        /// Output AOT artifact file
        #[arg(short, long)]
        output: PathBuf,

        /// Section name to extract (e.g., "aot-linux-x64")
        #[arg(short, long)]
        section: String,
    },
    /// List all embedded AOT artifacts
    List {
        /// Input WebAssembly component
        #[arg(short, long)]
        input: PathBuf,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Embed { input, output, artifacts } => {
            embed_artifacts(&input, &output, &artifacts)?;
        },
        Commands::Extract { input, output, section } => {
            extract_artifact(&input, &output, &section)?;
        },
        Commands::List { input } => {
            list_artifacts(&input)?;
        },
    }

    Ok(())
}

fn embed_artifacts(input: &PathBuf, output: &PathBuf, artifacts: &[String]) -> Result<()> {
    let wasm_data = fs::read(input)
        .with_context(|| format!("Failed to read input file: {}", input.display()))?;

    println!("Original WASM size: {} bytes", wasm_data.len());

    // Parse artifacts from "name:path" format
    let mut aot_artifacts = Vec::new();
    for artifact in artifacts {
        let parts: Vec<&str> = artifact.splitn(2, ':').collect();
        if parts.len() != 2 {
            anyhow::bail!("Invalid artifact format '{}'. Expected 'name:path'", artifact);
        }

        let section_name = format!("aot-{}", parts[0]);
        let artifact_data = fs::read(parts[1])
            .with_context(|| format!("Failed to read artifact file: {}", parts[1]))?;

        println!("Embedding {} bytes as section '{}'", artifact_data.len(), section_name);
        aot_artifacts.push((section_name, artifact_data));
    }

    // Create new WASM with embedded artifacts
    let enhanced_wasm = add_custom_sections(wasm_data, aot_artifacts)?;

    fs::write(output, &enhanced_wasm)
        .with_context(|| format!("Failed to write output file: {}", output.display()))?;

    println!("Created {} with {} embedded AOT sections", output.display(), artifacts.len());
    println!("Final WASM size: {} bytes", enhanced_wasm.len());

    Ok(())
}

fn extract_artifact(input: &PathBuf, output: &PathBuf, section_name: &str) -> Result<()> {
    let wasm_data = fs::read(input)
        .with_context(|| format!("Failed to read input file: {}", input.display()))?;

    println!("Searching for section '{}' in {} byte WASM file", section_name, wasm_data.len());

    let parser = WasmParser::new(0);
    for payload in parser.parse_all(&wasm_data) {
        let payload = payload.context("Failed to parse WASM")?;

        if let Payload::CustomSection(reader) = payload {
            println!("Found custom section: '{}'", reader.name());

            if reader.name() == section_name {
                let section_data = reader.data();
                fs::write(output, section_data)
                    .with_context(|| format!("Failed to write output file: {}", output.display()))?;

                println!("Extracted {} bytes to {}", section_data.len(), output.display());
                return Ok(());
            }
        }
    }

    anyhow::bail!("Section '{}' not found", section_name);
}

fn list_artifacts(input: &PathBuf) -> Result<()> {
    let wasm_data = fs::read(input)
        .with_context(|| format!("Failed to read input file: {}", input.display()))?;

    let parser = WasmParser::new(0);
    let mut artifacts = Vec::new();

    for payload in parser.parse_all(&wasm_data) {
        let payload = payload.context("Failed to parse WASM")?;

        if let Payload::CustomSection(reader) = payload {
            if reader.name().starts_with("aot-") {
                artifacts.push(reader.name().to_string());
            }
        }
    }

    if artifacts.is_empty() {
        println!("No AOT artifacts found");
    } else {
        println!("Found {} AOT artifacts:", artifacts.len());
        for artifact in artifacts {
            println!("  {}", artifact);
        }
    }

    Ok(())
}

fn add_custom_sections(wasm_data: Vec<u8>, aot_artifacts: Vec<(String, Vec<u8>)>) -> Result<Vec<u8>> {
    // For simplicity, we'll use the same approach as the Python version:
    // insert custom sections after the WASM header (first 8 bytes)

    let mut result = Vec::new();

    // Copy WASM header (magic + version)
    if wasm_data.len() < 8 {
        anyhow::bail!("Invalid WASM file: too short");
    }

    result.extend_from_slice(&wasm_data[0..8]);

    // Add custom sections
    for (section_name, section_data) in aot_artifacts {
        let custom_section = create_custom_section(&section_name, &section_data)?;
        result.extend_from_slice(&custom_section);
    }

    // Copy rest of original WASM
    result.extend_from_slice(&wasm_data[8..]);

    Ok(result)
}

fn create_custom_section(name: &str, data: &[u8]) -> Result<Vec<u8>> {
    // Custom section format:
    // - section_id (0 for custom sections): 1 byte
    // - section_size (LEB128): variable
    // - name_length (LEB128): variable
    // - name: name_length bytes
    // - data: remaining bytes

    let name_bytes = name.as_bytes();
    let section_content_size = leb128_size(name_bytes.len()) + name_bytes.len() + data.len();

    let mut section = Vec::new();

    // Section ID (0 = custom section)
    section.push(0);

    // Section size (LEB128)
    write_leb128(&mut section, section_content_size);

    // Name length (LEB128)
    write_leb128(&mut section, name_bytes.len());

    // Name
    section.extend_from_slice(name_bytes);

    // Data
    section.extend_from_slice(data);

    Ok(section)
}

fn write_leb128(output: &mut Vec<u8>, mut value: usize) {
    loop {
        let byte = (value & 0x7F) as u8;
        value >>= 7;
        if value == 0 {
            output.push(byte);
            break;
        } else {
            output.push(byte | 0x80);
        }
    }
}

fn leb128_size(value: usize) -> usize {
    if value == 0 {
        1
    } else {
        ((value.ilog2() / 7) + 1) as usize
    }
}