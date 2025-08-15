/*!
JSON validation tests for the checksum updater tool.

These tests specifically validate JSON file formats and ensure all tool
registry files are properly structured and valid.
*/

use anyhow::Result;
use checksum_updater_lib::checksum_manager::ChecksumManager;
use serde_json::Value;
use std::env;
use std::path::PathBuf;
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

/// Test that all JSON schema requirements are met
#[tokio::test]
async fn test_json_schema_validation() -> Result<()> {
    let workspace_root = get_workspace_root();
    let checksums_dir = workspace_root.join("checksums");
    let tools_dir = checksums_dir.join("tools");

    // Only run if the tools directory exists
    if !tools_dir.exists() {
        println!("Skipping JSON schema validation - tools directory not found");
        return Ok(());
    }

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());
    let tools = manager.list_all_tools().await?;

    for tool_name in &tools {
        println!("Validating JSON schema for: {}", tool_name);

        let tool_info = manager.get_tool_info(&tool_name).await
            .map_err(|e| anyhow::anyhow!("Failed to parse {}: {}", tool_name, e))?;

        // Validate required fields
        assert!(!tool_info.tool_name.is_empty(), "Tool name cannot be empty for {}", tool_name);
        assert!(!tool_info.github_repo.is_empty(), "GitHub repo cannot be empty for {}", tool_name);
        assert!(!tool_info.latest_version.is_empty(), "Latest version cannot be empty for {}", tool_name);

        // Validate GitHub repo format (should be owner/repo)
        assert!(
            tool_info.github_repo.contains('/'),
            "GitHub repo should be in owner/repo format for {}: {}",
            tool_name,
            tool_info.github_repo
        );

        // Validate version format (should be semantic version)
        if tool_info.latest_version != "0.0.0" {
            semver::Version::parse(&tool_info.latest_version)
                .map_err(|e| anyhow::anyhow!("Invalid version format for {}: {} ({})", tool_name, tool_info.latest_version, e))?;
        }

        // Validate that versions contain the latest version
        if !tool_info.versions.is_empty() {
            assert!(
                tool_info.versions.contains_key(&tool_info.latest_version),
                "Latest version {} not found in versions map for {}",
                tool_info.latest_version,
                tool_name
            );
        }

        // Validate each version's data
        for (version, version_info) in &tool_info.versions {
            // Validate version format
            if version != "0.0.0" {
                semver::Version::parse(version)
                    .map_err(|e| anyhow::anyhow!("Invalid version format for {} {}: {}", tool_name, version, e))?;
            }

            // Validate release date format (YYYY-MM-DD)
            let date_parts: Vec<&str> = version_info.release_date.split('-').collect();
            assert_eq!(
                date_parts.len(), 3,
                "Release date should be YYYY-MM-DD format for {} {}: {}",
                tool_name, version, version_info.release_date
            );

            // Validate platforms
            assert!(
                !version_info.platforms.is_empty(),
                "Platforms cannot be empty for {} {}",
                tool_name, version
            );

            for (platform, platform_info) in &version_info.platforms {
                // Validate platform name format
                assert!(
                    platform.contains('-'),
                    "Platform should be in format like 'linux-x64' for {} {} {}",
                    tool_name, version, platform
                );

                // Validate SHA256 checksum format (64 hex characters)
                assert_eq!(
                    platform_info.sha256.len(), 64,
                    "SHA256 should be 64 characters for {} {} {}: {}",
                    tool_name, version, platform, platform_info.sha256
                );

                assert!(
                    platform_info.sha256.chars().all(|c| c.is_ascii_hexdigit()),
                    "SHA256 should contain only hex characters for {} {} {}: {}",
                    tool_name, version, platform, platform_info.sha256
                );

                // Validate that either url_suffix or platform_name is present
                if platform_info.platform_name.is_none() {
                    assert!(
                        !platform_info.url_suffix.is_empty(),
                        "Either platform_name or url_suffix must be present for {} {} {}",
                        tool_name, version, platform
                    );
                }
            }
        }
    }

    println!("All {} JSON files passed schema validation", tools.len());
    Ok(())
}

/// Test JSON formatting and consistency
#[tokio::test]
async fn test_json_formatting() -> Result<()> {
    let workspace_root = get_workspace_root();
    let checksums_dir = workspace_root.join("checksums");
    let tools_dir = checksums_dir.join("tools");

    // Only run if the tools directory exists
    if !tools_dir.exists() {
        println!("Skipping JSON formatting validation - tools directory not found");
        return Ok(());
    }

    let mut read_dir = fs::read_dir(&tools_dir).await?;
    let mut json_files = Vec::new();

    while let Some(entry) = read_dir.next_entry().await? {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) == Some("json") {
            json_files.push(path);
        }
    }

    for json_path in json_files {
        let file_name = json_path.file_name().unwrap().to_string_lossy();
        println!("Validating JSON formatting for: {}", file_name);

        let content = fs::read_to_string(&json_path).await?;

        // Validate that the JSON parses correctly
        let parsed: Value = serde_json::from_str(&content)
            .map_err(|e| anyhow::anyhow!("Invalid JSON in {}: {}", file_name, e))?;

        // Validate that it's a JSON object
        assert!(
            parsed.is_object(),
            "JSON file should contain an object at root for {}",
            file_name
        );

        // Validate consistent formatting by re-serializing
        let reformatted = serde_json::to_string_pretty(&parsed)?;

        // Check that the reformatted version is valid JSON too
        let _reparsed: Value = serde_json::from_str(&reformatted)
            .map_err(|e| anyhow::anyhow!("Reformatted JSON is invalid for {}: {}", file_name, e))?;

        // Validate required root fields exist
        let obj = parsed.as_object().unwrap();
        assert!(obj.contains_key("tool_name"), "Missing tool_name in {}", file_name);
        assert!(obj.contains_key("github_repo"), "Missing github_repo in {}", file_name);
        assert!(obj.contains_key("latest_version"), "Missing latest_version in {}", file_name);
        assert!(obj.contains_key("versions"), "Missing versions in {}", file_name);

        // Validate that versions is an object
        assert!(
            obj["versions"].is_object(),
            "versions should be an object in {}",
            file_name
        );
    }

    println!("All JSON files passed formatting validation");
    Ok(())
}

/// Test consistency between tool names and file names
#[tokio::test]
async fn test_tool_name_consistency() -> Result<()> {
    let workspace_root = get_workspace_root();
    let checksums_dir = workspace_root.join("checksums");
    let tools_dir = checksums_dir.join("tools");

    // Only run if the tools directory exists
    if !tools_dir.exists() {
        println!("Skipping tool name consistency validation - tools directory not found");
        return Ok(());
    }

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());
    let tools = manager.list_all_tools().await?;

    for tool_name in &tools {
        let tool_info = manager.get_tool_info(&tool_name).await?;

        // Validate that the tool_name in the JSON matches the file name
        assert_eq!(
            tool_info.tool_name, *tool_name,
            "Tool name in JSON ({}) doesn't match file name ({})",
            tool_info.tool_name, tool_name
        );

        // Validate file naming convention
        let expected_file_name = format!("{}.json", tool_name);
        let file_path = tools_dir.join(&expected_file_name);
        assert!(
            file_path.exists(),
            "Expected file {} should exist for tool {}",
            expected_file_name, tool_name
        );
    }

    println!("All tool names are consistent with file names");
    Ok(())
}

/// Test that all checksums are valid SHA256 hashes
#[tokio::test]
async fn test_checksum_validity() -> Result<()> {
    let workspace_root = get_workspace_root();
    let checksums_dir = workspace_root.join("checksums");
    let tools_dir = checksums_dir.join("tools");

    // Only run if the checksums directory exists
    if !checksums_dir.exists() {
        println!("Skipping checksum validity validation - checksums directory not found");
        return Ok(());
    }

    let manager = ChecksumManager::new_with_paths(checksums_dir.clone(), tools_dir.clone());
    let tools = manager.list_all_tools().await?;

    let mut total_checksums = 0;
    let mut valid_checksums = 0;

    for tool_name in &tools {
        let tool_info = manager.get_tool_info(&tool_name).await?;

        for (version, version_info) in &tool_info.versions {
            for (platform, platform_info) in &version_info.platforms {
                total_checksums += 1;

                // Validate SHA256 format
                let checksum = &platform_info.sha256;

                // Should be exactly 64 characters
                assert_eq!(
                    checksum.len(), 64,
                    "Invalid SHA256 length for {} {} {}: {} (should be 64 chars)",
                    tool_name, version, platform, checksum
                );

                // Should contain only hexadecimal characters
                assert!(
                    checksum.chars().all(|c| c.is_ascii_hexdigit()),
                    "Invalid SHA256 format for {} {} {}: {} (should be hex only)",
                    tool_name, version, platform, checksum
                );

                // Should be lowercase (standard convention)
                assert_eq!(
                    checksum, &checksum.to_lowercase(),
                    "SHA256 should be lowercase for {} {} {}: {}",
                    tool_name, version, platform, checksum
                );

                valid_checksums += 1;
            }
        }
    }

    println!("Validated {} checksums across all tools", total_checksums);
    assert_eq!(total_checksums, valid_checksums, "All checksums should be valid");

    Ok(())
}
