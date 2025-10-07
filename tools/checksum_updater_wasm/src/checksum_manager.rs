/*!
Checksum management for WebAssembly tools.

This module handles reading, writing, and managing checksum data in JSON format.
*/

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use tokio::fs;
use tracing::{debug, info, warn};

/// Tool information from the JSON registry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolInfo {
    pub tool_name: String,
    pub github_repo: String,
    pub latest_version: String,
    pub last_checked: DateTime<Utc>,
    pub versions: HashMap<String, VersionInfo>,
    #[serde(default)]
    pub supported_platforms: Vec<String>,
}

/// Version-specific information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VersionInfo {
    pub release_date: String,
    pub platforms: HashMap<String, PlatformInfo>,
}

/// Platform-specific checksum and URL information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlatformInfo {
    pub sha256: String,
    pub url_suffix: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub platform_name: Option<String>,
}

/// Manager for checksum data operations
pub struct ChecksumManager {
    checksums_dir: PathBuf,
    tools_dir: PathBuf,
}

impl ChecksumManager {
    /// Create a new checksum manager (native WASIP2 implementation)
    pub async fn new() -> Result<Self> {
        let checksums_dir = Self::find_checksums_directory()?;
        let tools_dir = checksums_dir.join("tools");

        // Ensure directories exist using native std::fs
        std::fs::create_dir_all(&tools_dir).context("Failed to create tools directory")?;

        Ok(Self {
            checksums_dir,
            tools_dir,
        })
    }

    /// Create a new checksum manager with custom paths (for testing)
    pub fn new_with_paths(checksums_dir: PathBuf, tools_dir: PathBuf) -> Self {
        Self {
            checksums_dir,
            tools_dir,
        }
    }

    /// Find the checksums directory in the repository (native WASIP2)
    fn find_checksums_directory() -> Result<PathBuf> {
        let mut current_dir = std::env::current_dir()?;

        // Look for checksums directory up the directory tree
        loop {
            let checksums_path = current_dir.join("checksums");
            if checksums_path.exists() {
                info!("Found checksums directory at: {}", checksums_path.display());
                return Ok(checksums_path);
            }

            if let Some(parent) = current_dir.parent() {
                current_dir = parent.to_path_buf();
            } else {
                break;
            }
        }

        // If not found, use current directory + checksums
        let checksums_path = std::env::current_dir()?.join("checksums");
        warn!(
            "Checksums directory not found, using: {}",
            checksums_path.display()
        );
        Ok(checksums_path)
    }

    /// List all available tools
    pub async fn list_all_tools(&self) -> Result<Vec<String>> {
        let mut tools = Vec::new();
        let mut entries = fs::read_dir(&self.tools_dir).await?;

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) == Some("json") {
                if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                    tools.push(stem.to_string());
                }
            }
        }

        tools.sort();
        debug!("Found {} tools: {:?}", tools.len(), tools);
        Ok(tools)
    }

    /// Get tool information from JSON file
    pub async fn get_tool_info(&self, tool_name: &str) -> Result<ToolInfo> {
        let file_path = self.tools_dir.join(format!("{}.json", tool_name));

        let content = fs::read_to_string(&file_path)
            .await
            .with_context(|| format!("Failed to read tool file: {}", file_path.display()))?;

        let mut tool_info: ToolInfo = serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse JSON for tool: {}", tool_name))?;

        // Extract supported platforms from all versions
        let mut platforms = std::collections::HashSet::new();
        for version_info in tool_info.versions.values() {
            platforms.extend(version_info.platforms.keys().cloned());
        }
        tool_info.supported_platforms = platforms.into_iter().collect();
        tool_info.supported_platforms.sort();

        Ok(tool_info)
    }

    /// Save tool information to JSON file
    pub async fn save_tool_info(&self, tool_info: &ToolInfo) -> Result<()> {
        let file_path = self.tools_dir.join(format!("{}.json", tool_info.tool_name));

        debug!("Saving tool info to: {}", file_path.display());

        let json_content = serde_json::to_string_pretty(tool_info)
            .context("Failed to serialize tool info to JSON")?;

        fs::write(&file_path, json_content)
            .await
            .with_context(|| format!("Failed to write tool file: {}", file_path.display()))?;

        info!("Saved tool info for: {}", tool_info.tool_name);
        Ok(())
    }

    /// Check if a tool exists
    pub async fn tool_exists(&self, tool_name: &str) -> bool {
        let file_path = self.tools_dir.join(format!("{}.json", tool_name));
        file_path.exists()
    }

    /// Create a new tool entry
    pub async fn create_tool(&self, tool_name: &str, github_repo: &str) -> Result<ToolInfo> {
        let tool_info = ToolInfo {
            tool_name: tool_name.to_string(),
            github_repo: github_repo.to_string(),
            latest_version: "0.0.0".to_string(),
            last_checked: Utc::now(),
            versions: HashMap::new(),
            supported_platforms: Vec::new(),
        };

        self.save_tool_info(&tool_info).await?;
        info!("Created new tool: {}", tool_name);
        Ok(tool_info)
    }

    /// Update tool with new version information
    pub async fn update_tool_version(
        &self,
        tool_name: &str,
        version: &str,
        version_info: VersionInfo,
    ) -> Result<()> {
        let mut tool_info = self.get_tool_info(tool_name).await?;

        // Update latest version if newer
        if self.is_newer_version(version, &tool_info.latest_version) {
            tool_info.latest_version = version.to_string();
        }

        // Add/update version info
        tool_info.versions.insert(version.to_string(), version_info);
        tool_info.last_checked = Utc::now();

        self.save_tool_info(&tool_info).await?;
        Ok(())
    }

    /// Check if a version is newer than the current latest
    fn is_newer_version(&self, new_version: &str, current_latest: &str) -> bool {
        match (
            semver::Version::parse(new_version),
            semver::Version::parse(current_latest),
        ) {
            (Ok(new), Ok(current)) => new > current,
            _ => {
                // Fall back to string comparison if semver parsing fails
                new_version > current_latest
            }
        }
    }

    /// Get the checksum for a specific tool, version, and platform
    pub async fn get_checksum(
        &self,
        tool_name: &str,
        version: &str,
        platform: &str,
    ) -> Result<Option<String>> {
        let tool_info = self.get_tool_info(tool_name).await?;

        if let Some(version_info) = tool_info.versions.get(version) {
            if let Some(platform_info) = version_info.platforms.get(platform) {
                return Ok(Some(platform_info.sha256.clone()));
            }
        }

        Ok(None)
    }

    /// Update the registry.bzl file with hardcoded data
    pub async fn update_registry_bzl(&self) -> Result<()> {
        let registry_path = self.checksums_dir.join("registry.bzl");

        debug!("Updating registry.bzl at: {}", registry_path.display());

        // Read current registry file
        let content = if registry_path.exists() {
            fs::read_to_string(&registry_path).await?
        } else {
            String::new()
        };

        // Find the hardcoded data section
        let start_marker = "hardcoded_data = {";
        let end_marker = "    return hardcoded_data.get(tool_name, {})";

        if let Some(start_pos) = content.find(start_marker) {
            if let Some(end_pos) = content.find(end_marker) {
                // Generate new hardcoded data
                let new_data = self.generate_hardcoded_data().await?;

                // Replace the section
                let before = &content[..start_pos];
                let after = &content[end_pos..];
                let new_content = format!("{}{}\n\n{}", before, new_data, after);

                fs::write(&registry_path, new_content).await?;
                info!("Updated registry.bzl with latest tool data");
            }
        } else {
            warn!("Could not find hardcoded data section in registry.bzl");
        }

        Ok(())
    }

    /// Generate hardcoded data for registry.bzl
    async fn generate_hardcoded_data(&self) -> Result<String> {
        let tools = self.list_all_tools().await?;
        let mut data_entries = Vec::new();

        for tool_name in tools {
            let tool_info = self.get_tool_info(&tool_name).await?;
            let tool_data = self.format_tool_for_bzl(&tool_info)?;
            data_entries.push(tool_data);
        }

        Ok(format!(
            "hardcoded_data = {{\n{}\n    }}",
            data_entries.join(",\n")
        ))
    }

    /// Format tool information for Bazel/Starlark syntax
    fn format_tool_for_bzl(&self, tool_info: &ToolInfo) -> Result<String> {
        let mut versions_data = Vec::new();

        for (version, version_info) in &tool_info.versions {
            let mut platforms_data = Vec::new();

            for (platform, platform_info) in &version_info.platforms {
                let platform_entry = if let Some(platform_name) = &platform_info.platform_name {
                    format!(
                        "                        \"{}\": {{\n                            \"sha256\": \"{}\",\n                            \"platform_name\": \"{}\",\n                        }}",
                        platform, platform_info.sha256, platform_name
                    )
                } else {
                    format!(
                        "                        \"{}\": {{\n                            \"sha256\": \"{}\",\n                            \"url_suffix\": \"{}\",\n                        }}",
                        platform, platform_info.sha256, platform_info.url_suffix
                    )
                };
                platforms_data.push(platform_entry);
            }

            let version_entry = format!(
                "                \"{}\": {{\n                    \"release_date\": \"{}\",\n                    \"platforms\": {{\n{}\n                    }},\n                }}",
                version,
                version_info.release_date,
                platforms_data.join(",\n")
            );
            versions_data.push(version_entry);
        }

        Ok(format!(
            "        \"{}\": {{\n            \"tool_name\": \"{}\",\n            \"github_repo\": \"{}\",\n            \"latest_version\": \"{}\",\n            \"versions\": {{\n{}\n            }},\n        }}",
            tool_info.tool_name,
            tool_info.tool_name,
            tool_info.github_repo,
            tool_info.latest_version,
            versions_data.join(",\n")
        ))
    }

    /// Backup current checksums before updating
    pub async fn create_backup(&self) -> Result<PathBuf> {
        let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
        let backup_dir = self.checksums_dir.join(format!("backup_{}", timestamp));

        fs::create_dir_all(&backup_dir).await?;

        // Copy all JSON files
        let mut entries = fs::read_dir(&self.tools_dir).await?;
        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) == Some("json") {
                if let Some(file_name) = path.file_name() {
                    let backup_path = backup_dir.join(file_name);
                    fs::copy(&path, &backup_path).await?;
                }
            }
        }

        info!("Created backup at: {}", backup_dir.display());
        Ok(backup_dir)
    }

    /// Get the tools directory path
    pub fn tools_dir(&self) -> &Path {
        &self.tools_dir
    }

    /// Get the checksums directory path
    pub fn checksums_dir(&self) -> &Path {
        &self.checksums_dir
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_comparison() {
        let manager = ChecksumManager {
            checksums_dir: PathBuf::new(),
            tools_dir: PathBuf::new(),
        };

        assert!(manager.is_newer_version("1.1.0", "1.0.0"));
        assert!(manager.is_newer_version("2.0.0", "1.9.9"));
        assert!(!manager.is_newer_version("1.0.0", "1.1.0"));
        assert!(!manager.is_newer_version("1.0.0", "1.0.0"));
    }

    #[test]
    fn test_tool_creation() {
        // Test tool info structure creation
        let tool_info = ToolInfo {
            tool_name: "test-tool".to_string(),
            github_repo: "owner/test-tool".to_string(),
            latest_version: "1.0.0".to_string(),
            last_checked: chrono::Utc::now(),
            versions: HashMap::new(),
            supported_platforms: vec!["linux_amd64".to_string()],
        };

        assert_eq!(tool_info.tool_name, "test-tool");
        assert_eq!(tool_info.github_repo, "owner/test-tool");
        assert_eq!(tool_info.latest_version, "1.0.0");
        assert_eq!(tool_info.supported_platforms.len(), 1);
    }
}
