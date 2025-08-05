/*! 
Integration tests for the checksum updater tool.

These tests validate the full functionality of the checksum updater including
file operations, JSON validation, and tool execution.
*/

use anyhow::Result;
use checksum_updater_lib::{
    checksum_manager::ChecksumManager,
    update_engine::UpdateEngine,
    validator::ChecksumValidator,
};
use serde_json::Value;
use std::env;
use std::path::PathBuf;
use tempfile::TempDir;
use tokio::fs;

/// Get the workspace root directory for accessing test data
fn get_workspace_root() -> PathBuf {
    // In Bazel tests, we can use the TEST_SRCDIR environment variable
    if let Ok(srcdir) = env::var("TEST_SRCDIR") {
        PathBuf::from(srcdir).join("__main__")
    } else {
        // Fallback for non-Bazel execution
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().parent().unwrap().to_path_buf()
    }
}

/// Test basic checksum manager functionality
#[tokio::test]
async fn test_checksum_manager_basic_operations() -> Result<()> {
    let temp_dir = TempDir::new()?;
    let checksums_dir = temp_dir.path().join("checksums");
    let tools_dir = checksums_dir.join("tools");
    
    fs::create_dir_all(&tools_dir).await?;

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());

    // Test creating a new tool
    let tool_info = manager.create_tool("test-tool", "owner/test-tool").await?;
    assert_eq!(tool_info.tool_name, "test-tool");
    assert_eq!(tool_info.github_repo, "owner/test-tool");
    assert_eq!(tool_info.latest_version, "0.0.0");

    // Test tool existence check
    assert!(manager.tool_exists("test-tool").await);
    assert!(!manager.tool_exists("non-existent-tool").await);

    // Test retrieving tool info
    let retrieved_info = manager.get_tool_info("test-tool").await?;
    assert_eq!(retrieved_info.tool_name, "test-tool");

    // Test listing tools
    let tools = manager.list_all_tools().await?;
    assert!(tools.contains(&"test-tool".to_string()));

    Ok(())
}

/// Test JSON validation functionality
#[tokio::test] 
async fn test_json_validation() -> Result<()> {
    let temp_dir = TempDir::new()?;
    let checksums_dir = temp_dir.path().join("checksums");
    let tools_dir = checksums_dir.join("tools");
    
    fs::create_dir_all(&tools_dir).await?;

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());
    let validator = ChecksumValidator::new();

    // Create a valid tool JSON file
    manager.create_tool("valid-tool", "owner/valid-tool").await?;

    // Create an invalid JSON file
    let invalid_json_path = tools_dir.join("invalid-tool.json");
    fs::write(&invalid_json_path, "{ invalid json content").await?;

    // Test JSON format validation
    let results = validator.validate_json_format(&manager).await?;
    
    // Should have at least one valid file (valid-tool) and detect the invalid one
    assert!(results.valid_checksums >= 1);
    assert!(results.errors.len() >= 1);
    
    // Check that the invalid file was detected
    let has_invalid_error = results.errors.iter().any(|e| {
        e.error_type == "json_format" && e.message.contains("Invalid JSON format")
    });
    assert!(has_invalid_error);

    Ok(())
}

/// Test update engine with mock data
#[tokio::test]
async fn test_update_engine_initialization() -> Result<()> {
    let temp_dir = TempDir::new()?;
    let checksums_dir = temp_dir.path().join("checksums");
    let tools_dir = checksums_dir.join("tools");
    
    fs::create_dir_all(&tools_dir).await?;

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());
    let engine = UpdateEngine::new(manager);

    // Test listing available tools (should include configured tools)
    let tools = engine.list_available_tools().await?;
    
    // Should include at least the tools defined in tool_config
    assert!(!tools.is_empty());
    
    // Should include wasm-tools as it's a configured tool
    assert!(tools.contains(&"wasm-tools".to_string()));

    Ok(())
}

/// Test real JSON file validation if available
#[tokio::test]
async fn test_real_json_files_validation() -> Result<()> {
    let workspace_root = get_workspace_root();
    let checksums_dir = workspace_root.join("checksums");
    let tools_dir = checksums_dir.join("tools");
    
    // Only run this test if the checksums directory exists
    if !checksums_dir.exists() {
        println!("Skipping real JSON validation - checksums directory not found");
        return Ok(());
    }

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());
    let validator = ChecksumValidator::new();

    // Test validation of actual JSON files in the repository
    let results = validator.validate_json_format(&manager).await?;
    
    println!("JSON validation results:");
    println!("  Valid files: {}", results.valid_checksums);
    println!("  Invalid files: {}", results.invalid_checksums);
    println!("  Errors: {}", results.errors.len());

    // Print any errors for debugging
    for error in &results.errors {
        println!("  Error in {}: {}", error.tool_name, error.message);
    }

    // All real JSON files should be valid
    assert_eq!(results.invalid_checksums, 0, "Found invalid JSON files in the repository");

    Ok(())
}

/// Test checksum manager file operations
#[tokio::test]
async fn test_checksum_manager_file_operations() -> Result<()> {
    let temp_dir = TempDir::new()?;
    let checksums_dir = temp_dir.path().join("checksums");
    let tools_dir = checksums_dir.join("tools");
    
    fs::create_dir_all(&tools_dir).await?;

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());

    // Create a tool and verify the JSON file is created correctly
    let _tool_info = manager.create_tool("file-test-tool", "owner/file-test-tool").await?;
    
    // Verify the JSON file exists and has correct content
    let json_path = tools_dir.join("file-test-tool.json");
    assert!(json_path.exists());
    
    let json_content = fs::read_to_string(&json_path).await?;
    let parsed: Value = serde_json::from_str(&json_content)?;
    
    assert_eq!(parsed["tool_name"], "file-test-tool");
    assert_eq!(parsed["github_repo"], "owner/file-test-tool");
    assert_eq!(parsed["latest_version"], "0.0.0");

    // Test updating tool version
    use checksum_updater_lib::checksum_manager::{VersionInfo, PlatformInfo};
    use std::collections::HashMap;
    
    let mut platforms = HashMap::new();
    platforms.insert("linux_amd64".to_string(), PlatformInfo {
        sha256: "test-checksum".to_string(),
        url_suffix: "linux_amd64.tar.gz".to_string(),
        platform_name: None,
    });
    
    let version_info = VersionInfo {
        release_date: "2024-01-01".to_string(),
        platforms,
    };
    
    manager.update_tool_version("file-test-tool", "1.0.0", version_info).await?;
    
    // Verify the update was saved correctly
    let updated_tool_info = manager.get_tool_info("file-test-tool").await?;
    assert_eq!(updated_tool_info.latest_version, "1.0.0");
    assert!(updated_tool_info.versions.contains_key("1.0.0"));

    Ok(())
}

/// Test configuration parsing and tool configuration
#[tokio::test]
async fn test_tool_configuration() -> Result<()> {
    use checksum_updater_lib::tool_config::ToolConfig;
    
    let tool_config = ToolConfig::default();
    
    // Test that we can get configuration for known tools
    let wasm_tools_config = tool_config.get_tool_config("wasm-tools");
    assert_eq!(wasm_tools_config.github_repo, "bytecodealliance/wasm-tools");
    assert!(!wasm_tools_config.platforms.is_empty());
    
    // Test URL generation
    let url = wasm_tools_config.generate_download_url("1.0.0", "linux_amd64")?;
    assert!(url.contains("github.com"));
    assert!(url.contains("bytecodealliance/wasm-tools"));
    assert!(url.contains("1.0.0"));

    Ok(())
}