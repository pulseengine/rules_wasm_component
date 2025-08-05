/*! 
Checksum updater library for WebAssembly tools.

This library provides functionality to automatically update checksums for
WebAssembly tools by fetching the latest releases from GitHub and validating
their checksums.
*/

pub mod checksum_manager;
pub mod github_client;
pub mod tool_config;
pub mod update_engine;
pub mod validator;

// Re-export commonly used types
pub use checksum_manager::{ChecksumManager, PlatformInfo, ToolInfo, VersionInfo};
pub use github_client::{GitHubClient, GitHubRelease};
pub use tool_config::{ToolConfig, ToolConfigEntry};
pub use update_engine::{UpdateConfig, UpdateEngine, UpdateResults, ToolUpdateResult};
pub use validator::{ChecksumValidator, ValidationResults};