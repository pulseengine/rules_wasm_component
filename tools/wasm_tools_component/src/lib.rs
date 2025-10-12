//! WASM Tools Integration Component
//!
//! This component provides unified access to wasm-tools operations across
//! different build systems and platforms, using hermetic tool binaries.

use anyhow::{Context, Result as AnyhowResult};
use std::env;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};

/// Get the path to the hermetic wasm-tools binary
fn get_wasm_tools_binary() -> String {
    // Use hermetic binary if available, otherwise fall back to system PATH
    env::var("WASM_TOOLS_BINARY").unwrap_or_else(|_| "wasm-tools".to_string())
}

/// Information about a WASM file
#[derive(serde::Serialize, serde::Deserialize, Debug)]
pub struct WasmInfo {
    pub path: String,
    pub size: u64,
    pub is_component: bool,
    pub validation_status: ValidationStatus,
    pub metadata: Vec<(String, String)>,
}

/// Validation status of a WASM file
#[derive(serde::Serialize, serde::Deserialize, Debug, PartialEq)]
pub enum ValidationStatus {
    Valid,
    Invalid,
    Unknown,
}

/// Component creation configuration
#[derive(serde::Deserialize, Debug)]
pub struct ComponentConfig {
    pub input_module: String,
    pub output_path: String,
    pub adapter: Option<String>,
    pub options: Vec<String>,
}

/// Component embedding configuration
#[derive(serde::Deserialize, Debug)]
pub struct EmbedConfig {
    pub wit_file: String,
    pub wasm_module: String,
    pub output_path: String,
    pub world: Option<String>,
    pub options: Vec<String>,
}

/// Composition configuration
#[derive(serde::Deserialize, Debug)]
pub struct ComposeConfig {
    pub components: Vec<String>,
    pub composition_file: String,
    pub output_path: String,
    pub options: Vec<String>,
}

/// Batch validation configuration
#[derive(serde::Deserialize, Debug)]
pub struct BatchValidationConfig {
    pub input_files: Vec<String>,
    pub output_dir: String,
    pub parallel: bool,
    pub features: Vec<String>,
}

/// Validate a WASM file using wasm-tools
pub fn validate_wasm(wasm_path: &str, features: &[String]) -> AnyhowResult<WasmInfo> {
    let path = Path::new(wasm_path);

    if !path.exists() {
        return Err(anyhow::anyhow!("WASM file does not exist: {}", wasm_path));
    }

    let metadata = fs::metadata(path)?;
    let size = metadata.len();

    // Run wasm-tools validate
    let mut cmd = Command::new(get_wasm_tools_binary());
    cmd.arg("validate").arg(wasm_path);

    // Add features if specified
    for feature in features {
        cmd.arg("--features").arg(feature);
    }

    let output = cmd
        .output()
        .with_context(|| "Failed to execute wasm-tools validate")?;

    let validation_status = if output.status.success() {
        ValidationStatus::Valid
    } else {
        ValidationStatus::Invalid
    };

    // Check if it's a component by trying component-model validation
    let is_component = if validation_status == ValidationStatus::Valid {
        check_is_component(wasm_path)?
    } else {
        false
    };

    Ok(WasmInfo {
        path: wasm_path.to_string(),
        size,
        is_component,
        validation_status,
        metadata: vec![(
            "format".to_string(),
            if is_component { "component" } else { "module" }.to_string(),
        )],
    })
}

/// Check if a WASM file is a component
pub fn check_is_component(wasm_path: &str) -> AnyhowResult<bool> {
    let output = Command::new(get_wasm_tools_binary())
        .arg("validate")
        .arg(wasm_path)
        .arg("--features")
        .arg("component-model")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .with_context(|| "Failed to execute wasm-tools validate for component check")?;

    Ok(output.status.success())
}

/// Get information about a WASM file
pub fn inspect_wasm(wasm_path: &str) -> AnyhowResult<WasmInfo> {
    validate_wasm(wasm_path, &[])
}

/// Create a new component from a WASM module
pub fn component_new(config: &ComponentConfig) -> AnyhowResult<String> {
    let mut cmd = Command::new(get_wasm_tools_binary());
    cmd.arg("component")
        .arg("new")
        .arg(&config.input_module)
        .arg("-o")
        .arg(&config.output_path);

    // Add adapter if specified
    if let Some(adapter) = &config.adapter {
        cmd.arg("--adapt").arg(adapter);
    }

    // Add additional options
    for option in &config.options {
        cmd.arg(option);
    }

    let output = cmd
        .output()
        .with_context(|| "Failed to execute wasm-tools component new")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!(
            "wasm-tools component new failed: {}",
            stderr
        ));
    }

    Ok(config.output_path.clone())
}

/// Embed WIT metadata into a WASM module to create a component
pub fn component_embed(config: &EmbedConfig) -> AnyhowResult<String> {
    let mut cmd = Command::new(get_wasm_tools_binary());
    cmd.arg("component")
        .arg("embed")
        .arg(&config.wit_file)
        .arg(&config.wasm_module)
        .arg("--output")
        .arg(&config.output_path);

    // Add world if specified
    if let Some(world) = &config.world {
        cmd.arg("--world").arg(world);
    }

    // Add additional options
    for option in &config.options {
        cmd.arg(option);
    }

    let output = cmd
        .output()
        .with_context(|| "Failed to execute wasm-tools component embed")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!(
            "wasm-tools component embed failed: {}",
            stderr
        ));
    }

    Ok(config.output_path.clone())
}

/// Extract WIT interface from a component
pub fn component_wit(component_path: &str, output_path: &str) -> AnyhowResult<String> {
    let output = Command::new(get_wasm_tools_binary())
        .arg("component")
        .arg("wit")
        .arg(component_path)
        .arg("-o")
        .arg(output_path)
        .output()
        .with_context(|| "Failed to execute wasm-tools component wit")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!(
            "wasm-tools component wit failed: {}",
            stderr
        ));
    }

    Ok(output_path.to_string())
}

/// Compose multiple components
pub fn compose_components(config: &ComposeConfig) -> AnyhowResult<String> {
    let mut cmd = Command::new(get_wasm_tools_binary());
    cmd.arg("compose")
        .arg("-f")
        .arg(&config.composition_file)
        .arg("-o")
        .arg(&config.output_path);

    // Add component files
    for component in &config.components {
        cmd.arg(component);
    }

    // Add additional options
    for option in &config.options {
        cmd.arg(option);
    }

    let output = cmd
        .output()
        .with_context(|| "Failed to execute wasm-tools compose")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("wasm-tools compose failed: {}", stderr));
    }

    Ok(config.output_path.clone())
}

/// Convert component to JavaScript bindings
pub fn to_js(component_path: &str, output_dir: &str, options: &[String]) -> AnyhowResult<String> {
    let mut cmd = Command::new(get_wasm_tools_binary());
    cmd.arg("component")
        .arg("targets")
        .arg("js")
        .arg(component_path)
        .arg("--out-dir")
        .arg(output_dir);

    // Add additional options
    for option in options {
        cmd.arg(option);
    }

    let output = cmd
        .output()
        .with_context(|| "Failed to execute wasm-tools component targets js")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("wasm-tools to-js failed: {}", stderr));
    }

    Ok(output_dir.to_string())
}

/// Strip debug information from component
pub fn strip_component(input_path: &str, output_path: &str) -> AnyhowResult<String> {
    let output = Command::new(get_wasm_tools_binary())
        .arg("strip")
        .arg(input_path)
        .arg("-o")
        .arg(output_path)
        .output()
        .with_context(|| "Failed to execute wasm-tools strip")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("wasm-tools strip failed: {}", stderr));
    }

    Ok(output_path.to_string())
}

/// Validate multiple WASM files in batch
pub fn validate_batch(config: &BatchValidationConfig) -> AnyhowResult<Vec<WasmInfo>> {
    let mut results = Vec::new();

    for input_file in &config.input_files {
        match validate_wasm(input_file, &config.features) {
            Ok(info) => results.push(info),
            Err(e) => {
                // For batch operations, we collect errors but continue processing
                results.push(WasmInfo {
                    path: input_file.clone(),
                    size: 0,
                    is_component: false,
                    validation_status: ValidationStatus::Invalid,
                    metadata: vec![("error".to_string(), e.to_string())],
                });
            }
        }
    }

    Ok(results)
}

/// Convert multiple modules to components in batch
pub fn batch_component_new(
    input_modules: &[String],
    output_dir: &str,
    adapter: Option<&str>,
) -> AnyhowResult<Vec<String>> {
    let mut results = Vec::new();

    // Ensure output directory exists
    fs::create_dir_all(output_dir)?;

    for input_module in input_modules {
        let input_path = Path::new(input_module);
        let filename = input_path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("component");
        let output_path = Path::new(output_dir).join(format!("{}.wasm", filename));

        let config = ComponentConfig {
            input_module: input_module.clone(),
            output_path: output_path.to_string_lossy().to_string(),
            adapter: adapter.map(|s| s.to_string()),
            options: vec![],
        };

        match component_new(&config) {
            Ok(output) => results.push(output),
            Err(e) => {
                // For batch operations, log error but continue
                eprintln!("Failed to convert {}: {}", input_module, e);
                continue;
            }
        }
    }

    Ok(results)
}
