//! Universal File Operations Component for WebAssembly Build Systems
//!
//! This component provides cross-platform file operations that replace
//! platform-specific shell scripts in build systems like Bazel.

use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

use anyhow::{Context, Result as AnyhowResult};

// Generate bindings from WIT
wit_bindgen::generate!({
    world: "file-ops-world",
    path: "../wit/file-operations.wit"
});

use exports::build::file_ops::file_operations::{Guest as FileOpsGuest, PathInfo};
use exports::build::file_ops::workspace_management::{Guest as WorkspaceGuest, WorkspaceInfo, WorkspaceConfig, FileSpec, PackageConfig, GoModuleConfig, CppWorkspaceConfig, WorkspaceType};

struct FileOperationsComponent;

impl FileOpsGuest for FileOperationsComponent {
    fn copy_file(src: String, dest: String) -> Result<(), String> {
        let src_path = Path::new(&src);
        let dest_path = Path::new(&dest);
        
        if !src_path.exists() {
            return Err(format!("Source file does not exist: {}", src));
        }
        
        // Create parent directory if it doesn't exist
        if let Some(parent) = dest_path.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("Failed to create parent directory: {}", e))?;
        }
        
        fs::copy(src_path, dest_path)
            .map_err(|e| format!("Failed to copy file: {}", e))?;
            
        Ok(())
    }
    
    fn copy_directory(src: String, dest: String) -> Result<(), String> {
        let src_path = Path::new(&src);
        let dest_path = Path::new(&dest);
        
        if !src_path.exists() {
            return Err(format!("Source directory does not exist: {}", src));
        }
        
        if !src_path.is_dir() {
            return Err(format!("Source is not a directory: {}", src));
        }
        
        copy_dir_recursive(src_path, dest_path)
            .map_err(|e| format!("Failed to copy directory: {}", e))
    }
    
    fn create_directory(path: String) -> Result<(), String> {
        fs::create_dir_all(&path)
            .map_err(|e| format!("Failed to create directory {}: {}", path, e))
    }
    
    fn remove_path(path: String) -> Result<(), String> {
        let path_obj = Path::new(&path);
        
        if !path_obj.exists() {
            return Ok(()); // Already doesn't exist
        }
        
        if path_obj.is_dir() {
            fs::remove_dir_all(&path)
                .map_err(|e| format!("Failed to remove directory {}: {}", path, e))
        } else {
            fs::remove_file(&path)
                .map_err(|e| format!("Failed to remove file {}: {}", path, e))
        }
    }
    
    fn path_exists(path: String) -> PathInfo {
        let path_obj = Path::new(&path);
        
        if !path_obj.exists() {
            return PathInfo::NotFound;
        }
        
        if path_obj.is_file() {
            PathInfo::File
        } else if path_obj.is_dir() {
            PathInfo::Directory
        } else if path_obj.is_symlink() {
            PathInfo::Symlink
        } else {
            PathInfo::Other
        }
    }
    
    fn resolve_absolute_path(path: String) -> Result<String, String> {
        let path_obj = Path::new(&path);
        
        match path_obj.canonicalize() {
            Ok(absolute_path) => Ok(absolute_path.to_string_lossy().to_string()),
            Err(_) => {
                // If canonicalize fails (e.g., path doesn't exist), try to resolve manually
                let current_dir = std::env::current_dir()
                    .map_err(|e| format!("Failed to get current directory: {}", e))?;
                    
                let resolved = if path_obj.is_absolute() {
                    path_obj.to_path_buf()
                } else {
                    current_dir.join(path_obj)
                };
                
                Ok(resolved.to_string_lossy().to_string())
            }
        }
    }
    
    fn join_paths(paths: Vec<String>) -> String {
        let path_buf = paths.iter().fold(PathBuf::new(), |acc, p| acc.join(p));
        path_buf.to_string_lossy().to_string()
    }
    
    fn get_dirname(path: String) -> String {
        Path::new(&path)
            .parent()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_else(|| ".".to_string())
    }
    
    fn get_basename(path: String) -> String {
        Path::new(&path)
            .file_name()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_else(|| path)
    }
    
    fn list_directory(dir: String, pattern: Option<String>) -> Result<Vec<String>, String> {
        let dir_path = Path::new(&dir);
        
        if !dir_path.exists() {
            return Err(format!("Directory does not exist: {}", dir));
        }
        
        if !dir_path.is_dir() {
            return Err(format!("Path is not a directory: {}", dir));
        }
        
        let entries = fs::read_dir(dir_path)
            .map_err(|e| format!("Failed to read directory: {}", e))?;
            
        let mut files = Vec::new();
        
        for entry in entries {
            let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
            let file_name = entry.file_name().to_string_lossy().to_string();
            
            // Apply pattern filter if provided
            if let Some(ref pattern) = pattern {
                if !simple_pattern_match(&file_name, pattern) {
                    continue;
                }
            }
            
            files.push(file_name);
        }
        
        files.sort();
        Ok(files)
    }
}

impl WorkspaceGuest for FileOperationsComponent {
    fn prepare_workspace(config: WorkspaceConfig) -> Result<WorkspaceInfo, String> {
        let start_time = Instant::now();
        let mut prepared_files = Vec::new();
        
        // Create the workspace directory
        Self::create_directory(config.work_dir.clone())?;
        
        // Copy sources
        for source in config.sources {
            let dest_path = if let Some(dest) = source.destination {
                format!("{}/{}", config.work_dir, dest)
            } else {
                let basename = Self::get_basename(source.source.clone());
                format!("{}/{}", config.work_dir, basename)
            };
            
            Self::copy_file(source.source.clone(), dest_path.clone())?;
            prepared_files.push(dest_path);
        }
        
        // Copy headers
        for header in config.headers {
            let dest_path = if let Some(dest) = header.destination {
                format!("{}/{}", config.work_dir, dest)
            } else {
                let basename = Self::get_basename(header.source.clone());
                format!("{}/{}", config.work_dir, basename)
            };
            
            Self::copy_file(header.source.clone(), dest_path.clone())?;
            prepared_files.push(dest_path);
        }
        
        // Copy bindings if provided
        if let Some(bindings_dir) = config.bindings_dir {
            Self::copy_directory(bindings_dir, format!("{}/bindings", config.work_dir))?;
            prepared_files.push(format!("{}/bindings", config.work_dir));
        }
        
        // Copy dependencies
        for dep in config.dependencies {
            let dest_path = if let Some(dest) = dep.destination {
                format!("{}/{}", config.work_dir, dest)
            } else {
                let basename = Self::get_basename(dep.source.clone());
                format!("{}/{}", config.work_dir, basename)
            };
            
            Self::copy_file(dep.source.clone(), dest_path.clone())?;
            prepared_files.push(dest_path);
        }
        
        // Language-specific setup
        match config.workspace_type {
            WorkspaceType::Go => {
                // Additional Go-specific setup can be added here
            },
            WorkspaceType::Cpp => {
                // Additional C++-specific setup can be added here
            },
            WorkspaceType::Javascript => {
                // Additional JavaScript-specific setup can be added here
            },
            _ => {
                // Generic setup
            }
        }
        
        let elapsed = start_time.elapsed();
        
        Ok(WorkspaceInfo {
            prepared_files,
            workspace_path: config.work_dir,
            message: format!("Workspace prepared successfully with {} files", prepared_files.len()),
            preparation_time_ms: elapsed.as_millis() as u64,
        })
    }
    
    fn copy_sources(sources: Vec<FileSpec>, dest_dir: String) -> Result<(), String> {
        Self::create_directory(dest_dir.clone())?;
        
        for source in sources {
            let dest_path = if let Some(dest) = source.destination {
                format!("{}/{}", dest_dir, dest)
            } else {
                let basename = Self::get_basename(source.source.clone());
                format!("{}/{}", dest_dir, basename)
            };
            
            Self::copy_file(source.source, dest_path)?;
        }
        
        Ok(())
    }
    
    fn copy_headers(headers: Vec<FileSpec>, dest_dir: String) -> Result<(), String> {
        Self::copy_sources(headers, dest_dir)
    }
    
    fn copy_bindings(bindings_dir: String, dest_dir: String) -> Result<(), String> {
        Self::copy_directory(bindings_dir, dest_dir)
    }
    
    fn setup_package_json(config: PackageConfig, work_dir: String) -> Result<(), String> {
        let package_json_path = format!("{}/package.json", work_dir);
        
        let mut package_json = serde_json::json!({
            "name": config.name,
            "version": config.version,
            "type": config.module_type,
        });
        
        // Add dependencies
        if !config.dependencies.is_empty() {
            let deps: serde_json::Map<String, serde_json::Value> = config.dependencies
                .into_iter()
                .map(|dep| (dep.name, serde_json::Value::String(dep.version)))
                .collect();
            package_json["dependencies"] = serde_json::Value::Object(deps);
        }
        
        // Add additional fields
        for field in config.additional_fields {
            let value: serde_json::Value = serde_json::from_str(&field.value)
                .map_err(|e| format!("Invalid JSON in field '{}': {}", field.key, e))?;
            package_json[field.key] = value;
        }
        
        let content = serde_json::to_string_pretty(&package_json)
            .map_err(|e| format!("Failed to serialize package.json: {}", e))?;
            
        fs::write(package_json_path, content)
            .map_err(|e| format!("Failed to write package.json: {}", e))
    }
    
    fn setup_go_module(config: GoModuleConfig, work_dir: String) -> Result<(), String> {
        Self::create_directory(work_dir.clone())?;
        
        // Copy source files
        for source in config.sources {
            let dest_path = if let Some(dest) = source.destination {
                format!("{}/{}", work_dir, dest)
            } else {
                let basename = Self::get_basename(source.source.clone());
                format!("{}/{}", work_dir, basename)
            };
            
            Self::copy_file(source.source, dest_path)?;
        }
        
        // Copy go.mod if provided
        if let Some(go_mod) = config.go_mod_file {
            Self::copy_file(go_mod, format!("{}/go.mod", work_dir))?;
        }
        
        // Copy WIT file if provided
        if let Some(wit_file) = config.wit_file {
            Self::copy_file(wit_file, format!("{}/component.wit", work_dir))?;
        }
        
        Ok(())
    }
    
    fn setup_cpp_workspace(config: CppWorkspaceConfig, work_dir: String) -> Result<(), String> {
        Self::create_directory(work_dir.clone())?;
        
        // Copy source files
        for source in config.sources {
            let dest_path = if let Some(dest) = source.destination {
                format!("{}/{}", work_dir, dest)
            } else {
                let basename = Self::get_basename(source.source.clone());
                format!("{}/{}", work_dir, basename)
            };
            
            Self::copy_file(source.source, dest_path)?;
        }
        
        // Copy header files
        for header in config.headers {
            let dest_path = if let Some(dest) = header.destination {
                format!("{}/{}", work_dir, dest)
            } else {
                let basename = Self::get_basename(header.source.clone());
                format!("{}/{}", work_dir, basename)
            };
            
            Self::copy_file(header.source, dest_path)?;
        }
        
        // Copy generated bindings
        if let Some(bindings_dir) = config.bindings_dir {
            Self::copy_directory(bindings_dir, format!("{}/bindings", work_dir))?;
        }
        
        // Copy dependency headers
        for dep_header in config.dependency_headers {
            let dest_path = if let Some(dest) = dep_header.destination {
                format!("{}/{}", work_dir, dest)
            } else {
                let basename = Self::get_basename(dep_header.source.clone());
                format!("{}/{}", work_dir, basename)
            };
            
            Self::copy_file(dep_header.source, dest_path)?;
        }
        
        Ok(())
    }
}

// Export the implementation
export!(FileOperationsComponent);

// Helper functions

fn copy_dir_recursive(src: &Path, dest: &Path) -> AnyhowResult<()> {
    fs::create_dir_all(dest).context("Failed to create destination directory")?;
    
    for entry in walkdir::WalkDir::new(src) {
        let entry = entry.context("Failed to read directory entry")?;
        let src_path = entry.path();
        let relative_path = src_path.strip_prefix(src)
            .context("Failed to get relative path")?;
        let dest_path = dest.join(relative_path);
        
        if src_path.is_dir() {
            fs::create_dir_all(&dest_path)
                .with_context(|| format!("Failed to create directory: {:?}", dest_path))?;
        } else {
            if let Some(parent) = dest_path.parent() {
                fs::create_dir_all(parent)
                    .with_context(|| format!("Failed to create parent directory: {:?}", parent))?;
            }
            
            fs::copy(src_path, &dest_path)
                .with_context(|| format!("Failed to copy file: {:?} -> {:?}", src_path, dest_path))?;
                
            // Preserve file times
            if let Ok(metadata) = src_path.metadata() {
                let mtime = filetime::FileTime::from_last_modification_time(&metadata);
                let atime = filetime::FileTime::from_last_access_time(&metadata);
                let _ = filetime::set_file_times(&dest_path, atime, mtime);
            }
        }
    }
    
    Ok(())
}

fn simple_pattern_match(text: &str, pattern: &str) -> bool {
    // Simple glob-style pattern matching for *, ?, and literal strings
    if pattern == "*" {
        return true;
    }
    
    if pattern.contains('*') || pattern.contains('?') {
        // For now, implement simple prefix/suffix matching
        if pattern.starts_with('*') && pattern.ends_with('*') {
            let middle = &pattern[1..pattern.len()-1];
            text.contains(middle)
        } else if pattern.starts_with('*') {
            let suffix = &pattern[1..];
            text.ends_with(suffix)
        } else if pattern.ends_with('*') {
            let prefix = &pattern[..pattern.len()-1];
            text.starts_with(prefix)
        } else {
            // More complex patterns - for now just do literal match
            text == pattern
        }
    } else {
        text == pattern
    }
}