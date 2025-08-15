/*!
Checksum validation for WebAssembly tools.

This module provides functionality to validate existing checksums against
actual downloads and fix any validation errors.
*/

use crate::{
    checksum_manager::ChecksumManager, github_client::GitHubClient, tool_config::ToolConfig,
};
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

/// Results of checksum validation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationResults {
    pub tools_validated: usize,
    pub valid_checksums: usize,
    pub invalid_checksums: usize,
    pub fixed_checksums: usize,
    pub errors: Vec<ValidationError>,
}

/// Error that occurred during validation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationError {
    pub tool_name: String,
    pub version: String,
    pub platform: String,
    pub message: String,
    pub error_type: String,
}

/// Single checksum validation result
#[derive(Debug)]
struct ChecksumValidation {
    tool_name: String,
    version: String,
    platform: String,
    stored_checksum: String,
    actual_checksum: Option<String>,
    is_valid: bool,
    error: Option<String>,
}

/// Checksum validator
pub struct ChecksumValidator {
    github_client: GitHubClient,
    tool_config: ToolConfig,
}

impl ChecksumValidator {
    /// Create a new checksum validator
    pub fn new() -> Self {
        Self {
            github_client: GitHubClient::new(),
            tool_config: ToolConfig::default(),
        }
    }

    /// Validate checksums for multiple tools
    pub async fn validate_tools(
        &self,
        tool_names: &[String],
        manager: &ChecksumManager,
        fix_errors: bool,
    ) -> Result<ValidationResults> {
        info!("Starting validation for {} tools", tool_names.len());

        let mut valid_checksums = 0;
        let mut invalid_checksums = 0;
        let mut fixed_checksums = 0;
        let mut errors = Vec::new();
        let mut total_validations = 0;

        for tool_name in tool_names {
            match self
                .validate_single_tool(tool_name, manager, fix_errors)
                .await
            {
                Ok(tool_results) => {
                    for validation in tool_results {
                        total_validations += 1;

                        if validation.is_valid {
                            valid_checksums += 1;
                        } else {
                            invalid_checksums += 1;

                            if let Some(ref error) = validation.error {
                                errors.push(ValidationError {
                                    tool_name: validation.tool_name.clone(),
                                    version: validation.version.clone(),
                                    platform: validation.platform.clone(),
                                    message: error.clone(),
                                    error_type: "checksum_mismatch".to_string(),
                                });
                            }
                        }

                        if fix_errors
                            && !validation.is_valid
                            && validation.actual_checksum.is_some()
                        {
                            match self.fix_checksum(&validation, manager).await {
                                Ok(()) => {
                                    fixed_checksums += 1;
                                    info!(
                                        "Fixed checksum for {} {} {}",
                                        validation.tool_name,
                                        validation.version,
                                        validation.platform
                                    );
                                }
                                Err(e) => {
                                    warn!(
                                        "Failed to fix checksum for {} {} {}: {}",
                                        validation.tool_name,
                                        validation.version,
                                        validation.platform,
                                        e
                                    );
                                }
                            }
                        }
                    }
                }
                Err(e) => {
                    errors.push(ValidationError {
                        tool_name: tool_name.clone(),
                        version: "unknown".to_string(),
                        platform: "unknown".to_string(),
                        message: e.to_string(),
                        error_type: "tool_error".to_string(),
                    });
                }
            }
        }

        info!(
            "Validation completed: {}/{} valid, {} fixed",
            valid_checksums, total_validations, fixed_checksums
        );

        Ok(ValidationResults {
            tools_validated: tool_names.len(),
            valid_checksums,
            invalid_checksums,
            fixed_checksums,
            errors,
        })
    }

    /// Validate checksums for a single tool
    async fn validate_single_tool(
        &self,
        tool_name: &str,
        manager: &ChecksumManager,
        _fix_errors: bool,
    ) -> Result<Vec<ChecksumValidation>> {
        info!("Validating checksums for {}", tool_name);

        let tool_info = manager
            .get_tool_info(tool_name)
            .await
            .with_context(|| format!("Failed to get tool info for {}", tool_name))?;

        let tool_config = self.tool_config.get_tool_config(tool_name);
        let mut validations = Vec::new();

        // Validate the latest version only to avoid excessive downloads
        let latest_version = &tool_info.latest_version;

        if let Some(version_info) = tool_info.versions.get(latest_version) {
            for (platform, platform_info) in &version_info.platforms {
                debug!(
                    "Validating {} {} {} (checksum: {})",
                    tool_name, latest_version, platform, platform_info.sha256
                );

                let validation = self
                    .validate_single_checksum(
                        tool_name,
                        latest_version,
                        platform,
                        &platform_info.sha256,
                        &tool_config,
                    )
                    .await;

                validations.push(validation);
            }
        } else {
            warn!("No version info found for {} {}", tool_name, latest_version);
        }

        Ok(validations)
    }

    /// Validate a single checksum
    async fn validate_single_checksum(
        &self,
        tool_name: &str,
        version: &str,
        platform: &str,
        stored_checksum: &str,
        tool_config: &crate::tool_config::ToolConfigEntry,
    ) -> ChecksumValidation {
        // Generate download URL
        let url = match tool_config.generate_download_url(version, platform) {
            Ok(url) => url,
            Err(e) => {
                return ChecksumValidation {
                    tool_name: tool_name.to_string(),
                    version: version.to_string(),
                    platform: platform.to_string(),
                    stored_checksum: stored_checksum.to_string(),
                    actual_checksum: None,
                    is_valid: false,
                    error: Some(format!("Failed to generate URL: {}", e)),
                };
            }
        };

        // Download and calculate actual checksum
        let actual_checksum = match self.download_and_calculate_checksum(&url).await {
            Ok(checksum) => checksum,
            Err(e) => {
                return ChecksumValidation {
                    tool_name: tool_name.to_string(),
                    version: version.to_string(),
                    platform: platform.to_string(),
                    stored_checksum: stored_checksum.to_string(),
                    actual_checksum: None,
                    is_valid: false,
                    error: Some(format!("Download failed: {}", e)),
                };
            }
        };

        let is_valid = stored_checksum == actual_checksum;
        let error = if !is_valid {
            Some(format!(
                "Checksum mismatch: stored={}, actual={}",
                stored_checksum, actual_checksum
            ))
        } else {
            None
        };

        ChecksumValidation {
            tool_name: tool_name.to_string(),
            version: version.to_string(),
            platform: platform.to_string(),
            stored_checksum: stored_checksum.to_string(),
            actual_checksum: Some(actual_checksum),
            is_valid,
            error,
        }
    }

    /// Download file and calculate its SHA256 checksum
    async fn download_and_calculate_checksum(&self, url: &str) -> Result<String> {
        debug!("Downloading for checksum validation: {}", url);

        let file_bytes = self
            .github_client
            .download_file(url)
            .await
            .with_context(|| format!("Failed to download file: {}", url))?;

        // Calculate SHA256 checksum
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(&file_bytes);
        let checksum = hex::encode(hasher.finalize());

        debug!("Calculated checksum: {}", checksum);
        Ok(checksum)
    }

    /// Fix a checksum by updating it with the correct value
    async fn fix_checksum(
        &self,
        validation: &ChecksumValidation,
        manager: &ChecksumManager,
    ) -> Result<()> {
        let actual_checksum = validation
            .actual_checksum
            .as_ref()
            .context("No actual checksum available for fixing")?;

        info!(
            "Fixing checksum for {} {} {}: {} -> {}",
            validation.tool_name,
            validation.version,
            validation.platform,
            validation.stored_checksum,
            actual_checksum
        );

        // Get current tool info
        let mut tool_info = manager.get_tool_info(&validation.tool_name).await?;

        // Update the checksum
        if let Some(version_info) = tool_info.versions.get_mut(&validation.version) {
            if let Some(platform_info) = version_info.platforms.get_mut(&validation.platform) {
                platform_info.sha256 = actual_checksum.clone();
            }
        }

        // Save the updated tool info
        manager.save_tool_info(&tool_info).await?;

        Ok(())
    }

    /// Validate that all JSON files are properly formatted
    pub async fn validate_json_format(
        &self,
        manager: &ChecksumManager,
    ) -> Result<ValidationResults> {
        info!("Validating JSON format for all tool files");

        let tools = manager.list_all_tools().await?;
        let mut errors = Vec::new();
        let mut valid_files = 0;

        for tool_name in &tools {
            match manager.get_tool_info(tool_name).await {
                Ok(_) => {
                    valid_files += 1;
                    debug!("Valid JSON format: {}", tool_name);
                }
                Err(e) => {
                    errors.push(ValidationError {
                        tool_name: tool_name.clone(),
                        version: "n/a".to_string(),
                        platform: "n/a".to_string(),
                        message: format!("Invalid JSON format: {}", e),
                        error_type: "json_format".to_string(),
                    });
                }
            }
        }

        Ok(ValidationResults {
            tools_validated: tools.len(),
            valid_checksums: valid_files,
            invalid_checksums: errors.len(),
            fixed_checksums: 0,
            errors,
        })
    }
}

impl ValidationResults {
    /// Check if there are any validation errors
    pub fn has_errors(&self) -> bool {
        !self.errors.is_empty() || self.invalid_checksums > 0
    }

    /// Get success rate as a percentage
    pub fn success_rate(&self) -> f64 {
        if self.valid_checksums + self.invalid_checksums == 0 {
            return 100.0;
        }

        (self.valid_checksums as f64 / (self.valid_checksums + self.invalid_checksums) as f64)
            * 100.0
    }
}

impl Default for ChecksumValidator {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use tokio::fs;

    async fn create_test_manager() -> (ChecksumManager, TempDir) {
        let temp_dir = TempDir::new().unwrap();
        let checksums_dir = temp_dir.path().join("checksums");
        let tools_dir = checksums_dir.join("tools");

        fs::create_dir_all(&tools_dir).await.unwrap();

        let manager = ChecksumManager::new_with_paths(checksums_dir, tools_dir);

        (manager, temp_dir)
    }

    #[test]
    fn test_validation_results_success_rate() {
        let results = ValidationResults {
            tools_validated: 1,
            valid_checksums: 3,
            invalid_checksums: 1,
            fixed_checksums: 0,
            errors: vec![],
        };

        assert_eq!(results.success_rate(), 75.0);
    }

    #[test]
    fn test_validation_results_has_errors() {
        let results_with_errors = ValidationResults {
            tools_validated: 1,
            valid_checksums: 1,
            invalid_checksums: 1,
            fixed_checksums: 0,
            errors: vec![],
        };

        assert!(results_with_errors.has_errors());

        let results_no_errors = ValidationResults {
            tools_validated: 1,
            valid_checksums: 2,
            invalid_checksums: 0,
            fixed_checksums: 0,
            errors: vec![],
        };

        assert!(!results_no_errors.has_errors());
    }

    #[tokio::test]
    async fn test_json_format_validation() {
        let (manager, _temp_dir) = create_test_manager().await;
        let validator = ChecksumValidator::new();

        // Create a valid tool
        manager
            .create_tool("test-tool", "owner/test-tool")
            .await
            .unwrap();

        // Validate JSON format
        let results = validator.validate_json_format(&manager).await.unwrap();

        assert_eq!(results.tools_validated, 1);
        assert_eq!(results.valid_checksums, 1);
        assert_eq!(results.invalid_checksums, 0);
        assert!(!results.has_errors());
    }

    #[test]
    fn test_validator_creation() {
        let validator = ChecksumValidator::new();
        // Just verify it can be created without panic
        assert!(std::ptr::addr_of!(validator.github_client) as usize != 0);
    }
}
