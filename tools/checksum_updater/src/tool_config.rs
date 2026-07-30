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
    /// Prefix to strip from GitHub release tag names (e.g., "v" for "v1.0.0", "wasi-sdk-" for "wasi-sdk-29")
    pub tag_prefix: Option<String>,
    /// Version filter for selecting which releases to consider
    pub version_filter: VersionFilter,
}

/// Filter for selecting which versions to consider during updates
#[derive(Debug, Clone, Default)]
pub enum VersionFilter {
    /// Accept any stable release (default behavior)
    #[default]
    Any,
    /// Only accept LTS versions (for Node.js: even major versions like 20, 22, 24)
    LtsOnly,
    /// Accept the newest release that actually ships the expected asset.
    ///
    /// Used for universal-wasm tools whose later releases may stop shipping the
    /// consumable `.wasm` artifact, so plain "latest" would pick a tag with no
    /// downloadable asset. The asset name comes from the tool's
    /// `UrlPattern::UniversalWasm`. Resolved in the update engine (it needs each
    /// release's asset list), not via `accepts()`.
    ///
    /// (loom used this while it shipped `loom.wasm` through v0.3.0; from v1.x it
    /// ships per-platform native binaries and moved to
    /// `PerPlatformVersionedAsset` + `Any`. file-ops-component is the current
    /// user.)
    AssetExists,
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
    /// Universal (platform-independent) WASM component published as a single
    /// release asset, e.g. `loom.wasm`. URL is
    /// `https://github.com/{repo}/releases/download/v{version}/{asset_name}`.
    /// The single platform key (e.g. "wasm" or "wasm_component") is stored in
    /// `platforms`; the asset name is the same across platforms.
    UniversalWasm { asset_name: String },
    /// Per-platform asset where the suffix (including extension) is given
    /// verbatim per platform. Required for tools with *mixed* extensions across
    /// platforms (e.g. `.tar.xz`/`.tar.gz` on unix but `.zip` on Windows) — the
    /// other variants assume one extension for all platforms, which silently
    /// drops the odd-one-out (wit-bindgen 0.58 Windows became .zip; wasmtime,
    /// tinygo Windows have the same shape).
    ///
    /// `pattern` is the full URL with `{version}` and `{asset}` placeholders;
    /// `platform_mapping` maps each platform to its `{asset}` value, which is
    /// the complete suffix *including* the file extension and is stored verbatim
    /// as the registry `url_suffix`.
    PerPlatformAsset {
        pattern: String,
        platform_mapping: HashMap<String, String>,
    },
    /// Per-platform asset whose stored `url_suffix` is the COMPLETE filename
    /// *including the version*, e.g. loom's `loom-v1.1.14-aarch64-apple-darwin.tar.gz`.
    /// Required when the toolchain reads `url_suffix` as the whole filename
    /// (`filename: "{suffix}"` in tool_registry.bzl, as loom/wkg/wrpc do) rather
    /// than appending a fragment to a version-templated pattern. `PerPlatformAsset`
    /// can't express this because its stored suffix is static (no `{version}`),
    /// so the next release would write a stale, wrong filename.
    ///
    /// `filename_pattern` is the asset filename with `{version}` and `{platform}`
    /// placeholders; `platform_mapping` maps each platform to its `{platform}`
    /// value (including the file extension). The full resolved filename is both
    /// the download asset and the verbatim registry `url_suffix`.
    PerPlatformVersionedAsset {
        filename_pattern: String,
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
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
            },
        );

        // wit-bindgen configuration.
        // PerPlatformAsset because Windows switched to .zip in 0.58 while unix
        // stays .tar.gz — a single-extension pattern silently drops Windows.
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
                url_pattern: UrlPattern::PerPlatformAsset {
                    pattern: "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{version}/wit-bindgen-{version}-{asset}".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-macos.tar.gz".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-macos.tar.gz".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-linux.tar.gz".to_string());
                        map.insert("linux_arm64".to_string(), "aarch64-linux.tar.gz".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-windows.zip".to_string());
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
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
                        map.insert(
                            "darwin_amd64".to_string(),
                            "x86_64-apple-darwin".to_string(),
                        );
                        map.insert(
                            "darwin_arm64".to_string(),
                            "aarch64-apple-darwin".to_string(),
                        );
                        map.insert(
                            "linux_amd64".to_string(),
                            "x86_64-unknown-linux-musl".to_string(),
                        );
                        map.insert(
                            "linux_arm64".to_string(),
                            "aarch64-unknown-linux-musl".to_string(),
                        );
                        map.insert(
                            "windows_amd64".to_string(),
                            "x86_64-pc-windows-gnu".to_string(),
                        );
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
            },
        );

        // wasmtime configuration.
        // PerPlatformAsset: assets are wasmtime-v{version}-{platform}, with
        // .tar.xz on unix and .zip on Windows. (Previously excluded over a
        // "GitHub API" note that was really this mixed-extension mismatch.)
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
                url_pattern: UrlPattern::PerPlatformAsset {
                    pattern: "https://github.com/bytecodealliance/wasmtime/releases/download/v{version}/wasmtime-v{version}-{asset}".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-macos.tar.xz".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-macos.tar.xz".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-linux.tar.xz".to_string());
                        map.insert("linux_arm64".to_string(), "aarch64-linux.tar.xz".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-windows.zip".to_string());
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
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
                    "windows_arm64".to_string(),
                ],
                url_pattern: UrlPattern::Custom {
                    pattern: "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-{version}/wasi-sdk-{version}.0-{platform}.tar.gz".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-macos".to_string());
                        map.insert("darwin_arm64".to_string(), "arm64-macos".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-linux".to_string());
                        map.insert("linux_arm64".to_string(), "arm64-linux".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-windows".to_string());
                        map.insert("windows_arm64".to_string(), "arm64-windows".to_string());
                        map
                    },
                },
                tag_prefix: Some("wasi-sdk-".to_string()),
                version_filter: VersionFilter::Any,
            },
        );

        // nodejs configuration
        // Uses LtsOnly filter to only accept even-numbered major versions (20, 22, 24, etc.)
        tools.insert(
            "nodejs".to_string(),
            ToolConfigEntry {
                github_repo: "nodejs/node".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::Custom {
                    pattern: "https://nodejs.org/dist/v{version}/node-v{version}-{platform}.tar.gz"
                        .to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "darwin-x64".to_string());
                        map.insert("darwin_arm64".to_string(), "darwin-arm64".to_string());
                        map.insert("linux_amd64".to_string(), "linux-x64".to_string());
                        map.insert("linux_arm64".to_string(), "linux-arm64".to_string());
                        map.insert("windows_amd64".to_string(), "win-x64".to_string());
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::LtsOnly,
            },
        );

        // Note: wizer removed - now part of wasmtime v39.0.0+, use `wasmtime wizer` subcommand

        // wkg configuration
        tools.insert(
            "wkg".to_string(),
            ToolConfigEntry {
                github_repo: "bytecodealliance/wasm-pkg-tools".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::Custom {
                    pattern: "https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v{version}/wkg-{platform}".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-apple-darwin".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-apple-darwin".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-unknown-linux-gnu".to_string());
                        map.insert("linux_arm64".to_string(), "aarch64-unknown-linux-gnu".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-pc-windows-gnu".to_string());
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
            },
        );

        // tinygo configuration
        // Note: Windows uses .zip instead of .tar.gz, so we skip it in automated updates
        // Windows checksums need to be added manually
        tools.insert(
            "tinygo".to_string(),
            ToolConfigEntry {
                github_repo: "tinygo-org/tinygo".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    // Note: windows_amd64 excluded - uses .zip extension
                ],
                url_pattern: UrlPattern::Custom {
                    pattern: "https://github.com/tinygo-org/tinygo/releases/download/v{version}/tinygo{version}.{platform}.tar.gz".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "darwin-amd64".to_string());
                        map.insert("darwin_arm64".to_string(), "darwin-arm64".to_string());
                        map.insert("linux_amd64".to_string(), "linux-amd64".to_string());
                        map.insert("linux_arm64".to_string(), "linux-arm64".to_string());
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
            },
        );

        // loom, the optimizer. v0.3.0 was the last release shipping the
        // universal `loom.wasm`; from v1.x loom ships per-platform native
        // tarballs (`loom-v{version}-{triple}.tar.gz`, `.zip` on Windows) and the
        // toolchain (tool_registry.bzl loom: `filename: "{suffix}"`) reads the
        // full versioned filename as the registry `url_suffix`. That needs
        // PerPlatformVersionedAsset — UniversalWasm/AssetExists kept the updater
        // stuck at v0.3.0 (#514 migrated the registry + toolchain to native).
        tools.insert(
            "loom".to_string(),
            ToolConfigEntry {
                github_repo: "pulseengine/loom".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::PerPlatformVersionedAsset {
                    filename_pattern: "loom-v{version}-{platform}".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "x86_64-apple-darwin.tar.gz".to_string());
                        map.insert("darwin_arm64".to_string(), "aarch64-apple-darwin.tar.gz".to_string());
                        map.insert("linux_amd64".to_string(), "x86_64-unknown-linux-gnu.tar.gz".to_string());
                        map.insert("windows_amd64".to_string(), "x86_64-pc-windows-msvc.zip".to_string());
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
            },
        );

        tools.insert(
            "file-ops-component".to_string(),
            ToolConfigEntry {
                github_repo: "pulseengine/bazel-file-ops-component".to_string(),
                platforms: vec!["wasm_component".to_string()],
                url_pattern: UrlPattern::UniversalWasm {
                    asset_name: "file_ops_component.wasm".to_string(),
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::AssetExists,
            },
        );

        // wsc (github_repo pulseengine/sigil), the signing tool. Early releases
        // were dual-natured (per-OS CLI binaries plus a wasm CLI module
        // wsc-cli.wasm), but wsc-cli.wasm was capped at v0.7.0 and later releases
        // drop it — from v0.9.x the registry uses only per-OS native binaries, so
        // PerPlatformAsset (version-less asset names, mixed extension: bare unix
        // binaries vs `.exe` on Windows) describes it cleanly. Closes the #498
        // tail. NOTE: bumping wsc advances the signing toolchain — surface any
        // wsc version change for signing-path review before shipping.
        tools.insert(
            "wsc".to_string(),
            ToolConfigEntry {
                github_repo: "pulseengine/sigil".to_string(),
                platforms: vec![
                    "darwin_amd64".to_string(),
                    "darwin_arm64".to_string(),
                    "linux_amd64".to_string(),
                    "linux_arm64".to_string(),
                    "windows_amd64".to_string(),
                ],
                url_pattern: UrlPattern::PerPlatformAsset {
                    pattern: "https://github.com/pulseengine/sigil/releases/download/v{version}/{asset}".to_string(),
                    platform_mapping: {
                        let mut map = HashMap::new();
                        map.insert("darwin_amd64".to_string(), "wsc-macos-x86_64".to_string());
                        map.insert("darwin_arm64".to_string(), "wsc-macos-aarch64".to_string());
                        map.insert("linux_amd64".to_string(), "wsc-linux-x86_64".to_string());
                        map.insert("linux_arm64".to_string(), "wsc-linux-aarch64".to_string());
                        map.insert("windows_amd64".to_string(), "wsc-windows-x86_64.exe".to_string());
                        map
                    },
                },
                tag_prefix: Some("v".to_string()),
                version_filter: VersionFilter::Any,
            },
        );

        // PulseEngine verification/synthesis toolchains, all per-OS native
        // archives named `<tool>-v{version}-{triple}.{ext}` (mixed extension:
        // .tar.gz on unix, .zip on Windows where a Windows build exists), so all
        // fit PerPlatformAsset with the stored url_suffix being the triple. They
        // were previously unmanaged and drifted far behind upstream (#539).
        for (tool, repo, has_windows) in [
            ("spar", "pulseengine/spar", true),
            ("synth", "pulseengine/synth", false),
            ("witness", "pulseengine/witness", true),
        ] {
            let mut platform_mapping = HashMap::new();
            platform_mapping.insert("darwin_amd64".to_string(), "x86_64-apple-darwin.tar.gz".to_string());
            platform_mapping.insert("darwin_arm64".to_string(), "aarch64-apple-darwin.tar.gz".to_string());
            platform_mapping.insert("linux_amd64".to_string(), "x86_64-unknown-linux-gnu.tar.gz".to_string());
            platform_mapping.insert("linux_arm64".to_string(), "aarch64-unknown-linux-gnu.tar.gz".to_string());
            let mut platforms = vec![
                "darwin_amd64".to_string(),
                "darwin_arm64".to_string(),
                "linux_amd64".to_string(),
                "linux_arm64".to_string(),
            ];
            if has_windows {
                platform_mapping.insert("windows_amd64".to_string(), "x86_64-pc-windows-msvc.zip".to_string());
                platforms.push("windows_amd64".to_string());
            }
            tools.insert(
                tool.to_string(),
                ToolConfigEntry {
                    github_repo: repo.to_string(),
                    platforms: platforms,
                    url_pattern: UrlPattern::PerPlatformAsset {
                        pattern: format!(
                            "https://github.com/{}/releases/download/v{{version}}/{}-v{{version}}-{{asset}}",
                            repo, tool,
                        ),
                        platform_mapping: platform_mapping,
                    },
                    tag_prefix: Some("v".to_string()),
                    version_filter: VersionFilter::Any,
                },
            );
        }

        // meld is deliberately NOT wired in here yet: between the pinned v0.10.0
        // (standalone binaries `meld-{triple}`) and current v0.37.0 it migrated
        // to versioned tarballs (`meld-v{version}-{triple}.tar.gz`). Adopting it
        // needs a toolchain-side migration (extraction + versioned filename, like
        // loom's #514), not just an updater entry. Tracked as a follow-up.

        // wasmsign2-cli has no GitHub releases (tag/CI only). jco uses the npm
        // ecosystem, not GitHub release assets.

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
            tag_prefix: Some("v".to_string()),
            version_filter: VersionFilter::Any,
        }
    }
}

impl VersionFilter {
    /// Check if a version passes the filter
    pub fn accepts(&self, version: &str) -> bool {
        match self {
            // AssetExists is resolved in the update engine against each release's
            // asset list; by version string alone it accepts everything.
            VersionFilter::Any | VersionFilter::AssetExists => true,
            VersionFilter::LtsOnly => {
                // For Node.js, even major versions are LTS (20, 22, 24, etc.)
                // Odd major versions are "Current" (21, 23, 25, etc.)
                if let Ok(semver) = semver::Version::parse(version) {
                    semver.major % 2 == 0
                } else {
                    // If we can't parse the version, try to extract major version
                    version
                        .split('.')
                        .next()
                        .and_then(|major| major.parse::<u64>().ok())
                        .map(|major| major % 2 == 0)
                        .unwrap_or(false)
                }
            }
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
            UrlPattern::Custom {
                pattern,
                platform_mapping,
            } => {
                let platform_name = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Unsupported platform: {}", platform))?;

                let url = pattern
                    .replace("{version}", version)
                    .replace("{platform}", platform_name);

                Ok(url)
            }
            UrlPattern::UniversalWasm { asset_name } => Ok(format!(
                "https://github.com/{}/releases/download/v{}/{}",
                self.github_repo, version, asset_name
            )),
            UrlPattern::PerPlatformAsset {
                pattern,
                platform_mapping,
            } => {
                let asset = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Unsupported platform: {}", platform))?;
                Ok(pattern
                    .replace("{version}", version)
                    .replace("{asset}", asset))
            }
            UrlPattern::PerPlatformVersionedAsset { .. } => {
                let filename = self.versioned_filename(version, platform)?;
                Ok(format!(
                    "https://github.com/{}/releases/download/v{}/{}",
                    self.github_repo, version, filename
                ))
            }
        }
    }

    /// Resolve the full per-platform filename for a `PerPlatformVersionedAsset`
    /// tool. This is both the download asset name and the verbatim registry
    /// `url_suffix`, so the two can never drift.
    fn versioned_filename(&self, version: &str, platform: &str) -> Result<String> {
        match &self.url_pattern {
            UrlPattern::PerPlatformVersionedAsset {
                filename_pattern,
                platform_mapping,
            } => {
                let platform_value = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Unsupported platform: {}", platform))?;
                Ok(filename_pattern
                    .replace("{version}", version)
                    .replace("{platform}", platform_value))
            }
            _ => Err(anyhow::anyhow!(
                "versioned_filename called on non-versioned pattern"
            )),
        }
    }

    /// Asset name for a universal-wasm tool, if this is one.
    pub fn universal_asset_name(&self) -> Option<&str> {
        match &self.url_pattern {
            UrlPattern::UniversalWasm { asset_name } => Some(asset_name),
            _ => None,
        }
    }

    /// Check if this tool uses platform names instead of URL suffixes
    pub fn has_platform_names(&self) -> bool {
        matches!(self.url_pattern, UrlPattern::SingleBinary { .. })
    }

    /// Get platform name for JSON storage
    pub fn get_platform_name(&self, platform: &str) -> Result<String> {
        match &self.url_pattern {
            UrlPattern::SingleBinary { platform_mapping } => platform_mapping
                .get(platform)
                .cloned()
                .with_context(|| format!("Platform {} not found", platform)),
            _ => Err(anyhow::anyhow!("Tool does not use platform names")),
        }
    }

    /// Get URL suffix for JSON storage. `version` is only consulted by patterns
    /// whose stored suffix embeds the version (PerPlatformVersionedAsset).
    pub fn get_url_suffix(&self, version: &str, platform: &str) -> Result<String> {
        match &self.url_pattern {
            UrlPattern::StandardTarball { platform_mapping } => {
                let platform_name = platform_mapping
                    .get(platform)
                    .with_context(|| format!("Platform {} not found", platform))?;
                Ok(format!("{}.tar.gz", platform_name))
            }
            UrlPattern::Custom {
                platform_mapping, ..
            } => {
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
            UrlPattern::UniversalWasm { asset_name } => Ok(asset_name.clone()),
            UrlPattern::PerPlatformAsset {
                platform_mapping, ..
            } => platform_mapping
                .get(platform)
                .cloned()
                .with_context(|| format!("Platform {} not found", platform)),
            UrlPattern::PerPlatformVersionedAsset { .. } => {
                self.versioned_filename(version, platform)
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
        assert!(wasm_tools_config
            .platforms
            .contains(&"linux_amd64".to_string()));
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
            .get_url_suffix("1.240.0", "linux_amd64")
            .unwrap();
        assert_eq!(suffix, "x86_64-linux.tar.gz");
    }

    #[test]
    fn test_get_platform_name() {
        let config = ToolConfig::new();
        let wac_config = config.get_tool_config("wac");

        let platform_name = wac_config.get_platform_name("linux_amd64").unwrap();
        assert_eq!(platform_name, "x86_64-unknown-linux-musl");
    }

    #[test]
    fn test_per_platform_asset_wit_bindgen_windows_zip() {
        let config = ToolConfig::new();
        let wb = config.get_tool_config("wit-bindgen");
        // Windows must be .zip (the bug: StandardTarball forced .tar.gz -> 404).
        assert_eq!(
            wb.generate_download_url("0.58.0", "windows_amd64").unwrap(),
            "https://github.com/bytecodealliance/wit-bindgen/releases/download/v0.58.0/wit-bindgen-0.58.0-x86_64-windows.zip"
        );
        assert_eq!(
            wb.get_url_suffix("0.58.0", "windows_amd64").unwrap(),
            "x86_64-windows.zip"
        );
        // Unix stays .tar.gz.
        assert_eq!(
            wb.generate_download_url("0.58.0", "linux_amd64").unwrap(),
            "https://github.com/bytecodealliance/wit-bindgen/releases/download/v0.58.0/wit-bindgen-0.58.0-x86_64-linux.tar.gz"
        );
        assert_eq!(
            wb.get_url_suffix("0.58.0", "linux_amd64").unwrap(),
            "x86_64-linux.tar.gz"
        );
        assert!(!wb.has_platform_names());
    }

    #[test]
    fn test_per_platform_asset_wasmtime_mixed_ext() {
        let config = ToolConfig::new();
        let wt = config.get_tool_config("wasmtime");
        assert_eq!(wt.github_repo, "bytecodealliance/wasmtime");
        assert_eq!(
            wt.generate_download_url("45.0.1", "linux_amd64").unwrap(),
            "https://github.com/bytecodealliance/wasmtime/releases/download/v45.0.1/wasmtime-v45.0.1-x86_64-linux.tar.xz"
        );
        assert_eq!(
            wt.get_url_suffix("45.0.1", "linux_amd64").unwrap(),
            "x86_64-linux.tar.xz"
        );
        assert_eq!(
            wt.generate_download_url("45.0.1", "windows_amd64").unwrap(),
            "https://github.com/bytecodealliance/wasmtime/releases/download/v45.0.1/wasmtime-v45.0.1-x86_64-windows.zip"
        );
        assert_eq!(
            wt.get_url_suffix("45.0.1", "windows_amd64").unwrap(),
            "x86_64-windows.zip"
        );
    }

    #[test]
    fn test_per_platform_versioned_asset_loom_native() {
        let config = ToolConfig::new();
        let loom = config.get_tool_config("loom");

        assert_eq!(loom.github_repo, "pulseengine/loom");
        assert!(matches!(loom.version_filter, VersionFilter::Any));
        assert!(!loom.has_platform_names());

        // The stored url_suffix must be the FULL versioned filename the toolchain
        // reads verbatim, and must match the hand-authored #513 registry block
        // exactly — else the loom toolchain download breaks on the next release.
        assert_eq!(
            loom.generate_download_url("1.1.14", "darwin_arm64").unwrap(),
            "https://github.com/pulseengine/loom/releases/download/v1.1.14/loom-v1.1.14-aarch64-apple-darwin.tar.gz"
        );
        assert_eq!(
            loom.get_url_suffix("1.1.14", "darwin_arm64").unwrap(),
            "loom-v1.1.14-aarch64-apple-darwin.tar.gz"
        );
        assert_eq!(
            loom.get_url_suffix("1.1.14", "linux_amd64").unwrap(),
            "loom-v1.1.14-x86_64-unknown-linux-gnu.tar.gz"
        );
        // Windows is .zip (mixed extension).
        assert_eq!(
            loom.get_url_suffix("1.1.14", "windows_amd64").unwrap(),
            "loom-v1.1.14-x86_64-pc-windows-msvc.zip"
        );
    }

    #[test]
    fn test_universal_wasm_file_ops() {
        let config = ToolConfig::new();
        let fo = config.get_tool_config("file-ops-component");
        assert_eq!(fo.github_repo, "pulseengine/bazel-file-ops-component");
        assert_eq!(fo.universal_asset_name(), Some("file_ops_component.wasm"));
        let url = fo.generate_download_url("0.2.0", "wasm_component").unwrap();
        assert_eq!(
            url,
            "https://github.com/pulseengine/bazel-file-ops-component/releases/download/v0.2.0/file_ops_component.wasm"
        );
    }

    #[test]
    fn test_non_universal_has_no_asset_name() {
        let config = ToolConfig::new();
        assert_eq!(
            config.get_tool_config("wasm-tools").universal_asset_name(),
            None
        );
    }

    #[test]
    fn test_default_config_for_unknown_tool() {
        let config = ToolConfig::new();
        let unknown_config = config.get_tool_config("unknown-tool");

        assert_eq!(unknown_config.github_repo, "bytecodealliance/unknown-tool");
        assert!(unknown_config
            .platforms
            .contains(&"linux_amd64".to_string()));
    }
}
