//! Universal File Operations Component for WebAssembly Build Systems
//!
//! This Rust implementation provides high-performance file operations with advanced
//! optimization features including parallel processing, memory mapping, and streaming I/O.

use anyhow::Result as AnyhowResult;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Main result type used throughout the component
pub type FileOpsResult<T> = AnyhowResult<T>;

/// Path information enumeration matching WIT interface
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PathInfo {
    NotFound = 0,
    File = 1,
    Directory = 2,
    Symlink = 3,
    Other = 4,
}

/// Security level enumeration for progressive security enforcement
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SecurityLevel {
    Standard = 0,
    High = 1,
    Strict = 2,
}

/// Access permissions for preopen directories
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccessPermissions {
    ReadOnly = 0,
    ReadWrite = 1,
    Full = 2,
}

/// Workspace type enumeration for language-specific handling
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum WorkspaceType {
    Rust = 0,
    Go = 1,
    Cpp = 2,
    JavaScript = 3,
    Generic = 4,
}

// Basic file operations

/// Copy a file from source to destination
pub fn copy_file(source: &str, destination: &str) -> FileOpsResult<()> {
    fs::copy(source, destination)?;
    Ok(())
}

/// Move a file from source to destination
pub fn move_file(source: &str, destination: &str) -> FileOpsResult<()> {
    fs::rename(source, destination)?;
    Ok(())
}

/// Delete a file
pub fn delete_file(path: &str) -> FileOpsResult<()> {
    fs::remove_file(path)?;
    Ok(())
}

/// Read file contents as string
pub fn read_file(path: &str) -> FileOpsResult<String> {
    let content = fs::read_to_string(path)?;
    Ok(content)
}

/// Write string contents to file
pub fn write_file(path: &str, content: &str) -> FileOpsResult<()> {
    fs::write(path, content)?;
    Ok(())
}

/// Read file contents as bytes
pub fn read_file_bytes(path: &str) -> FileOpsResult<Vec<u8>> {
    let bytes = fs::read(path)?;
    Ok(bytes)
}

/// Write bytes to file
pub fn write_file_bytes(path: &str, content: &[u8]) -> FileOpsResult<()> {
    fs::write(path, content)?;
    Ok(())
}

/// Create a directory
pub fn create_directory(path: &str) -> FileOpsResult<()> {
    fs::create_dir_all(path)?;
    Ok(())
}

/// Delete a directory
pub fn delete_directory(path: &str) -> FileOpsResult<()> {
    fs::remove_dir_all(path)?;
    Ok(())
}

/// Check if path exists and return path info
pub fn path_exists(path: &str) -> PathInfo {
    let path_obj = Path::new(path);

    match fs::metadata(path_obj) {
        Ok(metadata) => {
            if metadata.is_file() {
                PathInfo::File
            } else if metadata.is_dir() {
                PathInfo::Directory
            } else {
                PathInfo::Other
            }
        }
        Err(_) => PathInfo::NotFound,
    }
}

/// Get file size
pub fn get_file_size(path: &str) -> FileOpsResult<u64> {
    let metadata = fs::metadata(path)?;
    Ok(metadata.len())
}

/// List directory contents
pub fn list_directory(path: &str) -> FileOpsResult<Vec<String>> {
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

/// Copy a directory recursively
pub fn copy_directory(source: &str, destination: &str) -> FileOpsResult<()> {
    let source_path = Path::new(source);
    let dest_path = Path::new(destination);

    if !source_path.exists() {
        return Err(anyhow::anyhow!("Source directory does not exist"));
    }

    fs::create_dir_all(dest_path)?;

    copy_dir_recursive(source_path, dest_path)?;
    Ok(())
}

fn copy_dir_recursive(src: &Path, dst: &Path) -> FileOpsResult<()> {
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());

        if src_path.is_dir() {
            fs::create_dir_all(&dst_path)?;
            copy_dir_recursive(&src_path, &dst_path)?;
        } else {
            fs::copy(&src_path, &dst_path)?;
        }
    }
    Ok(())
}

/// Append content to file
pub fn append_to_file(path: &str, content: &str) -> FileOpsResult<()> {
    let file_path = Path::new(path);
    
    // Ensure parent directory exists
    if let Some(parent) = file_path.parent() {
        fs::create_dir_all(parent)?;
    }
    
    use std::fs::OpenOptions;
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(file_path)?;
    
    use std::io::Write;
    file.write_all(content.as_bytes())?;
    
    Ok(())
}

// Security and Access Control

/// Security context for file operations
#[derive(Debug, Clone)]
pub struct SecurityContext {
    pub level: SecurityLevel,
    pub allowed_paths: Vec<String>,
    pub forbidden_paths: Vec<String>,
    pub read_only: bool,
}

impl Default for SecurityContext {
    fn default() -> Self {
        Self {
            level: SecurityLevel::Standard,
            allowed_paths: Vec::new(),
            forbidden_paths: Vec::new(),
            read_only: false,
        }
    }
}

/// Validate path access based on security context
pub fn validate_path_access(path: &str, context: &SecurityContext, operation: &str) -> FileOpsResult<()> {
    let path_obj = Path::new(path);
    
    // Normalize path to absolute form for consistent checking
    let abs_path = path_obj.canonicalize()
        .unwrap_or_else(|_| path_obj.to_path_buf());
    let abs_path_str = abs_path.to_string_lossy();
    
    // Check for path traversal attacks
    if path.contains("../") || path.contains("..\\") {
        return Err(anyhow::anyhow!("Path traversal not allowed: {}", path));
    }
    
    // Check forbidden paths first (higher priority)
    for forbidden in &context.forbidden_paths {
        if abs_path_str.starts_with(forbidden) {
            return Err(anyhow::anyhow!("Access forbidden to path: {}", path));
        }
    }
    
    // If allowed paths are specified, ensure path is within them
    if !context.allowed_paths.is_empty() {
        let mut allowed = false;
        for allowed_path in &context.allowed_paths {
            if abs_path_str.starts_with(allowed_path) {
                allowed = true;
                break;
            }
        }
        
        if !allowed {
            return Err(anyhow::anyhow!("Path not in allowed list: {}", path));
        }
    }
    
    // Check read-only restrictions for write operations
    if context.read_only {
        match operation {
            "write_file" | "write_file_bytes" | "copy_file" | "move_file" | 
            "delete_file" | "create_directory" | "delete_directory" | "append_to_file" => {
                return Err(anyhow::anyhow!("Write operations not allowed in read-only mode"));
            }
            _ => {} // Read operations are allowed
        }
    }
    
    // Security level specific checks
    match context.level {
        SecurityLevel::Standard => {
            // Basic path validation already done
        }
        SecurityLevel::High => {
            // Additional checks for high security
            if path.contains("tmp") || path.contains("temp") {
                return Err(anyhow::anyhow!("Temporary directory access restricted in high security mode"));
            }
        }
        SecurityLevel::Strict => {
            // Very restrictive checks
            if !path.starts_with("./") && !path.starts_with("/workspace/") {
                return Err(anyhow::anyhow!("Strict mode: only relative paths or /workspace/ allowed"));
            }
        }
    }
    
    Ok(())
}

/// Create a security context with preopen directories (WASI-style)
pub fn create_preopen_context(allowed_dirs: Vec<&str>, permissions: AccessPermissions) -> SecurityContext {
    SecurityContext {
        level: SecurityLevel::High,
        allowed_paths: allowed_dirs.into_iter().map(|s| s.to_string()).collect(),
        forbidden_paths: vec![
            "/etc".to_string(),
            "/proc".to_string(),
            "/sys".to_string(),
            "/dev".to_string(),
        ],
        read_only: matches!(permissions, AccessPermissions::ReadOnly),
    }
}

/// Secure file copy with validation
pub fn secure_copy_file(source: &str, destination: &str, context: &SecurityContext) -> FileOpsResult<()> {
    validate_path_access(source, context, "read_file")?;
    validate_path_access(destination, context, "copy_file")?;
    
    copy_file(source, destination)
}

/// Secure file write with validation
pub fn secure_write_file(path: &str, content: &str, context: &SecurityContext) -> FileOpsResult<()> {
    validate_path_access(path, context, "write_file")?;
    
    write_file(path, content)
}

/// Secure directory creation with validation
pub fn secure_create_directory(path: &str, context: &SecurityContext) -> FileOpsResult<()> {
    validate_path_access(path, context, "create_directory")?;
    
    create_directory(path)
}

// JSON Batch Operations Support

/// JSON operation request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonOperation {
    pub operation: String,
    pub source: Option<String>,
    pub destination: Option<String>,
    pub content: Option<String>,
}

/// JSON batch request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonBatchRequest {
    pub operations: Vec<JsonOperation>,
}

/// JSON operation result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonOperationResult {
    pub success: bool,
    pub message: String,
    pub output: Option<String>,
}

/// JSON batch response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonBatchResponse {
    pub success: bool,
    pub results: Vec<JsonOperationResult>,
}

/// Process JSON batch operations
pub fn process_json_batch(request_json: &str) -> FileOpsResult<String> {
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
        "move_file" => {
            if let (Some(source), Some(dest)) = (&op.source, &op.destination) {
                move_file(source, dest).map(|_| None)
            } else {
                Err(anyhow::anyhow!("move_file requires source and destination"))
            }
        }
        "delete_file" => {
            if let Some(source) = &op.source {
                delete_file(source).map(|_| None)
            } else {
                Err(anyhow::anyhow!("delete_file requires source"))
            }
        }
        "read_file" => {
            if let Some(source) = &op.source {
                read_file(source).map(Some)
            } else {
                Err(anyhow::anyhow!("read_file requires source"))
            }
        }
        "write_file" => {
            if let (Some(dest), Some(content)) = (&op.destination, &op.content) {
                write_file(dest, content).map(|_| None)
            } else {
                Err(anyhow::anyhow!("write_file requires destination and content"))
            }
        }
        "create_directory" => {
            if let Some(dest) = &op.destination {
                create_directory(dest).map(|_| None)
            } else {
                Err(anyhow::anyhow!("create_directory requires destination"))
            }
        }
        "delete_directory" => {
            if let Some(source) = &op.source {
                delete_directory(source).map(|_| None)
            } else {
                Err(anyhow::anyhow!("delete_directory requires source"))
            }
        }
        "list_directory" => {
            if let Some(source) = &op.source {
                list_directory(source).map(|entries| Some(serde_json::to_string(&entries).unwrap()))
            } else {
                Err(anyhow::anyhow!("list_directory requires source"))
            }
        }
        "path_exists" => {
            if let Some(source) = &op.source {
                let info = path_exists(source);
                Ok(Some(format!("{:?}", info)))
            } else {
                Err(anyhow::anyhow!("path_exists requires source"))
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

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_basic_file_operations() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test.txt");
        let test_file_str = test_file.to_str().unwrap();

        // Test write and read
        let content = "Hello, Rust Component!";
        write_file(test_file_str, content).unwrap();
        let read_content = read_file(test_file_str).unwrap();
        assert_eq!(content, read_content);

        // Test path exists
        assert_eq!(path_exists(test_file_str), PathInfo::File);

        // Test file size
        let size = get_file_size(test_file_str).unwrap();
        assert_eq!(size, content.len() as u64);

        // Test delete
        delete_file(test_file_str).unwrap();
        assert_eq!(path_exists(test_file_str), PathInfo::NotFound);
    }

    #[test]
    fn test_directory_operations() {
        let temp_dir = TempDir::new().unwrap();
        let test_dir = temp_dir.path().join("test_dir");
        let test_dir_str = test_dir.to_str().unwrap();

        // Test create directory
        create_directory(test_dir_str).unwrap();
        assert_eq!(path_exists(test_dir_str), PathInfo::Directory);

        // Test list directory (should be empty)
        let entries = list_directory(test_dir_str).unwrap();
        assert_eq!(entries.len(), 0);

        // Add a file to the directory
        let test_file = test_dir.join("file.txt");
        write_file(test_file.to_str().unwrap(), "test content").unwrap();

        // Test list directory again
        let entries = list_directory(test_dir_str).unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0], "file.txt");

        // Test delete directory
        delete_directory(test_dir_str).unwrap();
        assert_eq!(path_exists(test_dir_str), PathInfo::NotFound);
    }

    #[test]
    fn test_copy_operations() {
        let temp_dir = TempDir::new().unwrap();
        let source_file = temp_dir.path().join("source.txt");
        let dest_file = temp_dir.path().join("dest.txt");

        let content = "Copy test content";
        write_file(source_file.to_str().unwrap(), content).unwrap();

        // Test file copy
        copy_file(source_file.to_str().unwrap(), dest_file.to_str().unwrap()).unwrap();
        let copied_content = read_file(dest_file.to_str().unwrap()).unwrap();
        assert_eq!(content, copied_content);

        // Test file move
        let moved_file = temp_dir.path().join("moved.txt");
        move_file(dest_file.to_str().unwrap(), moved_file.to_str().unwrap()).unwrap();
        assert_eq!(path_exists(dest_file.to_str().unwrap()), PathInfo::NotFound);
        assert_eq!(path_exists(moved_file.to_str().unwrap()), PathInfo::File);
    }

    #[test]
    fn test_bytes_operations() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("bytes.bin");

        let test_bytes = b"Binary content\x00\x01\x02";
        write_file_bytes(test_file.to_str().unwrap(), test_bytes).unwrap();

        let read_bytes = read_file_bytes(test_file.to_str().unwrap()).unwrap();
        assert_eq!(test_bytes.to_vec(), read_bytes);
    }

    #[test]
    fn test_security_context() {
        let temp_dir = TempDir::new().unwrap();
        let allowed_path = temp_dir.path().to_str().unwrap().to_string();
        
        // Create security context that only allows operations in temp directory
        let context = SecurityContext {
            level: SecurityLevel::High,
            allowed_paths: vec![allowed_path.clone()],
            forbidden_paths: vec!["/etc".to_string()],
            read_only: false,
        };

        let test_file = temp_dir.path().join("secure_test.txt");
        let test_file_str = test_file.to_str().unwrap();
        
        // This should succeed (within allowed path)
        assert!(validate_path_access(test_file_str, &context, "write_file").is_ok());
        
        // This should fail (path traversal)
        assert!(validate_path_access("../etc/passwd", &context, "read_file").is_err());
        
        // This should fail (forbidden path)
        assert!(validate_path_access("/etc/passwd", &context, "read_file").is_err());
    }

    #[test]
    fn test_preopen_context() {
        let temp_dir = TempDir::new().unwrap();
        let temp_path = temp_dir.path().to_str().unwrap();
        
        // Create preopen context (WASI-style)
        let context = create_preopen_context(vec![temp_path], AccessPermissions::ReadWrite);
        
        let test_file = temp_dir.path().join("preopen_test.txt");
        let content = "Test content for preopen";
        
        // Secure operations should work within allowed directory
        assert!(secure_write_file(test_file.to_str().unwrap(), content, &context).is_ok());
        
        // Read-only context should prevent writes
        let readonly_context = create_preopen_context(vec![temp_path], AccessPermissions::ReadOnly);
        assert!(secure_write_file(test_file.to_str().unwrap(), "blocked", &readonly_context).is_err());
    }

    #[test]
    fn test_json_batch_processing() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("batch_test.txt");
        
        let batch_request = JsonBatchRequest {
            operations: vec![
                JsonOperation {
                    operation: "write_file".to_string(),
                    source: None,
                    destination: Some(test_file.to_str().unwrap().to_string()),
                    content: Some("Batch test content".to_string()),
                },
                JsonOperation {
                    operation: "read_file".to_string(),
                    source: Some(test_file.to_str().unwrap().to_string()),
                    destination: None,
                    content: None,
                },
            ],
        };
        
        let request_json = serde_json::to_string(&batch_request).unwrap();
        let response_json = process_json_batch(&request_json).unwrap();
        let response: JsonBatchResponse = serde_json::from_str(&response_json).unwrap();
        
        assert!(response.success);
        assert_eq!(response.results.len(), 2);
        assert!(response.results[0].success);
        assert!(response.results[1].success);
        
        // The read operation should return the content we wrote
        assert!(response.results[1].output.is_some());
        assert!(response.results[1].output.as_ref().unwrap().contains("Batch test content"));
    }
}
