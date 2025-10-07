//! WebAssembly AOT embedding utilities
//!
//! This library provides functionality to embed AOT (Ahead-of-Time) compiled artifacts
//! into WebAssembly modules as custom sections. This enables platform-specific optimized
//! code to be bundled alongside the portable WebAssembly module.
//!
//! # Custom Section Format
//!
//! AOT artifacts are embedded as WebAssembly custom sections with names following
//! the pattern "aot-{name}" where {name} is a user-provided identifier (typically
//! representing the target architecture like "linux-x64", "darwin-arm64", etc.).
//!
//! The WebAssembly custom section format is:
//! - Section ID: 0x00 (indicates custom section)
//! - Section size: LEB128-encoded total size of section content
//! - Name length: LEB128-encoded length of section name
//! - Name: UTF-8 encoded section name
//! - Data: Raw binary data of the AOT artifact

use wasmparser::{Parser, Payload};

wit_bindgen::generate!({
    world: "embed-aot",
    path: "wit",
});

struct EmbedAot;

impl Guest for EmbedAot {
    /// Embed AOT artifacts as custom sections in a WebAssembly module
    ///
    /// Takes a WASM module and a list of (name, data) tuples representing AOT artifacts.
    /// Each artifact is embedded as a custom section named "aot-{name}".
    ///
    /// # Arguments
    /// * `wasm_data` - Original WebAssembly module bytes
    /// * `aot_artifacts` - List of (section_name, artifact_data) tuples to embed
    ///
    /// # Returns
    /// Modified WebAssembly module with embedded custom sections
    fn embed_artifacts(
        wasm_data: Vec<u8>,
        aot_artifacts: Vec<(String, Vec<u8>)>,
    ) -> Result<Vec<u8>, String> {
        add_custom_sections(wasm_data, aot_artifacts)
    }

    /// Extract a specific AOT artifact from a WebAssembly module
    ///
    /// Searches for a custom section with the given name and returns its data.
    ///
    /// # Arguments
    /// * `wasm_data` - WebAssembly module with embedded AOT artifacts
    /// * `section_name` - Name of the section to extract (without "aot-" prefix if already included)
    ///
    /// # Returns
    /// Binary data of the requested AOT artifact
    fn extract_artifact(wasm_data: Vec<u8>, section_name: String) -> Result<Vec<u8>, String> {
        let parser = Parser::new(0);

        for payload in parser.parse_all(&wasm_data) {
            let payload = payload.map_err(|e| format!("Failed to parse WASM: {}", e))?;

            if let Payload::CustomSection(reader) = payload {
                if reader.name() == section_name {
                    return Ok(reader.data().to_vec());
                }
            }
        }

        Err(format!("Section '{}' not found", section_name))
    }

    /// List all embedded AOT artifacts in a WebAssembly module
    ///
    /// Scans the module for custom sections with names starting with "aot-"
    /// and returns a list of their names.
    ///
    /// # Arguments
    /// * `wasm_data` - WebAssembly module bytes
    ///
    /// # Returns
    /// List of section names for embedded AOT artifacts
    fn list_artifacts(wasm_data: Vec<u8>) -> Result<Vec<String>, String> {
        let parser = Parser::new(0);
        let mut artifacts = Vec::new();

        for payload in parser.parse_all(&wasm_data) {
            let payload = payload.map_err(|e| format!("Failed to parse WASM: {}", e))?;

            if let Payload::CustomSection(reader) = payload {
                if reader.name().starts_with("aot-") {
                    artifacts.push(reader.name().to_string());
                }
            }
        }

        Ok(artifacts)
    }

    /// Verify the integrity of a WebAssembly module with embedded AOT artifacts
    ///
    /// Validates that:
    /// 1. The WASM module has a valid structure
    /// 2. All sections can be parsed correctly
    /// 3. The module has valid magic number and version
    ///
    /// # Arguments
    /// * `wasm_data` - WebAssembly module bytes
    ///
    /// # Returns
    /// true if the module is valid, false otherwise
    fn verify_integrity(wasm_data: Vec<u8>) -> Result<bool, String> {
        // Verify WASM magic number and version
        if wasm_data.len() < 8 {
            return Ok(false);
        }

        // WASM magic: 0x00 0x61 0x73 0x6D (\\0asm)
        if &wasm_data[0..4] != b"\0asm" {
            return Ok(false);
        }

        // WASM version: 0x01 0x00 0x00 0x00 (version 1)
        if &wasm_data[4..8] != b"\x01\x00\x00\x00" {
            return Ok(false);
        }

        // Try to parse all sections to verify structure
        let parser = Parser::new(0);
        for payload in parser.parse_all(&wasm_data) {
            // If any section fails to parse, the module is invalid
            payload.map_err(|e| format!("Invalid WASM structure: {}", e))?;
        }

        Ok(true)
    }
}

/// Add custom sections to a WebAssembly module
///
/// Inserts custom sections after the WASM header. This approach ensures the sections
/// are placed at the beginning of the module, making them easy to locate and extract.
fn add_custom_sections(
    wasm_data: Vec<u8>,
    aot_artifacts: Vec<(String, Vec<u8>)>,
) -> Result<Vec<u8>, String> {
    // Validate WASM header
    if wasm_data.len() < 8 {
        return Err("Invalid WASM file: too short".to_string());
    }

    if &wasm_data[0..4] != b"\0asm" {
        return Err("Invalid WASM file: bad magic number".to_string());
    }

    let mut result = Vec::new();

    // Copy WASM header (magic + version, 8 bytes)
    result.extend_from_slice(&wasm_data[0..8]);

    // Add custom sections
    for (section_name, section_data) in aot_artifacts {
        let custom_section = create_custom_section(&section_name, &section_data)?;
        result.extend_from_slice(&custom_section);
    }

    // Copy rest of original WASM
    result.extend_from_slice(&wasm_data[8..]);

    Ok(result)
}

/// Create a WebAssembly custom section with the given name and data
///
/// Custom section format:
/// - Section ID (0x00): 1 byte
/// - Section size (LEB128): variable length
/// - Name length (LEB128): variable length
/// - Name: UTF-8 bytes
/// - Data: raw bytes
fn create_custom_section(name: &str, data: &[u8]) -> Result<Vec<u8>, String> {
    let name_bytes = name.as_bytes();
    let section_content_size = leb128_size(name_bytes.len()) + name_bytes.len() + data.len();

    let mut section = Vec::new();

    // Section ID (0x00 = custom section)
    section.push(0);

    // Section size (LEB128)
    write_leb128(&mut section, section_content_size);

    // Name length (LEB128)
    write_leb128(&mut section, name_bytes.len());

    // Name
    section.extend_from_slice(name_bytes);

    // Data
    section.extend_from_slice(data);

    Ok(section)
}

/// Write an unsigned integer as LEB128 (Little Endian Base 128)
///
/// LEB128 is a variable-length encoding used throughout the WebAssembly binary format.
fn write_leb128(output: &mut Vec<u8>, mut value: usize) {
    loop {
        let byte = (value & 0x7F) as u8;
        value >>= 7;
        if value == 0 {
            output.push(byte);
            break;
        } else {
            output.push(byte | 0x80);
        }
    }
}

/// Calculate the size in bytes of a value when encoded as LEB128
fn leb128_size(value: usize) -> usize {
    if value == 0 {
        1
    } else {
        ((value.ilog2() / 7) + 1) as usize
    }
}

export!(EmbedAot);

#[cfg(test)]
mod tests {
    use super::*;

    /// Create a minimal valid WASM module for testing
    fn minimal_wasm_module() -> Vec<u8> {
        vec![
            0x00, 0x61, 0x73, 0x6D, // Magic: \0asm
            0x01, 0x00, 0x00, 0x00, // Version: 1
        ]
    }

    #[test]
    fn test_verify_integrity_valid_minimal() {
        let wasm = minimal_wasm_module();
        let result = EmbedAot::verify_integrity(wasm);
        assert!(result.is_ok());
        assert!(result.unwrap());
    }

    #[test]
    fn test_verify_integrity_invalid_magic() {
        let wasm = vec![
            0xFF, 0xFF, 0xFF, 0xFF, // Bad magic
            0x01, 0x00, 0x00, 0x00, // Version: 1
        ];
        let result = EmbedAot::verify_integrity(wasm);
        assert!(result.is_ok());
        assert!(!result.unwrap());
    }

    #[test]
    fn test_verify_integrity_too_short() {
        let wasm = vec![0x00, 0x61, 0x73]; // Only 3 bytes
        let result = EmbedAot::verify_integrity(wasm);
        assert!(result.is_ok());
        assert!(!result.unwrap());
    }

    #[test]
    fn test_list_artifacts_empty() {
        let wasm = minimal_wasm_module();
        let result = EmbedAot::list_artifacts(wasm);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), Vec::<String>::new());
    }

    #[test]
    fn test_embed_and_list_artifacts() {
        let wasm = minimal_wasm_module();
        let artifacts = vec![
            ("aot-linux-x64".to_string(), vec![1, 2, 3, 4]),
            ("aot-darwin-arm64".to_string(), vec![5, 6, 7, 8]),
        ];

        let result = EmbedAot::embed_artifacts(wasm, artifacts);
        assert!(result.is_ok());

        let enhanced_wasm = result.unwrap();

        // Verify the enhanced WASM is still valid
        let verify_result = EmbedAot::verify_integrity(enhanced_wasm.clone());
        assert!(verify_result.is_ok());
        assert!(verify_result.unwrap());

        // List artifacts
        let list_result = EmbedAot::list_artifacts(enhanced_wasm);
        assert!(list_result.is_ok());

        let artifact_list = list_result.unwrap();
        assert_eq!(artifact_list.len(), 2);
        assert!(artifact_list.contains(&"aot-linux-x64".to_string()));
        assert!(artifact_list.contains(&"aot-darwin-arm64".to_string()));
    }

    #[test]
    fn test_embed_and_extract_artifact() {
        let wasm = minimal_wasm_module();
        let test_data = vec![0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE];
        let artifacts = vec![
            ("aot-test".to_string(), test_data.clone()),
        ];

        // Embed
        let result = EmbedAot::embed_artifacts(wasm, artifacts);
        assert!(result.is_ok());
        let enhanced_wasm = result.unwrap();

        // Extract
        let extract_result = EmbedAot::extract_artifact(enhanced_wasm, "aot-test".to_string());
        assert!(extract_result.is_ok());

        let extracted_data = extract_result.unwrap();
        assert_eq!(extracted_data, test_data);
    }

    #[test]
    fn test_extract_nonexistent_artifact() {
        let wasm = minimal_wasm_module();
        let result = EmbedAot::extract_artifact(wasm, "aot-nonexistent".to_string());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }

    #[test]
    fn test_embed_multiple_artifacts_and_extract_each() {
        let wasm = minimal_wasm_module();
        let artifacts = vec![
            ("aot-linux-x64".to_string(), vec![1, 2, 3]),
            ("aot-darwin-arm64".to_string(), vec![4, 5, 6]),
            ("aot-windows-x64".to_string(), vec![7, 8, 9]),
        ];

        // Embed all
        let result = EmbedAot::embed_artifacts(wasm, artifacts.clone());
        assert!(result.is_ok());
        let enhanced_wasm = result.unwrap();

        // Extract each and verify
        for (name, expected_data) in artifacts {
            let extract_result = EmbedAot::extract_artifact(enhanced_wasm.clone(), name);
            assert!(extract_result.is_ok());
            assert_eq!(extract_result.unwrap(), expected_data);
        }
    }

    #[test]
    fn test_leb128_encoding() {
        let mut output = Vec::new();
        write_leb128(&mut output, 0);
        assert_eq!(output, vec![0x00]);

        output.clear();
        write_leb128(&mut output, 127);
        assert_eq!(output, vec![0x7F]);

        output.clear();
        write_leb128(&mut output, 128);
        assert_eq!(output, vec![0x80, 0x01]);

        output.clear();
        write_leb128(&mut output, 624485);
        assert_eq!(output, vec![0xE5, 0x8E, 0x26]);
    }

    #[test]
    fn test_leb128_size_calculation() {
        assert_eq!(leb128_size(0), 1);
        assert_eq!(leb128_size(127), 1);
        assert_eq!(leb128_size(128), 2);
        assert_eq!(leb128_size(16383), 2);
        assert_eq!(leb128_size(16384), 3);
    }

    #[test]
    fn test_invalid_wasm_embed() {
        let bad_wasm = vec![0xFF, 0xFF]; // Too short, bad magic
        let artifacts = vec![("aot-test".to_string(), vec![1, 2, 3])];

        let result = EmbedAot::embed_artifacts(bad_wasm, artifacts);
        assert!(result.is_err());
    }

    #[test]
    fn test_large_artifact() {
        let wasm = minimal_wasm_module();
        // Create a large artifact (1MB)
        let large_data = vec![0x42; 1024 * 1024];
        let artifacts = vec![
            ("aot-large".to_string(), large_data.clone()),
        ];

        let result = EmbedAot::embed_artifacts(wasm, artifacts);
        assert!(result.is_ok());

        let enhanced_wasm = result.unwrap();

        // Verify extraction
        let extract_result = EmbedAot::extract_artifact(enhanced_wasm, "aot-large".to_string());
        assert!(extract_result.is_ok());
        assert_eq!(extract_result.unwrap(), large_data);
    }
}
