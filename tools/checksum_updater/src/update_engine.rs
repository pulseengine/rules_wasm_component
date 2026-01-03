/*!
Update engine for managing checksum updates across multiple tools.

This module orchestrates the update process, including version checking,
downloading, and validation of WebAssembly tools.
*/

use crate::{
    checksum_manager::{ChecksumManager, PlatformInfo, VersionInfo},
    github_client::GitHubClient,
    tool_config::ToolConfig,
};
use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use futures::stream::StreamExt;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};
use tokio::time::timeout;
use tracing::{debug, info, warn};

/// Configuration for update operations
#[derive(Debug, Clone)]
pub struct UpdateConfig {
    pub force: bool,
    pub dry_run: bool,
    pub skip_errors: bool,
    pub parallel: bool,
    pub timeout_seconds: u64,
}

/// Results of an update operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateResults {
    pub summary: UpdateSummary,
    pub updates: Vec<ToolUpdateResult>,
    pub errors: Vec<UpdateError>,
    pub timestamp: DateTime<Utc>,
}

/// Summary statistics for updates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateSummary {
    pub tools_processed: usize,
    pub tools_updated: usize,
    pub new_versions_found: usize,
    pub errors: usize,
    pub duration: Duration,
}

/// Result of updating a single tool
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolUpdateResult {
    pub tool_name: String,
    pub old_version: Option<String>,
    pub new_version: String,
    pub version_change: String, // "major", "minor", "patch", "none"
    pub platforms_updated: usize,
    pub release_notes_url: Option<String>,
    pub update_duration: Duration,
}

/// Error that occurred during update
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateError {
    pub tool_name: String,
    pub message: String,
    pub error_type: String, // "network", "validation", "parsing", "timeout"
}

/// Update engine for managing tool updates
pub struct UpdateEngine {
    manager: ChecksumManager,
    github_client: GitHubClient,
    tool_config: ToolConfig,
}

impl UpdateEngine {
    /// Create a new update engine
    pub fn new(manager: ChecksumManager) -> Self {
        Self {
            manager,
            github_client: GitHubClient::new(),
            tool_config: ToolConfig::default(),
        }
    }

    /// List all available tools that can be updated
    pub async fn list_available_tools(&self) -> Result<Vec<String>> {
        // Only return tools that have GitHub API configurations
        // This filters out WASM components and other tools that use fallback checksums
        let mut tools = Vec::new();

        for tool_name in self.tool_config.get_all_tool_names() {
            tools.push(tool_name);
        }

        tools.sort();
        Ok(tools)
    }

    /// Update multiple tools
    pub async fn update_tools(
        &self,
        tool_names: &[String],
        config: &UpdateConfig,
    ) -> Result<UpdateResults> {
        let start_time = Instant::now();
        info!("Starting update for {} tools", tool_names.len());

        let mut updates = Vec::new();
        let mut errors = Vec::new();

        if config.parallel {
            // Process tools in parallel using buffer_unordered
            // This allows concurrent execution while maintaining back-pressure
            let mut stream = futures::stream::iter(tool_names.iter())
                .map(|tool_name| {
                    let tool_name = tool_name.clone();
                    let config = config.clone();
                    async move {
                        let result = self.update_single_tool_timeout(&tool_name, &config).await;
                        (tool_name, result)
                    }
                })
                .buffer_unordered(10); // Process up to 10 tools concurrently

            // Collect results as they complete
            while let Some((tool_name, result)) = stream.next().await {
                match result {
                    Ok(Some(update)) => {
                        updates.push(update);
                    }
                    Ok(None) => {
                        // No update needed
                    }
                    Err(e) => {
                        if !config.skip_errors {
                            return Err(e);
                        }
                        errors.push(UpdateError {
                            tool_name,
                            message: e.to_string(),
                            error_type: "processing".to_string(),
                        });
                    }
                }
            }
        } else {
            // Process tools sequentially
            for tool_name in tool_names {
                match self.update_single_tool_timeout(tool_name, config).await {
                    Ok(Some(update)) => updates.push(update),
                    Ok(None) => {} // No update needed
                    Err(e) => {
                        if config.skip_errors {
                            errors.push(UpdateError {
                                tool_name: tool_name.clone(),
                                message: e.to_string(),
                                error_type: "processing".to_string(),
                            });
                        } else {
                            return Err(e);
                        }
                    }
                }
            }
        }

        let duration = start_time.elapsed();

        let summary = UpdateSummary {
            tools_processed: tool_names.len(),
            tools_updated: updates.len(),
            new_versions_found: updates.iter().filter(|u| u.old_version.is_some()).count(),
            errors: errors.len(),
            duration,
        };

        info!(
            "Update completed: {} tools processed, {} updated, {} errors in {:?}",
            summary.tools_processed, summary.tools_updated, summary.errors, summary.duration
        );

        // Regenerate registry.bzl if we actually made updates (not dry-run)
        if !config.dry_run && !updates.is_empty() {
            info!("Regenerating registry.bzl with updated checksums");
            self.manager
                .update_registry_bzl()
                .await
                .context("Failed to update registry.bzl")?;
        }

        Ok(UpdateResults {
            summary,
            updates,
            errors,
            timestamp: Utc::now(),
        })
    }

    /// Update a single tool with timeout
    async fn update_single_tool_timeout(
        &self,
        tool_name: &str,
        config: &UpdateConfig,
    ) -> Result<Option<ToolUpdateResult>> {
        let timeout_duration = Duration::from_secs(config.timeout_seconds);

        match timeout(timeout_duration, self.update_single_tool(tool_name, config)).await {
            Ok(result) => result,
            Err(_) => Err(anyhow::anyhow!(
                "Tool update timed out after {}s",
                config.timeout_seconds
            )),
        }
    }

    /// Update a single tool
    async fn update_single_tool(
        &self,
        tool_name: &str,
        config: &UpdateConfig,
    ) -> Result<Option<ToolUpdateResult>> {
        let start_time = Instant::now();
        info!("Checking for updates: {}", tool_name);

        // Get or create tool configuration
        let tool_config = self.tool_config.get_tool_config(tool_name);

        // Get current tool info or create new
        let current_tool_info = if self.manager.tool_exists(tool_name).await {
            self.manager.get_tool_info(tool_name).await?
        } else {
            self.manager
                .create_tool(tool_name, &tool_config.github_repo)
                .await?
        };

        // Get release from GitHub, respecting version filter
        let (latest_release, latest_version) = self
            .get_filtered_release(&tool_config)
            .await
            .with_context(|| format!("Failed to get release for {}", tool_name))?;

        // Check if update is needed
        if !config.force && latest_version == current_tool_info.latest_version {
            debug!(
                "No update needed for {}: already at {}",
                tool_name, latest_version
            );
            return Ok(None);
        }

        // Determine version change type
        let version_change = if current_tool_info.latest_version == "0.0.0" {
            "initial".to_string()
        } else {
            self.classify_version_change(&current_tool_info.latest_version, &latest_version)
        };

        info!(
            "Updating {} from {} to {} ({})",
            tool_name, current_tool_info.latest_version, latest_version, version_change
        );

        // Download and validate checksums for all platforms
        let platforms_info = self
            .download_platform_checksums(tool_name, &latest_version, &tool_config)
            .await
            .with_context(|| format!("Failed to download checksums for {}", tool_name))?;

        if platforms_info.is_empty() {
            warn!("No platform checksums found for {}", tool_name);
            return Ok(None);
        }

        let version_info = VersionInfo {
            release_date: latest_release.published_at.format("%Y-%m-%d").to_string(),
            platforms: platforms_info,
            extra: HashMap::new(),
        };

        let platforms_count = version_info.platforms.len();

        // Save updates if not dry run
        if !config.dry_run {
            self.manager
                .update_tool_version(tool_name, &latest_version, version_info)
                .await
                .with_context(|| format!("Failed to save updates for {}", tool_name))?;
        }

        let update_duration = start_time.elapsed();

        Ok(Some(ToolUpdateResult {
            tool_name: tool_name.to_string(),
            old_version: if current_tool_info.latest_version == "0.0.0" {
                None
            } else {
                Some(current_tool_info.latest_version)
            },
            new_version: latest_version.to_string(),
            version_change,
            platforms_updated: platforms_count,
            release_notes_url: Some(format!(
                "https://github.com/{}/releases/tag/{}",
                tool_config.github_repo, latest_release.tag_name
            )),
            update_duration,
        }))
    }

    /// Get a release from GitHub that passes the version filter
    async fn get_filtered_release(
        &self,
        tool_config: &crate::tool_config::ToolConfigEntry,
    ) -> Result<(crate::github_client::GitHubRelease, String)> {
        use crate::tool_config::VersionFilter;

        match &tool_config.version_filter {
            VersionFilter::Any => {
                // Standard behavior: get the latest release
                let release = self
                    .github_client
                    .get_latest_release(&tool_config.github_repo)
                    .await?;

                let version = if let Some(prefix) = &tool_config.tag_prefix {
                    release.tag_name.trim_start_matches(prefix.as_str()).to_string()
                } else {
                    release.tag_name.trim_start_matches('v').to_string()
                };

                Ok((release, version))
            }
            VersionFilter::LtsOnly => {
                // Need to get all releases and filter
                info!(
                    "Fetching releases for {} with LTS filter",
                    tool_config.github_repo
                );

                let releases = self
                    .github_client
                    .get_all_releases(&tool_config.github_repo)
                    .await?;

                // Find the first release that passes the LTS filter
                for release in releases {
                    let version = if let Some(prefix) = &tool_config.tag_prefix {
                        release.tag_name.trim_start_matches(prefix.as_str()).to_string()
                    } else {
                        release.tag_name.trim_start_matches('v').to_string()
                    };

                    if tool_config.version_filter.accepts(&version) {
                        info!(
                            "Found LTS version {} for {}",
                            version, tool_config.github_repo
                        );
                        return Ok((release, version));
                    } else {
                        debug!(
                            "Skipping non-LTS version {} for {}",
                            version, tool_config.github_repo
                        );
                    }
                }

                Err(anyhow::anyhow!(
                    "No releases found that match LTS filter for {}",
                    tool_config.github_repo
                ))
            }
        }
    }

    /// Download and validate checksums for all platforms
    async fn download_platform_checksums(
        &self,
        tool_name: &str,
        version: &str,
        tool_config: &crate::tool_config::ToolConfigEntry,
    ) -> Result<HashMap<String, PlatformInfo>> {
        let mut platforms_info = HashMap::new();

        for platform in &tool_config.platforms {
            debug!("Processing platform {} for {}", platform, tool_name);

            match self
                .download_platform_checksum(tool_name, version, platform, tool_config)
                .await
            {
                Ok(platform_info) => {
                    platforms_info.insert(platform.clone(), platform_info);
                }
                Err(e) => {
                    warn!(
                        "Failed to process platform {} for {}: {}",
                        platform, tool_name, e
                    );
                    // Continue with other platforms
                }
            }
        }

        Ok(platforms_info)
    }

    /// Download and validate checksum for a single platform
    async fn download_platform_checksum(
        &self,
        tool_name: &str,
        version: &str,
        platform: &str,
        tool_config: &crate::tool_config::ToolConfigEntry,
    ) -> Result<PlatformInfo> {
        // Generate download URL based on tool configuration
        let url = tool_config.generate_download_url(version, platform)?;

        debug!("Downloading {} for checksum validation: {}", tool_name, url);

        // Download file and calculate checksum
        let file_bytes = self
            .github_client
            .download_file(&url)
            .await
            .with_context(|| format!("Failed to download file: {}", url))?;

        // Calculate SHA256 checksum
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(&file_bytes);
        let checksum = hex::encode(hasher.finalize());

        debug!(
            "Calculated checksum for {} {}: {}",
            tool_name, platform, checksum
        );

        // Generate platform info based on tool type
        let platform_info = if tool_config.has_platform_names() {
            PlatformInfo {
                sha256: checksum,
                url_suffix: String::new(), // Not used for tools with platform names
                platform_name: Some(tool_config.get_platform_name(platform)?),
                extra: HashMap::new(),
            }
        } else {
            PlatformInfo {
                sha256: checksum,
                url_suffix: tool_config.get_url_suffix(platform)?,
                platform_name: None,
                extra: HashMap::new(),
            }
        };

        Ok(platform_info)
    }

    /// Classify the type of version change
    fn classify_version_change(&self, old_version: &str, new_version: &str) -> String {
        match (
            semver::Version::parse(old_version),
            semver::Version::parse(new_version),
        ) {
            (Ok(old), Ok(new)) => {
                if new.major > old.major {
                    "major".to_string()
                } else if new.minor > old.minor {
                    "minor".to_string()
                } else if new.patch > old.patch {
                    "patch".to_string()
                } else {
                    "none".to_string()
                }
            }
            _ => "unknown".to_string(),
        }
    }
}

impl UpdateResults {
    /// Check if there are any errors
    pub fn has_errors(&self) -> bool {
        !self.errors.is_empty()
    }

    /// Check if any tools were updated
    pub fn has_updates(&self) -> bool {
        !self.updates.is_empty()
    }

    /// Get tools with major version updates
    pub fn major_updates(&self) -> Vec<&ToolUpdateResult> {
        self.updates
            .iter()
            .filter(|u| u.version_change == "major")
            .collect()
    }

    /// Check if all updates are safe (no major versions)
    pub fn is_safe_for_auto_merge(&self) -> bool {
        !self.has_errors() && self.major_updates().is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version_change_classification() {
        let manager =
            ChecksumManager::new_with_paths(std::path::PathBuf::new(), std::path::PathBuf::new());
        let engine = UpdateEngine::new(manager);

        assert_eq!(engine.classify_version_change("1.0.0", "2.0.0"), "major");
        assert_eq!(engine.classify_version_change("1.0.0", "1.1.0"), "minor");
        assert_eq!(engine.classify_version_change("1.0.0", "1.0.1"), "patch");
        assert_eq!(engine.classify_version_change("1.0.0", "1.0.0"), "none");
    }

    #[test]
    fn test_update_results_analysis() {
        let results = UpdateResults {
            summary: UpdateSummary {
                tools_processed: 3,
                tools_updated: 2,
                new_versions_found: 2,
                errors: 0,
                duration: Duration::from_secs(10),
            },
            updates: vec![
                ToolUpdateResult {
                    tool_name: "tool1".to_string(),
                    old_version: Some("1.0.0".to_string()),
                    new_version: "1.1.0".to_string(),
                    version_change: "minor".to_string(),
                    platforms_updated: 3,
                    release_notes_url: None,
                    update_duration: Duration::from_secs(5),
                },
                ToolUpdateResult {
                    tool_name: "tool2".to_string(),
                    old_version: Some("1.0.0".to_string()),
                    new_version: "2.0.0".to_string(),
                    version_change: "major".to_string(),
                    platforms_updated: 3,
                    release_notes_url: None,
                    update_duration: Duration::from_secs(5),
                },
            ],
            errors: vec![],
            timestamp: Utc::now(),
        };

        assert!(results.has_updates());
        assert!(!results.has_errors());
        assert!(!results.is_safe_for_auto_merge()); // Due to major update
        assert_eq!(results.major_updates().len(), 1);
    }

    #[test]
    fn test_safe_auto_merge() {
        let results = UpdateResults {
            summary: UpdateSummary {
                tools_processed: 2,
                tools_updated: 2,
                new_versions_found: 2,
                errors: 0,
                duration: Duration::from_secs(10),
            },
            updates: vec![
                ToolUpdateResult {
                    tool_name: "tool1".to_string(),
                    old_version: Some("1.0.0".to_string()),
                    new_version: "1.0.1".to_string(),
                    version_change: "patch".to_string(),
                    platforms_updated: 3,
                    release_notes_url: None,
                    update_duration: Duration::from_secs(3),
                },
                ToolUpdateResult {
                    tool_name: "tool2".to_string(),
                    old_version: Some("1.1.0".to_string()),
                    new_version: "1.2.0".to_string(),
                    version_change: "minor".to_string(),
                    platforms_updated: 3,
                    release_notes_url: None,
                    update_duration: Duration::from_secs(3),
                },
            ],
            errors: vec![],
            timestamp: Utc::now(),
        };

        assert!(results.is_safe_for_auto_merge()); // Only minor/patch updates
    }
}
