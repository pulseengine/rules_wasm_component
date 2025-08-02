use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use clap::{Arg, Command};
use futures_util::StreamExt;
use octocrab::{models::repos::Release, Octocrab};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use tempfile::NamedTempFile;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PlatformInfo {
    sha256: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    url_suffix: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    platform_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    binary_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    npm_package: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    npm_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    install_method: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct VersionInfo {
    release_date: String,
    platforms: HashMap<String, PlatformInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ToolConfig {
    tool_name: String,
    github_repo: String,
    latest_version: String,
    last_checked: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    note: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    install_method: Option<String>,
    versions: HashMap<String, VersionInfo>,
}

#[derive(Debug, Clone)]
struct ToolPattern {
    name: String,
    repo: String,
    url_patterns: Vec<PlatformPattern>,
    version_prefix: Option<String>,
}

#[derive(Debug, Clone)]
struct PlatformPattern {
    platform: String,
    url_template: String,
    additional_fields: HashMap<String, String>,
}

impl ToolPattern {
    fn new(name: &str, repo: &str) -> Self {
        Self {
            name: name.to_string(),
            repo: repo.to_string(),
            url_patterns: vec![],
            version_prefix: None,
        }
    }

    fn with_version_prefix(mut self, prefix: &str) -> Self {
        self.version_prefix = Some(prefix.to_string());
        self
    }

    fn add_platform(mut self, platform: &str, url_template: &str) -> Self {
        self.url_patterns.push(PlatformPattern {
            platform: platform.to_string(),
            url_template: url_template.to_string(),
            additional_fields: HashMap::new(),
        });
        self
    }

    fn add_platform_with_fields(
        mut self,
        platform: &str,
        url_template: &str,
        fields: HashMap<String, String>,
    ) -> Self {
        self.url_patterns.push(PlatformPattern {
            platform: platform.to_string(),
            url_template: url_template.to_string(),
            additional_fields: fields,
        });
        self
    }
}

fn get_tool_patterns() -> Vec<ToolPattern> {
    vec![
        ToolPattern::new("wasm-tools", "bytecodealliance/wasm-tools")
            .with_version_prefix("v")
            .add_platform(
                "darwin_amd64",
                "https://github.com/bytecodealliance/wasm-tools/releases/download/v{version}/wasm-tools-{version}-x86_64-macos.tar.gz",
            )
            .add_platform(
                "darwin_arm64", 
                "https://github.com/bytecodealliance/wasm-tools/releases/download/v{version}/wasm-tools-{version}-aarch64-macos.tar.gz",
            )
            .add_platform(
                "linux_amd64",
                "https://github.com/bytecodealliance/wasm-tools/releases/download/v{version}/wasm-tools-{version}-x86_64-linux.tar.gz",
            )
            .add_platform(
                "linux_arm64",
                "https://github.com/bytecodealliance/wasm-tools/releases/download/v{version}/wasm-tools-{version}-aarch64-linux.tar.gz",
            )
            .add_platform(
                "windows_amd64",
                "https://github.com/bytecodealliance/wasm-tools/releases/download/v{version}/wasm-tools-{version}-x86_64-windows.tar.gz",
            ),
        ToolPattern::new("wit-bindgen", "bytecodealliance/wit-bindgen")
            .with_version_prefix("v")
            .add_platform(
                "darwin_amd64",
                "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{version}/wit-bindgen-{version}-x86_64-macos.tar.gz",
            )
            .add_platform(
                "darwin_arm64",
                "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{version}/wit-bindgen-{version}-aarch64-macos.tar.gz",
            )
            .add_platform(
                "linux_amd64",
                "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{version}/wit-bindgen-{version}-x86_64-linux.tar.gz",
            )
            .add_platform(
                "linux_arm64",
                "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{version}/wit-bindgen-{version}-aarch64-linux.tar.gz",
            )
            .add_platform(
                "windows_amd64",
                "https://github.com/bytecodealliance/wit-bindgen/releases/download/v{version}/wit-bindgen-{version}-x86_64-windows.zip",
            ),
        ToolPattern::new("wasmtime", "bytecodealliance/wasmtime")
            .with_version_prefix("v")
            .add_platform(
                "darwin_amd64",
                "https://github.com/bytecodealliance/wasmtime/releases/download/v{version}/wasmtime-v{version}-x86_64-macos.tar.xz",
            )
            .add_platform(
                "darwin_arm64",
                "https://github.com/bytecodealliance/wasmtime/releases/download/v{version}/wasmtime-v{version}-aarch64-macos.tar.xz",
            )
            .add_platform(
                "linux_amd64",
                "https://github.com/bytecodealliance/wasmtime/releases/download/v{version}/wasmtime-v{version}-x86_64-linux.tar.xz",
            )
            .add_platform(
                "linux_arm64",
                "https://github.com/bytecodealliance/wasmtime/releases/download/v{version}/wasmtime-v{version}-aarch64-linux.tar.xz",
            )
            .add_platform(
                "windows_amd64",
                "https://github.com/bytecodealliance/wasmtime/releases/download/v{version}/wasmtime-v{version}-x86_64-windows.zip",
            ),
        ToolPattern::new("wac", "bytecodealliance/wac")
            .with_version_prefix("v")
            .add_platform_with_fields(
                "darwin_amd64",
                "https://github.com/bytecodealliance/wac/releases/download/v{version}/wac-cli-x86_64-apple-darwin",
                [("platform_name".to_string(), "x86_64-apple-darwin".to_string())].into(),
            )
            .add_platform_with_fields(
                "darwin_arm64",
                "https://github.com/bytecodealliance/wac/releases/download/v{version}/wac-cli-aarch64-apple-darwin",
                [("platform_name".to_string(), "aarch64-apple-darwin".to_string())].into(),
            )
            .add_platform_with_fields(
                "linux_amd64",
                "https://github.com/bytecodealliance/wac/releases/download/v{version}/wac-cli-x86_64-unknown-linux-musl",
                [("platform_name".to_string(), "x86_64-unknown-linux-musl".to_string())].into(),
            )
            .add_platform_with_fields(
                "linux_arm64",
                "https://github.com/bytecodealliance/wac/releases/download/v{version}/wac-cli-aarch64-unknown-linux-musl",
                [("platform_name".to_string(), "aarch64-unknown-linux-musl".to_string())].into(),
            )
            .add_platform_with_fields(
                "windows_amd64",
                "https://github.com/bytecodealliance/wac/releases/download/v{version}/wac-cli-x86_64-pc-windows-gnu",
                [("platform_name".to_string(), "x86_64-pc-windows-gnu".to_string())].into(),
            ),
    ]
}

async fn fetch_latest_release(github: &Octocrab, repo: &str) -> Result<Release> {
    let (owner, repo_name) = repo
        .split_once('/')
        .context("Invalid repository format. Expected 'owner/repo'")?;

    github
        .repos(owner, repo_name)
        .releases()
        .get_latest()
        .await
        .context("Failed to fetch latest release")
}

async fn download_and_hash(url: &str) -> Result<String> {
    println!("Downloading and hashing: {}", url);

    let response = reqwest::get(url)
        .await
        .context("Failed to download file")?;

    if !response.status().is_success() {
        anyhow::bail!("Download failed with status: {}", response.status());
    }

    let mut hasher = Sha256::new();
    let mut stream = response.bytes_stream();

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.context("Failed to read chunk")?;
        hasher.update(&chunk);
    }

    let hash = hasher.finalize();
    Ok(format!("{:x}", hash))
}

async fn update_tool_checksums(
    checksums_dir: &Path,
    tool_pattern: &ToolPattern,
    dry_run: bool,
) -> Result<bool> {
    println!("Checking tool: {}", tool_pattern.name);

    let github = Octocrab::builder().build()?;
    let latest_release = fetch_latest_release(&github, &tool_pattern.repo).await?;

    let version = latest_release.tag_name.clone();
    let clean_version = if let Some(prefix) = &tool_pattern.version_prefix {
        version.strip_prefix(prefix).unwrap_or(&version)
    } else {
        &version
    };

    println!("Latest version: {} (clean: {})", version, clean_version);

    let config_path = checksums_dir.join("tools").join(format!("{}.json", tool_pattern.name));
    let mut config: ToolConfig = if config_path.exists() {
        let content = fs::read_to_string(&config_path)?;
        serde_json::from_str(&content)?
    } else {
        ToolConfig {
            tool_name: tool_pattern.name.clone(),
            github_repo: tool_pattern.repo.clone(),
            latest_version: clean_version.to_string(),
            last_checked: Utc::now(),
            note: None,
            install_method: None,
            versions: HashMap::new(),
        }
    };

    // Check if we already have this version
    if config.versions.contains_key(clean_version) {
        println!("Version {} already exists, skipping", clean_version);
        // Update last_checked time
        config.last_checked = Utc::now();
        if !dry_run {
            let updated_content = serde_json::to_string_pretty(&config)?;
            fs::write(&config_path, updated_content)?;
        }
        return Ok(false);
    }

    println!("New version {} found, calculating checksums...", clean_version);

    let mut platforms = HashMap::new();
    for platform_pattern in &tool_pattern.url_patterns {
        let url = platform_pattern
            .url_template
            .replace("{version}", clean_version);

        match download_and_hash(&url).await {
            Ok(checksum) => {
                println!("✅ {}: {}", platform_pattern.platform, checksum);

                let mut platform_info = PlatformInfo {
                    sha256: checksum,
                    url_suffix: None,
                    platform_name: None,
                    binary_name: None,
                    npm_package: None,
                    npm_version: None,
                    install_method: None,
                };

                // Add additional fields based on tool pattern
                for (key, value) in &platform_pattern.additional_fields {
                    match key.as_str() {
                        "platform_name" => platform_info.platform_name = Some(value.clone()),
                        "binary_name" => platform_info.binary_name = Some(value.clone()),
                        "url_suffix" => platform_info.url_suffix = Some(value.clone()),
                        _ => {}
                    }
                }

                // Infer url_suffix from URL if not provided
                if platform_info.url_suffix.is_none() {
                    if let Some(suffix) = url.split('/').last() {
                        if let Some(tool_and_suffix) = suffix.strip_prefix(&format!("{}-{}-", tool_pattern.name, clean_version)) {
                            platform_info.url_suffix = Some(tool_and_suffix.to_string());
                        } else if suffix.contains(&tool_pattern.name) {
                            // For wasmtime format: wasmtime-v{version}-{platform}.tar.xz
                            if let Some(platform_suffix) = suffix.split(&format!("v{}-", clean_version)).nth(1) {
                                platform_info.url_suffix = Some(platform_suffix.to_string());
                            }
                        }
                    }
                }

                platforms.insert(platform_pattern.platform.clone(), platform_info);
            }
            Err(e) => {
                println!("❌ Failed to download {}: {}", platform_pattern.platform, e);
            }
        }
    }

    if platforms.is_empty() {
        println!("❌ No platforms successfully processed");
        return Ok(false);
    }

    // Add new version to config
    config.versions.insert(
        clean_version.to_string(),
        VersionInfo {
            release_date: latest_release
                .published_at
                .map(|dt| dt.format("%Y-%m-%d").to_string())
                .unwrap_or_else(|| Utc::now().format("%Y-%m-%d").to_string()),
            platforms,
        },
    );

    config.latest_version = clean_version.to_string();
    config.last_checked = Utc::now();

    if !dry_run {
        let updated_content = serde_json::to_string_pretty(&config)?;
        fs::write(&config_path, updated_content)?;
        println!("✅ Updated {}", config_path.display());
    } else {
        println!("🔍 Would update {}", config_path.display());
    }

    Ok(true)
}

#[tokio::main]
async fn main() -> Result<()> {
    let matches = Command::new("Checksum Updater")
        .version("1.0")
        .about("Updates tool checksums by checking GitHub releases")
        .arg(
            Arg::new("checksums-dir")
                .long("checksums-dir")
                .value_name("DIR")
                .help("Path to checksums directory")
                .default_value("checksums"),
        )
        .arg(
            Arg::new("tool")
                .long("tool")
                .value_name("TOOL")
                .help("Update specific tool only"),
        )
        .arg(
            Arg::new("dry-run")
                .long("dry-run")
                .help("Show what would be updated without making changes")
                .action(clap::ArgAction::SetTrue),
        )
        .get_matches();

    let checksums_dir = Path::new(matches.get_one::<String>("checksums-dir").unwrap());
    let specific_tool = matches.get_one::<String>("tool");
    let dry_run = matches.get_flag("dry-run");

    if !checksums_dir.exists() {
        anyhow::bail!("Checksums directory does not exist: {}", checksums_dir.display());
    }

    let tool_patterns = get_tool_patterns();
    let mut any_updates = false;

    for tool_pattern in tool_patterns {
        if let Some(tool_filter) = specific_tool {
            if tool_pattern.name != *tool_filter {
                continue;
            }
        }

        match update_tool_checksums(checksums_dir, &tool_pattern, dry_run).await {
            Ok(updated) => {
                if updated {
                    any_updates = true;
                }
            }
            Err(e) => {
                eprintln!("❌ Failed to update {}: {}", tool_pattern.name, e);
            }
        }
    }

    if any_updates {
        println!("\n✅ Tool checksums updated successfully!");
        if !dry_run {
            println!("💡 Remember to test the updated checksums and commit the changes.");
        }
    } else {
        println!("\n📅 All tools are up to date.");
    }

    Ok(())
}