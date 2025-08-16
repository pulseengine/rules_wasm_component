/*!
GitHub API client for fetching release information and downloading files.
WASI Preview 2 compatible version using WASI HTTP interfaces.
*/

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::Deserialize;
use tracing::{debug, info};

/// GitHub release information
#[derive(Debug, Deserialize)]
pub struct GitHubRelease {
    pub tag_name: String,
    pub name: String,
    pub published_at: DateTime<Utc>,
    pub assets: Vec<GitHubAsset>,
}

/// GitHub release asset
#[derive(Debug, Deserialize)]
pub struct GitHubAsset {
    pub name: String,
    pub browser_download_url: String,
    pub size: u64,
}

/// GitHub API client
pub struct GitHubClient {
    client: reqwest::Client,
}

impl GitHubClient {
    /// Create a new GitHub client
    pub fn new() -> Self {
        // For WASI, we use a simpler client configuration
        let client = reqwest::Client::builder()
            .user_agent("checksum_updater_wasm/0.1.0")
            .timeout(std::time::Duration::from_secs(60)) // Longer timeout for WASI
            .build()
            .expect("Failed to create HTTP client");

        Self { client }
    }

    /// Get the latest release for a repository
    pub async fn get_latest_release(&self, repo: &str) -> Result<GitHubRelease> {
        let url = format!("https://api.github.com/repos/{}/releases/latest", repo);
        debug!("Fetching latest release: {}", url);

        let response = self
            .client
            .get(&url)
            .send()
            .await
            .with_context(|| format!("Failed to fetch release from {}", url))?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!(
                "GitHub API request failed: {} - {}",
                response.status(),
                response.text().await.unwrap_or_default()
            ));
        }

        let release: GitHubRelease = response
            .json()
            .await
            .with_context(|| format!("Failed to parse release JSON from {}", repo))?;

        info!(
            "Found latest release for {}: {} (published {})",
            repo, release.tag_name, release.published_at
        );

        Ok(release)
    }

    /// Download a file from URL
    pub async fn download_file(&self, url: &str) -> Result<Vec<u8>> {
        debug!("Downloading file: {}", url);

        let response = self
            .client
            .get(url)
            .send()
            .await
            .with_context(|| format!("Failed to download file from {}", url))?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!(
                "Download failed: {} - {}",
                response.status(),
                response.text().await.unwrap_or_default()
            ));
        }

        let bytes = response
            .bytes()
            .await
            .with_context(|| format!("Failed to read response body from {}", url))?;

        info!("Downloaded {} bytes from {}", bytes.len(), url);
        Ok(bytes.to_vec())
    }

    /// Get all releases for a repository (paginated)
    pub async fn get_all_releases(&self, repo: &str) -> Result<Vec<GitHubRelease>> {
        let mut releases = Vec::new();
        let mut page = 1;
        const PER_PAGE: u32 = 30;

        loop {
            let url = format!(
                "https://api.github.com/repos/{}/releases?page={}&per_page={}",
                repo, page, PER_PAGE
            );

            debug!("Fetching releases page {}: {}", page, url);

            let response = self
                .client
                .get(&url)
                .send()
                .await
                .with_context(|| format!("Failed to fetch releases from {}", url))?;

            if !response.status().is_success() {
                return Err(anyhow::anyhow!(
                    "GitHub API request failed: {} - {}",
                    response.status(),
                    response.text().await.unwrap_or_default()
                ));
            }

            let page_releases: Vec<GitHubRelease> = response
                .json()
                .await
                .with_context(|| format!("Failed to parse releases JSON from {}", repo))?;

            if page_releases.is_empty() {
                break;
            }

            releases.extend(page_releases);
            page += 1;

            // Avoid hitting rate limits too hard
            tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        }

        info!("Found {} total releases for {}", releases.len(), repo);
        Ok(releases)
    }

    /// Check if a release exists for a specific tag
    pub async fn release_exists(&self, repo: &str, tag: &str) -> Result<bool> {
        let url = format!(
            "https://api.github.com/repos/{}/releases/tags/{}",
            repo, tag
        );
        debug!("Checking if release exists: {}", url);

        let response = self
            .client
            .head(&url)
            .send()
            .await
            .with_context(|| format!("Failed to check release existence at {}", url))?;

        Ok(response.status().is_success())
    }

    /// Get rate limit information
    pub async fn get_rate_limit(&self) -> Result<RateLimitInfo> {
        let url = "https://api.github.com/rate_limit";
        debug!("Checking rate limit: {}", url);

        let response = self
            .client
            .get(url)
            .send()
            .await
            .context("Failed to check rate limit")?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!(
                "Rate limit check failed: {}",
                response.status()
            ));
        }

        let rate_limit_response: serde_json::Value = response
            .json()
            .await
            .context("Failed to parse rate limit response")?;

        let core = &rate_limit_response["rate"];

        Ok(RateLimitInfo {
            limit: core["limit"].as_u64().unwrap_or(0),
            remaining: core["remaining"].as_u64().unwrap_or(0),
            reset: core["reset"].as_u64().unwrap_or(0),
        })
    }
}

/// GitHub API rate limit information
#[derive(Debug)]
pub struct RateLimitInfo {
    pub limit: u64,
    pub remaining: u64,
    pub reset: u64, // Unix timestamp
}

impl Default for GitHubClient {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    #[ignore] // Requires network access
    async fn test_get_latest_release() {
        let client = GitHubClient::new();
        let release = client
            .get_latest_release("bytecodealliance/wasm-tools")
            .await;

        assert!(release.is_ok());
        let release = release.unwrap();
        assert!(!release.tag_name.is_empty());
        assert!(!release.assets.is_empty());
    }

    #[tokio::test]
    #[ignore] // Requires network access
    async fn test_rate_limit_check() {
        let client = GitHubClient::new();
        let rate_limit = client.get_rate_limit().await;

        assert!(rate_limit.is_ok());
        let rate_limit = rate_limit.unwrap();
        assert!(rate_limit.limit > 0);
    }

    #[test]
    fn test_client_creation() {
        let client = GitHubClient::new();
        // Just verify it can be created without panic
        assert!(std::ptr::addr_of!(client.client) as usize != 0);
    }
}
