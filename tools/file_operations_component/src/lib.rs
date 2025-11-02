//! Universal File Operations Component for WebAssembly Build Systems
//!
//! This component provides cross-platform file operations that replace
//! platform-specific shell scripts in build systems like Bazel.

use anyhow::{Context, Result as AnyhowResult};
use std::fs;
use std::path::Path;

/// Copy a file from source to destination
pub fn copy_file(src: &str, dest: &str) -> AnyhowResult<()> {
    let src_path = Path::new(src);
    let dest_path = Path::new(dest);

    if !src_path.exists() {
        return Err(anyhow::anyhow!("Source file does not exist: {}", src));
    }

    // Create parent directory if it doesn't exist
    if let Some(parent) = dest_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("Failed to create parent directory for: {}", dest))?;
    }

    fs::copy(src_path, dest_path).with_context(|| format!("Failed to copy {} to {}", src, dest))?;

    Ok(())
}

/// Copy a directory recursively from source to destination
pub fn copy_directory(src: &str, dest: &str) -> AnyhowResult<()> {
    let src_path = Path::new(src);
    let dest_path = Path::new(dest);

    if !src_path.exists() {
        return Err(anyhow::anyhow!("Source directory does not exist: {}", src));
    }

    if !src_path.is_dir() {
        return Err(anyhow::anyhow!("Source is not a directory: {}", src));
    }

    // Create destination directory
    fs::create_dir_all(dest_path)
        .with_context(|| format!("Failed to create destination directory: {}", dest))?;

    copy_dir_recursive(src_path, dest_path)?;

    Ok(())
}

/// Create a directory (and all parent directories)
pub fn create_directory(path: &str) -> AnyhowResult<()> {
    let dir_path = Path::new(path);

    fs::create_dir_all(dir_path)
        .with_context(|| format!("Failed to create directory: {}", path))?;

    Ok(())
}

/// Recursively copy directory contents
fn copy_dir_recursive(src: &Path, dest: &Path) -> AnyhowResult<()> {
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let src_path = entry.path();
        let dest_path = dest.join(entry.file_name());

        if src_path.is_dir() {
            fs::create_dir_all(&dest_path)?;
            copy_dir_recursive(&src_path, &dest_path)?;
        } else {
            fs::copy(&src_path, &dest_path)?;
        }
    }

    Ok(())
}

#[derive(serde::Deserialize, serde::Serialize)]
pub struct WorkspaceConfig {
    pub work_dir: String,
    pub workspace_type: String,
    pub sources: Vec<FileSpec>,
    pub headers: Vec<FileSpec>,
    pub dependencies: Vec<FileSpec>,
    pub bindings_dir: Option<String>,
}

#[derive(serde::Deserialize, serde::Serialize)]
pub struct FileSpec {
    pub source: String,
    pub destination: Option<String>,
    pub preserve_permissions: Option<bool>,
}

#[derive(serde::Serialize)]
pub struct WorkspaceInfo {
    pub workspace_path: String,
    pub prepared_files: Vec<String>,
    pub preparation_time_ms: u64,
    pub message: String,
}

/// Prepare a complete workspace according to configuration
pub fn prepare_workspace(config: &WorkspaceConfig) -> AnyhowResult<WorkspaceInfo> {
    let start_time = std::time::Instant::now();
    let mut prepared_files = Vec::new();

    // Create working directory
    create_directory(&config.work_dir)?;

    // Copy source files
    for source in &config.sources {
        let dest_name = source
            .destination
            .as_ref()
            .map(|s| s.as_str())
            .unwrap_or_else(|| {
                Path::new(&source.source)
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("unknown")
            });
        let dest_path = Path::new(&config.work_dir).join(dest_name);

        copy_file(&source.source, dest_path.to_str().unwrap())?;
        prepared_files.push(dest_path.to_string_lossy().to_string());
    }

    // Copy header files
    for header in &config.headers {
        let dest_name = header
            .destination
            .as_ref()
            .map(|s| s.as_str())
            .unwrap_or_else(|| {
                Path::new(&header.source)
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("unknown")
            });
        let dest_path = Path::new(&config.work_dir).join(dest_name);

        copy_file(&header.source, dest_path.to_str().unwrap())?;
        prepared_files.push(dest_path.to_string_lossy().to_string());
    }

    // Copy dependencies
    for dep in &config.dependencies {
        let dest_name = dep
            .destination
            .as_ref()
            .map(|s| s.as_str())
            .unwrap_or_else(|| {
                Path::new(&dep.source)
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("unknown")
            });
        let dest_path = Path::new(&config.work_dir).join(dest_name);

        copy_file(&dep.source, dest_path.to_str().unwrap())?;
        prepared_files.push(dest_path.to_string_lossy().to_string());
    }

    // Copy bindings directory if specified
    if let Some(bindings_dir) = &config.bindings_dir {
        if Path::new(bindings_dir).exists() {
            copy_directory(bindings_dir, &config.work_dir)?;
            prepared_files.push(format!("{}/* (bindings)", config.work_dir));
        }
    }

    let duration = start_time.elapsed();
    let file_count = prepared_files.len();

    Ok(WorkspaceInfo {
        workspace_path: config.work_dir.clone(),
        prepared_files,
        preparation_time_ms: duration.as_millis() as u64,
        message: format!(
            "Successfully prepared {} workspace with {} files",
            config.workspace_type, file_count
        ),
    })
}

// JSON Batch Operations Support

/// JSON operation request
#[derive(serde::Deserialize, serde::Serialize, Debug, Clone)]
pub struct JsonOperation {
    pub operation: String,
    pub source: Option<String>,
    pub destination: Option<String>,
    pub content: Option<String>,
}

/// JSON batch request
#[derive(serde::Deserialize, Debug)]
pub struct JsonBatchRequest {
    pub operations: Vec<JsonOperation>,
}

/// JSON operation result
#[derive(serde::Serialize, Debug, Clone)]
pub struct JsonOperationResult {
    pub success: bool,
    pub message: String,
    pub output: Option<String>,
}

/// JSON batch response
#[derive(serde::Serialize, Debug)]
pub struct JsonBatchResponse {
    pub success: bool,
    pub results: Vec<JsonOperationResult>,
}

/// Process JSON batch operations
pub fn process_json_batch(request_json: &str) -> AnyhowResult<String> {
    let request: JsonBatchRequest = serde_json::from_str(request_json)?;
    let mut results = Vec::new();
    let mut overall_success = true;

    for op in request.operations {
        let result = execute_json_operation(&op);
        if !result.success {
            overall_success = false;
        }
        results.push(result);
    }

    let response = JsonBatchResponse {
        success: overall_success,
        results,
    };

    Ok(serde_json::to_string(&response)?)
}

/// List files in a directory
fn list_directory(path: &str) -> AnyhowResult<Vec<String>> {
    let mut entries = Vec::new();

    for entry in fs::read_dir(path)? {
        let entry = entry?;
        if let Some(name) = entry.file_name().to_str() {
            entries.push(name.to_string());
        }
    }

    entries.sort();
    Ok(entries)
}

/// Execute a single JSON operation
fn execute_json_operation(op: &JsonOperation) -> JsonOperationResult {
    let result = match op.operation.as_str() {
        "copy_file" => {
            if let (Some(source), Some(dest)) = (&op.source, &op.destination) {
                copy_file(source, dest).map(|_| None)
            } else {
                Err(anyhow::anyhow!("copy_file requires source and destination"))
            }
        }
        "copy_directory" => {
            if let (Some(source), Some(dest)) = (&op.source, &op.destination) {
                copy_directory(source, dest).map(|_| None)
            } else {
                Err(anyhow::anyhow!("copy_directory requires source and destination"))
            }
        }
        "create_directory" => {
            if let Some(dest) = &op.destination {
                create_directory(dest).map(|_| None)
            } else {
                Err(anyhow::anyhow!("create_directory requires destination"))
            }
        }
        "copy_first_matching" => {
            // Copy the first file matching a pattern (e.g., "*.rs") from source dir to destination
            // source = directory to search
            // content = glob pattern (e.g., "*.rs")
            // destination = output file path
            if let (Some(dir), Some(pattern), Some(dest)) = (&op.source, &op.content, &op.destination) {
                match list_directory(dir) {
                    Ok(entries) => {
                        // Simple glob matching: *.ext means ends with .ext
                        let matching: Vec<_> = entries.iter()
                            .filter(|name| {
                                if pattern.starts_with("*.") {
                                    let ext = &pattern[1..]; // Remove *
                                    name.ends_with(ext)
                                } else {
                                    name == &pattern
                                }
                            })
                            .collect();

                        if matching.is_empty() {
                            Err(anyhow::anyhow!("No files matching '{}' found in {}", pattern, dir))
                        } else {
                            // Copy the first match
                            let source_path = Path::new(dir).join(matching[0]);
                            match copy_file(source_path.to_str().unwrap(), dest) {
                                Ok(_) => {
                                    let message = if matching.len() > 1 {
                                        format!("Copied first match '{}' (found {} total)", matching[0], matching.len())
                                    } else {
                                        format!("Copied '{}'", matching[0])
                                    };
                                    Ok(Some(message))
                                }
                                Err(e) => Err(e)
                            }
                        }
                    }
                    Err(e) => Err(e)
                }
            } else {
                Err(anyhow::anyhow!("copy_first_matching requires source (dir), content (pattern), and destination"))
            }
        }
        _ => Err(anyhow::anyhow!("Unknown operation: {}", op.operation)),
    };

    match result {
        Ok(output) => JsonOperationResult {
            success: true,
            message: format!("Operation '{}' completed successfully", op.operation),
            output,
        },
        Err(e) => JsonOperationResult {
            success: false,
            message: format!("Operation '{}' failed: {}", op.operation, e),
            output: None,
        },
    }
}
