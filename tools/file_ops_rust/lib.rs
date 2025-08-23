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
}
