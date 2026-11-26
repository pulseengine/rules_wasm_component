/*!
Multi-Language WebAssembly Checksum Validator - Rust Component

This component handles:
- Advanced SHA256 validation and verification
- Checksum registry management and updates
- File operations and integrity checking
- JSON parsing and tool metadata management
- Integration with Go HTTP downloader component

Architecture: WASI Preview 2 WebAssembly Component Model
*/

use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::path::Path;
use std::process;

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

/// Checksum validation request
#[derive(Debug, Serialize, Deserialize)]
pub struct ValidationRequest {
    pub file_path: String,
    pub expected_sha256: String,
    pub tool_name: String,
    pub version: String,
    pub platform: String,
}

/// Checksum validation result
#[derive(Debug, Serialize, Deserialize)]
pub struct ValidationResult {
    pub file_path: String,
    pub actual_sha256: String,
    pub expected_sha256: String,
    pub valid: bool,
    pub file_size: u64,
    pub validation_time_ms: u64,
    pub error: Option<String>,
}

/// Registry update result
#[derive(Debug, Serialize, Deserialize)]
pub struct RegistryUpdateResult {
    pub tools_processed: u32,
    pub tools_updated: u32,
    pub new_versions_found: u32,
    pub errors: u32,
    pub duration_ms: u64,
}

fn main() {
    println!("🦀 Multi-Language WebAssembly Checksum Validator");
    println!("=================================================");
    println!("⚙️  Rust Component: SHA256 Validation & Registry Management");

    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        show_help();
        return;
    }

    let command = &args[1];
    match command.as_str() {
        "validate" => handle_validate(&args),
        "validate-json" => handle_validate_json(&args),
        "manage-registry" => handle_manage_registry(&args),
        "list-tools" => handle_list_tools(&args),
        "get-tool-info" => handle_get_tool_info(&args),
        "update-tool" => handle_update_tool(&args),
        "verify-integrity" => handle_verify_integrity(&args),
        "batch-validate" => handle_batch_validate(&args),
        "test-rust" => handle_test_rust(),
        _ => {
            eprintln!("❌ Unknown command: {}", command);
            show_help();
            process::exit(1);
        }
    }
}

fn show_help() {
    println!("Usage:");
    println!("  validate <file-path> <expected-sha256>");
    println!("  validate-json <json-request>");
    println!("  manage-registry <checksums-dir>");
    println!("  list-tools <checksums-dir>");
    println!("  get-tool-info <checksums-dir> <tool-name>");
    println!(
        "  update-tool <checksums-dir> <tool-name> <version> <platform> <sha256> <url-suffix>"
    );
    println!("  verify-integrity <checksums-dir>");
    println!("  batch-validate <checksums-dir> <files-list>");
    println!("  test-rust");
    println!();
    println!("Examples:");
    println!("  validate ./file.tar.gz abc123...");
    println!(
        r#"  validate-json '{{"file_path":"./file.tar.gz","expected_sha256":"abc123...","tool_name":"wasm-tools"}}'"#
    );
    println!("  manage-registry ./checksums");
    println!("  list-tools ./checksums");
    println!("  test-rust");
}

fn handle_validate(args: &[String]) {
    if args.len() < 4 {
        eprintln!("❌ Usage: validate <file-path> <expected-sha256>");
        return;
    }

    let file_path = &args[2];
    let expected_sha256 = &args[3];

    match validate_file_checksum(file_path, expected_sha256) {
        Ok(result) => print_validation_result(&result),
        Err(e) => eprintln!("❌ Validation failed: {}", e),
    }
}

fn handle_validate_json(args: &[String]) {
    if args.len() < 3 {
        eprintln!("❌ Usage: validate-json <json-request>");
        return;
    }

    let json_data = &args[2];
    match serde_json::from_str::<ValidationRequest>(json_data) {
        Ok(request) => {
            match validate_file_checksum(&request.file_path, &request.expected_sha256) {
                Ok(result) => {
                    println!("📋 JSON Validation Result:");
                    print_validation_result(&result);

                    // Output JSON result for integration
                    match serde_json::to_string_pretty(&result) {
                        Ok(json_result) => println!("\n🔗 JSON Output:\n{}", json_result),
                        Err(e) => eprintln!("⚠️  JSON serialization failed: {}", e),
                    }
                }
                Err(e) => eprintln!("❌ Validation failed: {}", e),
            }
        }
        Err(e) => eprintln!("❌ Failed to parse JSON request: {}", e),
    }
}

fn handle_manage_registry(args: &[String]) {
    if args.len() < 3 {
        eprintln!("❌ Usage: manage-registry <checksums-dir>");
        return;
    }

    let checksums_dir = Path::new(&args[2]);
    match manage_checksum_registry(checksums_dir) {
        Ok(result) => {
            println!("✅ Registry management completed:");
            println!("  Tools processed: {}", result.tools_processed);
            println!("  Tools updated: {}", result.tools_updated);
            println!("  New versions: {}", result.new_versions_found);
            println!("  Errors: {}", result.errors);
            println!("  Duration: {}ms", result.duration_ms);
        }
        Err(e) => eprintln!("❌ Registry management failed: {}", e),
    }
}

fn handle_list_tools(args: &[String]) {
    if args.len() < 3 {
        eprintln!("❌ Usage: list-tools <checksums-dir>");
        return;
    }

    let checksums_dir = Path::new(&args[2]);
    match list_tools(checksums_dir) {
        Ok(tools) => {
            println!("📋 Available tools ({}):", tools.len());
            for (i, tool) in tools.iter().enumerate() {
                println!("  {}. {}", i + 1, tool);
            }
        }
        Err(e) => eprintln!("❌ Failed to list tools: {}", e),
    }
}

fn handle_get_tool_info(args: &[String]) {
    if args.len() < 4 {
        eprintln!("❌ Usage: get-tool-info <checksums-dir> <tool-name>");
        return;
    }

    let checksums_dir = Path::new(&args[2]);
    let tool_name = &args[3];

    match get_tool_info(checksums_dir, tool_name) {
        Ok(tool_info) => print_tool_info(&tool_info),
        Err(e) => eprintln!("❌ Failed to get tool info: {}", e),
    }
}

fn handle_update_tool(args: &[String]) {
    if args.len() < 8 {
        eprintln!("❌ Usage: update-tool <checksums-dir> <tool-name> <version> <platform> <sha256> <url-suffix>");
        return;
    }

    let checksums_dir = Path::new(&args[2]);
    let tool_name = &args[3];
    let version = &args[4];
    let platform = &args[5];
    let sha256 = &args[6];
    let url_suffix = &args[7];

    match update_tool_info(
        checksums_dir,
        tool_name,
        version,
        platform,
        sha256,
        url_suffix,
    ) {
        Ok(_) => println!(
            "✅ Tool updated successfully: {} v{} ({})",
            tool_name, version, platform
        ),
        Err(e) => eprintln!("❌ Failed to update tool: {}", e),
    }
}

fn handle_verify_integrity(args: &[String]) {
    if args.len() < 3 {
        eprintln!("❌ Usage: verify-integrity <checksums-dir>");
        return;
    }

    let checksums_dir = Path::new(&args[2]);
    match verify_registry_integrity(checksums_dir) {
        Ok(valid) => {
            if valid {
                println!("✅ Registry integrity check: PASSED");
            } else {
                println!("❌ Registry integrity check: FAILED");
            }
        }
        Err(e) => eprintln!("❌ Integrity check failed: {}", e),
    }
}

fn handle_batch_validate(args: &[String]) {
    if args.len() < 4 {
        eprintln!("❌ Usage: batch-validate <checksums-dir> <files-list>");
        return;
    }

    let checksums_dir = Path::new(&args[2]);
    let files_list = &args[3];

    match batch_validate_files(checksums_dir, files_list) {
        Ok(results) => {
            println!("📊 Batch Validation Results:");
            let total = results.len();
            let valid = results.iter().filter(|r| r.valid).count();

            println!("  Total files: {}", total);
            println!("  Valid: {}", valid);
            println!("  Invalid: {}", total - valid);

            for result in &results {
                if result.valid {
                    println!("  ✅ {}", result.file_path);
                } else {
                    println!(
                        "  ❌ {} ({})",
                        result.file_path,
                        result.error.as_ref().unwrap_or(&"mismatch".to_string())
                    );
                }
            }
        }
        Err(e) => eprintln!("❌ Batch validation failed: {}", e),
    }
}

fn handle_test_rust() {
    println!("🧪 Testing Rust component functionality...");

    // Test 1: SHA256 calculation
    println!("  Test 1: SHA256 calculation");
    let test_data = b"Hello, WebAssembly Component Model!";
    let hash = calculate_sha256_bytes(test_data);
    println!("    ✅ SHA256: {}", hash);

    // Test 2: JSON serialization
    println!("  Test 2: JSON serialization");
    let test_result = ValidationResult {
        file_path: "test.txt".to_string(),
        actual_sha256: hash.clone(),
        expected_sha256: hash,
        valid: true,
        file_size: test_data.len() as u64,
        validation_time_ms: 42,
        error: None,
    };

    match serde_json::to_string_pretty(&test_result) {
        Ok(_) => println!("    ✅ JSON serialization successful"),
        Err(e) => println!("    ❌ JSON serialization failed: {}", e),
    }

    // Test 3: Current directory access
    println!("  Test 3: File system access");
    match std::env::current_dir() {
        Ok(dir) => println!("    ✅ Current directory: {}", dir.display()),
        Err(e) => println!("    ❌ Failed to get current directory: {}", e),
    }

    println!("🎉 Rust component tests completed!");
}

fn validate_file_checksum(file_path: &str, expected_sha256: &str) -> Result<ValidationResult> {
    let start_time = std::time::Instant::now();

    let path = Path::new(file_path);

    // Check if file exists
    if !path.exists() {
        return Ok(ValidationResult {
            file_path: file_path.to_string(),
            actual_sha256: String::new(),
            expected_sha256: expected_sha256.to_string(),
            valid: false,
            file_size: 0,
            validation_time_ms: start_time.elapsed().as_millis() as u64,
            error: Some("File not found".to_string()),
        });
    }

    // Get file size
    let metadata = fs::metadata(path)?;
    let file_size = metadata.len();

    // Calculate SHA256
    let mut file = fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0; 8192];

    loop {
        match file.read(&mut buffer)? {
            0 => break,
            n => hasher.update(&buffer[..n]),
        }
    }

    let actual_sha256 = hex_lower(&hasher.finalize());
    let valid = actual_sha256.eq_ignore_ascii_case(expected_sha256);

    Ok(ValidationResult {
        file_path: file_path.to_string(),
        actual_sha256,
        expected_sha256: expected_sha256.to_string(),
        valid,
        file_size,
        validation_time_ms: start_time.elapsed().as_millis() as u64,
        error: None,
    })
}

fn calculate_sha256_bytes(data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data);
    hex_lower(&hasher.finalize())
}

/// Lowercase hex of a digest. sha2 0.11 returns a hybrid-array digest that
/// does not implement `LowerHex`, so `format!("{:x}", ...)` no longer builds.
fn hex_lower(bytes: &[u8]) -> String {
    use std::fmt::Write;
    bytes
        .iter()
        .fold(String::with_capacity(bytes.len() * 2), |mut s, b| {
            let _ = write!(s, "{b:02x}");
            s
        })
}

fn manage_checksum_registry(checksums_dir: &Path) -> Result<RegistryUpdateResult> {
    let start_time = std::time::Instant::now();
    let tools_dir = checksums_dir.join("tools");

    if !tools_dir.exists() {
        fs::create_dir_all(&tools_dir)?;
    }

    let mut result = RegistryUpdateResult {
        tools_processed: 0,
        tools_updated: 0,
        new_versions_found: 0,
        errors: 0,
        duration_ms: 0,
    };

    // Process each JSON file in the tools directory
    if tools_dir.exists() {
        for entry in fs::read_dir(&tools_dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("json") {
                result.tools_processed += 1;

                match validate_tool_json(&path) {
                    Ok(valid) => {
                        if valid {
                            result.tools_updated += 1;
                        }
                    }
                    Err(_) => result.errors += 1,
                }
            }
        }
    }

    result.duration_ms = start_time.elapsed().as_millis() as u64;
    Ok(result)
}

fn validate_tool_json(json_path: &Path) -> Result<bool> {
    let content = fs::read_to_string(json_path)?;
    let _tool_info: ToolInfo = serde_json::from_str(&content)?;
    Ok(true)
}

fn list_tools(checksums_dir: &Path) -> Result<Vec<String>> {
    let tools_dir = checksums_dir.join("tools");
    let mut tools = Vec::new();

    if tools_dir.exists() {
        for entry in fs::read_dir(&tools_dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("json") {
                if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                    tools.push(stem.to_string());
                }
            }
        }
    }

    tools.sort();
    Ok(tools)
}

fn get_tool_info(checksums_dir: &Path, tool_name: &str) -> Result<ToolInfo> {
    let tool_path = checksums_dir
        .join("tools")
        .join(format!("{}.json", tool_name));
    let content = fs::read_to_string(tool_path)?;
    let tool_info: ToolInfo = serde_json::from_str(&content)?;
    Ok(tool_info)
}

fn update_tool_info(
    checksums_dir: &Path,
    tool_name: &str,
    version: &str,
    platform: &str,
    sha256: &str,
    url_suffix: &str,
) -> Result<()> {
    let tool_path = checksums_dir
        .join("tools")
        .join(format!("{}.json", tool_name));

    let mut tool_info = if tool_path.exists() {
        let content = fs::read_to_string(&tool_path)?;
        serde_json::from_str::<ToolInfo>(&content)?
    } else {
        ToolInfo {
            tool_name: tool_name.to_string(),
            github_repo: format!("owner/{}", tool_name), // placeholder
            latest_version: version.to_string(),
            last_checked: Utc::now(),
            versions: HashMap::new(),
            supported_platforms: Vec::new(),
        }
    };

    let platform_info = PlatformInfo {
        sha256: sha256.to_string(),
        url_suffix: url_suffix.to_string(),
        platform_name: None,
    };

    let version_info = VersionInfo {
        release_date: Utc::now().format("%Y-%m-%d").to_string(),
        platforms: {
            let mut platforms = HashMap::new();
            platforms.insert(platform.to_string(), platform_info);
            platforms
        },
    };

    tool_info.versions.insert(version.to_string(), version_info);
    tool_info.last_checked = Utc::now();

    let json_content = serde_json::to_string_pretty(&tool_info)?;
    fs::write(&tool_path, json_content)?;

    Ok(())
}

fn verify_registry_integrity(checksums_dir: &Path) -> Result<bool> {
    let tools = list_tools(checksums_dir)?;

    for tool_name in tools {
        match get_tool_info(checksums_dir, &tool_name) {
            Ok(_) => {}                 // Valid JSON
            Err(_) => return Ok(false), // Invalid JSON
        }
    }

    Ok(true)
}

fn batch_validate_files(_checksums_dir: &Path, _files_list: &str) -> Result<Vec<ValidationResult>> {
    // Placeholder implementation for batch validation
    // In a real implementation, this would read the files list and validate each file
    Ok(Vec::new())
}

fn print_validation_result(result: &ValidationResult) {
    println!("\n🔍 Checksum Validation Result:");
    println!("  File: {}", result.file_path);
    println!("  Size: {} bytes", result.file_size);

    if let Some(error) = &result.error {
        println!("  ❌ Status: FAILED");
        println!("  💥 Error: {}", error);
        return;
    }

    println!("  🔐 Expected SHA256: {}", result.expected_sha256);
    println!("  🔐 Actual SHA256:   {}", result.actual_sha256);
    println!("  ⏱️  Time: {}ms", result.validation_time_ms);

    if result.valid {
        println!("  ✅ Status: VALID");
    } else {
        println!("  ❌ Status: INVALID");
    }
}

fn print_tool_info(tool_info: &ToolInfo) {
    println!("\n📦 Tool Information:");
    println!("  Name: {}", tool_info.tool_name);
    println!("  Repository: {}", tool_info.github_repo);
    println!("  Latest Version: {}", tool_info.latest_version);
    println!(
        "  Last Checked: {}",
        tool_info.last_checked.format("%Y-%m-%d %H:%M:%S UTC")
    );
    println!("  Versions: {}", tool_info.versions.len());
    println!("  Platforms: {}", tool_info.supported_platforms.len());

    if !tool_info.versions.is_empty() {
        println!("\n📋 Available Versions:");
        let mut versions: Vec<_> = tool_info.versions.keys().collect();
        versions.sort();
        for version in versions {
            if let Some(version_info) = tool_info.versions.get(version) {
                println!(
                    "  - {} ({} platforms)",
                    version,
                    version_info.platforms.len()
                );
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::calculate_sha256_bytes;

    #[test]
    fn sha256_hex_matches_known_vectors() {
        // FIPS 180-2 test vectors.
        assert_eq!(
            calculate_sha256_bytes(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        assert_eq!(
            calculate_sha256_bytes(b""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
    }
}
