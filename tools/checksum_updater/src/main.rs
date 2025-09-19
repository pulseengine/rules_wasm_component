/*!
# Checksum Updater Tool

Automated tool for updating WebAssembly tool checksums from GitHub releases.

This tool:
- Fetches latest releases from GitHub repositories
- Downloads and validates checksums for multiple platforms
- Updates JSON checksum files
- Generates update summaries and reports
- Integrates with CI/CD workflows

## Usage

```bash
# Update all tools
checksum_updater update-all

# Update specific tools
checksum_updater update --tools wasm-tools,wit-bindgen

# Validate existing checksums
checksum_updater validate --all

# Generate summary report
checksum_updater generate-summary results.json
```
*/

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use regex::Regex;
use serde_json;
use std::path::PathBuf;
use tracing::{info, warn};

use checksum_updater::{
    ChecksumManager, ChecksumValidator, UpdateConfig, UpdateEngine, UpdateResults,
    ValidationResults,
};

/// Automated WebAssembly tool checksum updater
#[derive(Parser)]
#[command(name = "checksum_updater")]
#[command(about = "Automated tool for updating WebAssembly tool checksums")]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Enable verbose logging
    #[arg(short, long, global = true)]
    verbose: bool,

    /// Output format for results
    #[arg(long, global = true, value_enum, default_value = "human")]
    output_format: OutputFormat,

    /// Working directory (defaults to repository root)
    #[arg(long, global = true)]
    working_dir: Option<PathBuf>,
}

#[derive(Clone, Debug, clap::ValueEnum)]
enum OutputFormat {
    Human,
    Json,
    Markdown,
}

#[derive(Subcommand)]
enum Commands {
    /// Update checksums for all tools
    UpdateAll {
        /// Force update even if no new versions found
        #[arg(long)]
        force: bool,

        /// Perform dry run without making changes
        #[arg(long)]
        dry_run: bool,

        /// Skip tools that have update errors
        #[arg(long)]
        skip_errors: bool,
    },
    /// Update checksums for specific tools
    Update {
        /// Comma-separated list of tools to update
        #[arg(long, required = true)]
        tools: String,

        /// Force update even if no new versions found
        #[arg(long)]
        force: bool,

        /// Perform dry run without making changes
        #[arg(long)]
        dry_run: bool,
    },
    /// Validate existing checksums
    Validate {
        /// Validate all tools
        #[arg(long, conflicts_with = "tools")]
        all: bool,

        /// Comma-separated list of tools to validate
        #[arg(long)]
        tools: Option<String>,

        /// Fix validation errors if possible
        #[arg(long)]
        fix: bool,
    },
    /// Generate update summary from results file
    GenerateSummary {
        /// Path to results JSON file
        results_file: PathBuf,
    },
    /// List available tools and their current versions
    List {
        /// Show detailed information
        #[arg(long)]
        detailed: bool,

        /// Filter by tool name pattern
        #[arg(long)]
        filter: Option<String>,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize tracing
    init_tracing(cli.verbose)?;

    // Change to working directory if specified
    if let Some(working_dir) = &cli.working_dir {
        std::env::set_current_dir(working_dir)
            .with_context(|| format!("Failed to change to directory: {}", working_dir.display()))?;
    }

    // Execute the command
    let result = match cli.command {
        Commands::UpdateAll {
            force,
            dry_run,
            skip_errors,
        } => update_all_tools(force, dry_run, skip_errors, &cli.output_format).await,
        Commands::Update {
            tools,
            force,
            dry_run,
        } => update_specific_tools(&tools, force, dry_run, &cli.output_format).await,
        Commands::Validate { all, tools, fix } => {
            validate_checksums(all, tools.as_deref(), fix, &cli.output_format).await
        }
        Commands::GenerateSummary { results_file } => {
            generate_summary(&results_file, &cli.output_format).await
        }
        Commands::List { detailed, filter } => {
            list_tools(detailed, filter.as_deref(), &cli.output_format).await
        }
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }

    Ok(())
}

/// Initialize tracing subscriber
fn init_tracing(verbose: bool) -> Result<()> {
    use tracing_subscriber::{fmt, EnvFilter};

    let filter = if verbose {
        EnvFilter::new("checksum_updater=debug,info")
    } else {
        EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new("checksum_updater=info"))
    };

    fmt()
        .with_env_filter(filter)
        .with_target(false)
        .with_thread_ids(false)
        .with_line_number(verbose)
        .init();

    Ok(())
}

/// Update checksums for all available tools
async fn update_all_tools(
    force: bool,
    dry_run: bool,
    skip_errors: bool,
    output_format: &OutputFormat,
) -> Result<()> {
    info!("Starting update for all tools");

    let manager = ChecksumManager::new().await?;
    let mut engine = UpdateEngine::new(manager);

    let all_tools = engine.list_available_tools().await?;
    info!("Found {} tools to update", all_tools.len());

    let update_config = UpdateConfig {
        force,
        dry_run,
        skip_errors,
        parallel: true,
        timeout_seconds: 300, // 5 minutes per tool
    };

    let results = engine.update_tools(&all_tools, &update_config).await?;

    output_results(&results, output_format)?;

    if results.has_errors() && !skip_errors {
        warn!("Some tools failed to update");
        std::process::exit(1);
    }

    Ok(())
}

/// Update checksums for specific tools
async fn update_specific_tools(
    tools_str: &str,
    force: bool,
    dry_run: bool,
    output_format: &OutputFormat,
) -> Result<()> {
    let tools: Vec<String> = tools_str
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    info!("Starting update for tools: {:?}", tools);

    let manager = ChecksumManager::new().await?;
    let mut engine = UpdateEngine::new(manager);

    let update_config = UpdateConfig {
        force,
        dry_run,
        skip_errors: false,
        parallel: true,
        timeout_seconds: 300,
    };

    let results = engine.update_tools(&tools, &update_config).await?;

    output_results(&results, output_format)?;

    if results.has_errors() {
        warn!("Some tools failed to update");
        std::process::exit(1);
    }

    Ok(())
}

/// Validate existing checksums
async fn validate_checksums(
    all: bool,
    tools: Option<&str>,
    fix: bool,
    output_format: &OutputFormat,
) -> Result<()> {
    info!("Starting checksum validation");

    let manager = ChecksumManager::new().await?;
    let validator = ChecksumValidator::new();

    let tools_to_validate = if all {
        manager.list_all_tools().await?
    } else if let Some(tools_str) = tools {
        tools_str
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect()
    } else {
        return Err(anyhow::anyhow!("Must specify either --all or --tools"));
    };

    let validation_results = validator
        .validate_tools(&tools_to_validate, &manager, fix)
        .await?;

    output_validation_results(&validation_results, output_format)?;

    if validation_results.has_errors() {
        warn!("Validation failed for some tools");
        std::process::exit(1);
    }

    Ok(())
}

/// Generate summary from results file
async fn generate_summary(results_file: &PathBuf, output_format: &OutputFormat) -> Result<()> {
    let results_content = tokio::fs::read_to_string(results_file)
        .await
        .with_context(|| format!("Failed to read results file: {}", results_file.display()))?;

    let results: UpdateResults =
        serde_json::from_str(&results_content).context("Failed to parse results JSON")?;

    generate_update_summary(&results, output_format)?;

    Ok(())
}

/// List available tools
async fn list_tools(
    detailed: bool,
    filter: Option<&str>,
    output_format: &OutputFormat,
) -> Result<()> {
    let manager = ChecksumManager::new().await?;
    let tools = manager.list_all_tools().await?;

    let filtered_tools: Vec<String> = if let Some(filter_pattern) = filter {
        let regex = Regex::new(filter_pattern)
            .with_context(|| format!("Invalid filter pattern: {}", filter_pattern))?;
        tools
            .into_iter()
            .filter(|tool| regex.is_match(tool))
            .collect()
    } else {
        tools
    };

    output_tool_list(&filtered_tools, detailed, &manager, output_format).await?;

    Ok(())
}

/// Output update results in the specified format
fn output_results(results: &UpdateResults, format: &OutputFormat) -> Result<()> {
    match format {
        OutputFormat::Human => {
            println!("=== Update Results ===");
            println!("Tools updated: {}", results.summary.tools_updated);
            println!("New versions found: {}", results.summary.new_versions_found);
            println!("Errors: {}", results.summary.errors);
            println!("Duration: {:?}", results.summary.duration);

            if !results.updates.is_empty() {
                println!("\n=== Updates ===");
                for update in &results.updates {
                    println!(
                        "✅ {}: {} → {} ({})",
                        update.tool_name,
                        update.old_version.as_deref().unwrap_or("none"),
                        update.new_version,
                        update.version_change
                    );
                }
            }

            if !results.errors.is_empty() {
                println!("\n=== Errors ===");
                for error in &results.errors {
                    println!("❌ {}: {}", error.tool_name, error.message);
                }
            }
        }
        OutputFormat::Json => {
            println!("{}", serde_json::to_string_pretty(results)?);
        }
        OutputFormat::Markdown => {
            generate_update_summary(results, format)?;
        }
    }

    Ok(())
}

/// Output validation results
fn output_validation_results(results: &ValidationResults, format: &OutputFormat) -> Result<()> {
    match format {
        OutputFormat::Human => {
            println!("=== Validation Results ===");
            println!("Tools validated: {}", results.tools_validated);
            println!("Valid checksums: {}", results.valid_checksums);
            println!("Invalid checksums: {}", results.invalid_checksums);
            println!("Fixed checksums: {}", results.fixed_checksums);

            if !results.errors.is_empty() {
                println!("\n=== Validation Errors ===");
                for error in &results.errors {
                    println!("❌ {}: {}", error.tool_name, error.message);
                }
            }
        }
        OutputFormat::Json => {
            println!("{}", serde_json::to_string_pretty(results)?);
        }
        OutputFormat::Markdown => {
            println!("## Validation Results");
            println!("- **Tools validated**: {}", results.tools_validated);
            println!("- **Valid checksums**: {}", results.valid_checksums);
            println!("- **Invalid checksums**: {}", results.invalid_checksums);
            println!("- **Fixed checksums**: {}", results.fixed_checksums);

            if !results.errors.is_empty() {
                println!("\n### Validation Errors");
                for error in &results.errors {
                    println!("- **{}**: {}", error.tool_name, error.message);
                }
            }
        }
    }

    Ok(())
}

/// Generate update summary in markdown format
fn generate_update_summary(results: &UpdateResults, format: &OutputFormat) -> Result<()> {
    match format {
        OutputFormat::Markdown => {
            println!("### 📊 Update Summary");
            println!();
            println!("- **Tools processed**: {}", results.summary.tools_processed);
            println!("- **Tools updated**: {}", results.summary.tools_updated);
            println!(
                "- **New versions found**: {}",
                results.summary.new_versions_found
            );
            println!("- **Errors encountered**: {}", results.summary.errors);
            println!("- **Duration**: {:?}", results.summary.duration);
            println!();

            if !results.updates.is_empty() {
                println!("### ✅ Successfully Updated");
                println!();
                for update in &results.updates {
                    let change_emoji = match update.version_change.as_str() {
                        "major" => "🚨",
                        "minor" => "✨",
                        "patch" => "🔧",
                        _ => "📦",
                    };
                    println!(
                        "- {} **{}**: `{}` → `{}` ({})",
                        change_emoji,
                        update.tool_name,
                        update.old_version.as_deref().unwrap_or("none"),
                        update.new_version,
                        update.version_change
                    );
                }
                println!();
            }

            if !results.errors.is_empty() {
                println!("### ❌ Errors");
                println!();
                for error in &results.errors {
                    println!("- **{}**: {}", error.tool_name, error.message);
                }
                println!();
            }

            println!("### 🔍 Details");
            println!();
            for update in &results.updates {
                println!("#### {}", update.tool_name);
                println!(
                    "- **Version**: {} → {}",
                    update.old_version.as_deref().unwrap_or("none"),
                    update.new_version
                );
                println!("- **Change type**: {}", update.version_change);
                if let Some(release_notes) = &update.release_notes_url {
                    println!("- **Release notes**: [View changes]({})", release_notes);
                }
                println!("- **Platforms updated**: {}", update.platforms_updated);
                println!();
            }
        }
        _ => {
            // Fall back to regular output for non-markdown formats
            output_results(results, format)?;
        }
    }

    Ok(())
}

/// Output tool list
async fn output_tool_list(
    tools: &[String],
    detailed: bool,
    manager: &ChecksumManager,
    format: &OutputFormat,
) -> Result<()> {
    match format {
        OutputFormat::Human => {
            println!("=== Available Tools ({}) ===", tools.len());
            for tool in tools {
                if detailed {
                    if let Ok(info) = manager.get_tool_info(tool).await {
                        println!(
                            "📦 {} (latest: {}, repo: {})",
                            tool, info.latest_version, info.github_repo
                        );
                        println!("   Platforms: {}", info.supported_platforms.join(", "));
                    } else {
                        println!("📦 {} (info unavailable)", tool);
                    }
                } else {
                    println!("📦 {}", tool);
                }
            }
        }
        OutputFormat::Json => {
            if detailed {
                let mut detailed_info = Vec::new();
                for tool in tools {
                    match manager.get_tool_info(tool).await {
                        Ok(info) => detailed_info.push(serde_json::json!({
                            "name": tool,
                            "latest_version": info.latest_version,
                            "github_repo": info.github_repo,
                            "supported_platforms": info.supported_platforms,
                            "last_checked": info.last_checked
                        })),
                        Err(_) => detailed_info.push(serde_json::json!({
                            "name": tool,
                            "error": "info unavailable"
                        })),
                    }
                }
                println!("{}", serde_json::to_string_pretty(&detailed_info)?);
            } else {
                println!("{}", serde_json::to_string_pretty(tools)?);
            }
        }
        OutputFormat::Markdown => {
            println!("## Available Tools ({})", tools.len());
            println!();
            for tool in tools {
                if detailed {
                    if let Ok(info) = manager.get_tool_info(tool).await {
                        println!(
                            "- **{}** (latest: {}) - [{}](https://github.com/{})",
                            tool, info.latest_version, info.github_repo, info.github_repo
                        );
                        println!("  - Platforms: {}", info.supported_platforms.join(", "));
                    } else {
                        println!("- **{}** (info unavailable)", tool);
                    }
                } else {
                    println!("- {}", tool);
                }
            }
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cli_parsing() {
        // Test update-all command
        let cli = Cli::try_parse_from(&["checksum_updater", "update-all", "--force", "--dry-run"]);
        assert!(cli.is_ok());

        // Test update command
        let cli = Cli::try_parse_from(&[
            "checksum_updater",
            "update",
            "--tools",
            "wasm-tools,wit-bindgen",
        ]);
        assert!(cli.is_ok());

        // Test validate command
        let cli = Cli::try_parse_from(&["checksum_updater", "validate", "--all"]);
        assert!(cli.is_ok());
    }

    #[test]
    fn test_output_format_parsing() {
        let cli = Cli::try_parse_from(&["checksum_updater", "--output-format", "json", "list"]);
        assert!(cli.is_ok());

        match cli.unwrap().output_format {
            OutputFormat::Json => (),
            _ => panic!("Expected JSON format"),
        }
    }
}
