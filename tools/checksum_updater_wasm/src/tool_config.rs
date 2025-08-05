/*!
Configuration for WebAssembly tools and their download patterns.
*/

use anyhow::{Context, Result};
use std::collections::HashMap;

/// Configuration for all tools
#[derive(Debug, Clone)]
pub struct ToolConfig {
    tools: HashMap<String, ToolConfigEntry>,
}

/// Configuration for a specific tool
#[derive(Debug, Clone)]
pub struct ToolConfigEntry {
    pub github_repo: String,
    pub platforms: Vec<String>,
    pub url_pattern: UrlPattern,
}

/// URL pattern for downloading tool releases
#[derive(Debug, Clone)]
pub enum UrlPattern {
    /// Standard tarball pattern: {tool}-{version}-{platform}.tar.gz
    StandardTarball {
        platform_mapping: HashMap<String, String>,
    },
    /// Single binary pattern: {tool}-cli-{platform}
    SingleBinary {
        platform_mapping: HashMap<String, String>,
    },
    /// Custom pattern with placeholders
    Custom {
        pattern: String,
        platform_mapping: HashMap<String, String>,
    },
}

impl Default for ToolConfig {
    fn default() -> Self {
        Self::new()
    }
}

impl ToolConfig {
    /// Create a new tool configuration with defaults
    pub fn new() -> Self {
        let mut tools = HashMap::new();

        // wasm-tools configuration
        tools.insert(
            "wasm-tools".to_string(),
            ToolConfigEntry {
                github_repo: "bytecodealliance/wasm-tools".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::StandardTarball {
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-macos".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-macos".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-linux".to_string());
                        map.insert("linux_arm64".to_string(), "aarch64-linux".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-windows".to_string());
                        map
                    },
                },
            },
        );

        // wit-bindgen configuration
        tools.insert(
            "wit-bindgen".to_string(),
            ToolConfigEntry {
                github_repo: "bytecodealliance/wit-bindgen".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::StandardTarball {
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-macos".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-macos".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-linux".to_string());
                        map.insert("linux_arm64".to_string(), "aarch64-linux".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-windows".to_string());
                        map
                    },
                },
            },
        );

        // wac configuration
        tools.insert(
            "wac".to_string(),
            ToolConfigEntry {
                github_repo: "bytecodealliance/wac".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::SingleBinary {
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-apple-darwin".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-apple-darwin".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-unknown-linux-musl".to_string());
                        map.insert("linux_arm64".to_string(), "aarch64-unknown-linux-musl".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-pc-windows-gnu".to_string());
                        map
                    },
                },
            },
        );

        // wasmtime configuration
        tools.insert(
            "wasmtime".to_string(),
            ToolConfigEntry {
                github_repo: "bytecodealliance/wasmtime".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::Custom {
                    pattern: "https://github.com/bytecodealliance/wasmtime/releases/download/v{version}/wasmtime-v{version}-{platform}.tar.xz".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-macos".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-macos".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-linux".to_string());
                        map.insert("linux_arm64".to_string(), "aarch64-linux".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-windows".to_string());
                        map
                    },
                },
            },
        );

        // wasi-sdk configuration
        tools.insert(
            "wasi-sdk".to_string(),
            ToolConfigEntry {
                github_repo: "WebAssembly/wasi-sdk".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::Custom {
                    pattern: "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-{version}/wasi-sdk-{version}.0-{platform}.tar.gz".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-macos".to_string());
                        map.insert("darwin_arm64".to_string(), "arm64-macos".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-linux".to_string());
                        map.insert("linux_arm64".to_string(), "x86_64-linux".to_string()); // Note: same as amd64
                        map.insert("windows_amd64".to_string(), "x86_64-windows".to_string());
                        map
                    },
                },
            },
        );

        Self { tools }
    }

    /// Get configuration for a specific tool
    pub fn get_tool_config(&self, tool_name: &str) -> ToolConfigEntry {
        self.tools
            .get(tool_name)
            .cloned()
            .unwrap_or_else(|| self.create_default_config(tool_name))
    }

    /// Get all configured tool names
    pub fn get_all_tool_names(&self) -> Vec<String> {
        self.tools.keys().cloned().collect()
    }

    /// Create a default configuration for an unknown tool
    fn create_default_config(&self, tool_name: &str) -> ToolConfigEntry {
        // Try to infer GitHub repo
        let github_repo = format!("bytecodealliance/{}", tool_name);

        ToolConfigEntry {
            github_repo,
            platforms: vec![
                "darwin_amd64".to_string(),
                "linux_amd64".to_string(),
                "windows_amd64".to_string(),
            ],
            url_pattern: UrlPattern::StandardTarball {
                platform_mapping: {
                    let mut map = HashMap::new();
                    map.insert("darwin_amd64".to_string(), "x86_64-macos".to_string());
                    map.insert("linux_amd64".to_string(), "x86_64-linux".to_string());
                    map.insert("windows_amd64".to_string(), "x86_64-windows".to_string());
                    map
                },
            },
        }
    }
}

impl ToolConfigEntry {
    /// Generate download URL for a specific version and platform
    pub fn generate_download_url(&self, version: &str, platform: &str) -> Result<String> {
        match &self.url_pattern {
            UrlPattern::StandardTarball { platform_mapping } => {
                let platform_name = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Unsupported platform: {}", platform))?;

                let tool_name = self.github_repo.split('/').last().unwrap_or("tool");
                Ok(format!(
                    "https://github.com/{}/releases/download/v{}/{}-{}-{}.tar.gz",
                    self.github_repo, version, tool_name, version, platform_name
                ))
            }
            UrlPattern::SingleBinary { platform_mapping } => {
                let platform_name = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Unsupported platform: {}", platform))?;

                let tool_name = self.github_repo.split('/').last().unwrap_or("tool");
                Ok(format!(
                    "https://github.com/{}/releases/download/v{}/{}-cli-{}",
                    self.github_repo, version, tool_name, platform_name
                ))
            }
            UrlPattern::Custom { pattern, platform_mapping } => {
                let platform_name = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Unsupported platform: {}", platform))?;

                let url = pattern
                    .replace("{version}", version)
                    .replace("{platform}", platform_name);

                Ok(url)
            }
        }
    }

    /// Check if this tool uses platform names instead of URL suffixes
    pub fn has_platform_names(&self) -> bool {
        matches!(self.url_pattern, UrlPattern::SingleBinary { .. })
    }

    /// Get platform name for JSON storage
    pub fn get_platform_name(&self, platform: &str) -> Result<String> {
        match &self.url_pattern {
            UrlPattern::SingleBinary { platform_mapping } => {
                platform_mapping
                    .get(platform)
                    .cloned()
                    .with_context(|| format!("Platform {} not found", platform))
            }
            _ => Err(anyhow::anyhow!("Tool does not use platform names")),
        }
    }

    /// Get URL suffix for JSON storage
    pub fn get_url_suffix(&self, platform: &str) -> Result<String> {
        match &self.url_pattern {
            UrlPattern::StandardTarball { platform_mapping } => {
                let platform_name = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Platform {} not found", platform))?;
                Ok(format!("{}.tar.gz", platform_name))
            }
            UrlPattern::Custom { platform_mapping, .. } => {
                let platform_name = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Platform {} not found", platform))?;

                // Extract extension from the pattern
                if platform_name.contains("windows") {
                    Ok(format!("{}.zip", platform_name))
                } else if platform_name.contains("macos") || platform_name.contains("linux") {
                    Ok(format!("{}.tar.xz", platform_name))
                } else {
                    Ok(format!("{}.tar.gz", platform_name))
                }
            }
            _ => Err(anyhow::anyhow!("Tool does not use URL suffixes")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tool_config_creation() {
        let config = ToolConfig::new();
        assert!(config.tools.contains_key("wasm-tools"));
        assert!(config.tools.contains_key("wit-bindgen"));
        assert!(config.tools.contains_key("wac"));
    }

    #[test]
    fn test_get_tool_config() {
        let config = ToolConfig::new();
        
        let wasm_tools_config = config.get_tool_config("wasm-tools");
        assert_eq!(wasm_tools_config.github_repo, "bytecodealliance/wasm-tools");
        assert!(wasm_tools_config.platforms.contains(&"linux_amd64".to_string()));
    }

    #[test]
    fn test_generate_download_url() {
        let config = ToolConfig::new();
        
        // Test wasm-tools (standard tarball)
        let wasm_tools_config = config.get_tool_config("wasm-tools");
        let url = wasm_tools_config
            .generate_download_url("1.0.0", "linux_amd64")
            .unwrap();
        assert!(url.contains("wasm-tools-1.0.0-x86_64-linux.tar.gz"));
        
        // Test wac (single binary)
        let wac_config = config.get_tool_config("wac");
        let url = wac_config
            .generate_download_url("0.7.0", "linux_amd64")
            .unwrap();
        assert!(url.contains("wac-cli-x86_64-unknown-linux-musl"));
    }

    #[test]
    fn test_platform_names_vs_suffixes() {
        let config = ToolConfig::new();
        
        let wasm_tools_config = config.get_tool_config("wasm-tools");
        assert!(!wasm_tools_config.has_platform_names());
        
        let wac_config = config.get_tool_config("wac");
        assert!(wac_config.has_platform_names());
    }

    #[test]
    fn test_get_url_suffix() {
        let config = ToolConfig::new();
        let wasm_tools_config = config.get_tool_config("wasm-tools");
        
        let suffix = wasm_tools_config
            .get_url_suffix("linux_amd64")
            .unwrap();
        assert_eq!(suffix, "x86_64-linux.tar.gz");
    }

    #[test]
    fn test_get_platform_name() {
        let config = ToolConfig::new();
        let wac_config = config.get_tool_config("wac");
        
        let platform_name = wac_config
            .get_platform_name("linux_amd64")
            .unwrap();
        assert_eq!(platform_name, "x86_64-unknown-linux-musl");
    }

    #[test]
    fn test_default_config_for_unknown_tool() {
        let config = ToolConfig::new();
        let unknown_config = config.get_tool_config("unknown-tool");
        
        assert_eq!(unknown_config.github_repo, "bytecodealliance/unknown-tool");
        assert!(unknown_config.platforms.contains(&"linux_amd64".to_string()));
    }
}