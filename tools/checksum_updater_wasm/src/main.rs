/*!
WebAssembly component binary for the checksum updater.

This serves as a command-line interface to the WebAssembly component,
demonstrating how WASI Preview 2 components can provide CLI functionality.
*/

use anyhow::Result;
use clap::{Parser, Subcommand};
use tracing::{info, Level};

// Import the component library
use checksum_updater_wasm_lib::{ChecksumUpdater, Bootstrap, UpdateConfig, UpdateResult, ValidationResult};

/// WebAssembly component version of checksum updater
#[derive(Parser)]
#[command(name = "checksum_updater_wasm")]
#[command(about = "WebAssembly component for automated checksum updates")]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    #[arg(short, long)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// List all available tools
    List,
    
    /// Update specific tools
    Update {
        #[arg(long)]
        tools: Vec<String>,
        
        #[arg(long)]
        dry_run: bool,
        
        #[arg(long)]
        force: bool,
    },
    
    /// Update all tools
    UpdateAll {
        #[arg(long)]
        dry_run: bool,
        
        #[arg(long)]
        force: bool,
    },
    
    /// Validate checksums
    Validate {
        #[arg(long)]
        tools: Vec<String>,
        
        #[arg(long)]
        fix: bool,
    },
    
    /// Check for self-updates
    SelfUpdate {
        #[arg(long)]
        check_only: bool,
    },
    
    /// Bootstrap information
    Bootstrap,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize tracing
    let level = if cli.verbose { Level::DEBUG } else { Level::INFO };
    tracing_subscriber::fmt()
        .with_max_level(level)
        .with_target(false)
        .init();

    info!("Starting WebAssembly checksum updater component");

    match cli.command {
        Commands::List => {
            let tools = ChecksumUpdater::list_tools().await
                .map_err(|e| anyhow::anyhow!("Failed to list tools: {}", e))?;
            
            println!("=== Available Tools ({}) ===", tools.len());
            for tool in tools {
                println!("📦 {}", tool);
            }
        }

        Commands::Update { tools, dry_run, force } => {
            let config = UpdateConfig {
                force,
                dry_run,
                skip_errors: true,
                timeout_seconds: 120,
            };

            let result = ChecksumUpdater::update_tools(tools.clone(), config).await
                .map_err(|e| anyhow::anyhow!("Update failed: {}", e))?;

            println!("=== Update Results ===");
            println!("Tools processed: {}", result.tools_processed);
            println!("Tools updated: {}", result.tools_updated);
            println!("New versions found: {}", result.new_versions_found);
            println!("Errors: {}", result.errors);
            println!("Duration: {}ms", result.duration_ms);
        }

        Commands::UpdateAll { dry_run, force } => {
            let config = UpdateConfig {
                force,
                dry_run,
                skip_errors: true,
                timeout_seconds: 120,
            };

            let result = ChecksumUpdater::update_all_tools(config).await
                .map_err(|e| anyhow::anyhow!("Update failed: {}", e))?;

            println!("=== Update All Results ===");
            println!("Tools processed: {}", result.tools_processed);
            println!("Tools updated: {}", result.tools_updated);
            println!("New versions found: {}", result.new_versions_found);
            println!("Errors: {}", result.errors);
            println!("Duration: {}ms", result.duration_ms);
        }

        Commands::Validate { tools, fix } => {
            let result = ChecksumUpdater::validate_tools(tools, fix).await
                .map_err(|e| anyhow::anyhow!("Validation failed: {}", e))?;

            println!("=== Validation Results ===");
            println!("Tools validated: {}", result.tools_validated);
            println!("Valid checksums: {}", result.valid_checksums);
            println!("Invalid checksums: {}", result.invalid_checksums);
            println!("Fixed checksums: {}", result.fixed_checksums);
        }

        Commands::SelfUpdate { check_only } => {
            info!("Checking for self-updates...");
            
            let current_version = Bootstrap::get_version();
            println!("Current version: {}", current_version);

            match ChecksumUpdater::check_self_update().await
                .map_err(|e| anyhow::anyhow!("Self-update check failed: {}", e))? {
                Some(new_version) => {
                    println!("🔄 Update available: {} → {}", current_version, new_version);
                    
                    if !check_only {
                        println!("Downloading new version...");
                        let success = ChecksumUpdater::perform_self_update(new_version.clone()).await
                            .map_err(|e| anyhow::anyhow!("Self-update failed: {}", e))?;
                        
                        if success {
                            println!("✅ Self-update completed! New version: {}", new_version);
                            println!("🔄 Restart required to use the new version.");
                        } else {
                            println!("❌ Self-update failed");
                        }
                    }
                }
                None => {
                    println!("✅ Already at latest version: {}", current_version);
                }
            }
        }

        Commands::Bootstrap => {
            let version = Bootstrap::get_version();
            let path = Bootstrap::get_component_path()
                .map_err(|e| anyhow::anyhow!("Failed to get component path: {}", e))?;

            println!("=== Bootstrap Information ===");
            println!("Component version: {}", version);
            println!("Component path: {}", path);
            println!("Platform: WebAssembly Component Model (wasm32-wasi)");
            println!("Runtime: wasmtime (or compatible WASI Preview 2 runtime)");
            println!("Self-hosting: ✅ Enabled");
            println!("Registry integration: ✅ Enabled");
            println!("Self-update capability: ✅ Available");
        }
    }

    Ok(())
}