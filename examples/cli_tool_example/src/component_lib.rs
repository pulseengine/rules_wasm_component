/*!
Example library component using rust_wasm_component_bindgen.

This demonstrates a component that exports custom interfaces for other
components to use - perfect for the high-level rust_wasm_component_bindgen rule.
*/

use file_processor_component_bindings::exports::example::processor::file_ops::Guest;

/// Component that exports file processing functions for other components
struct FileProcessor;

impl Guest for FileProcessor {
    fn process_text(input: String, operation: String) -> Result<String, String> {
        match operation.as_str() {
            "uppercase" => Ok(input.to_uppercase()),
            "lowercase" => Ok(input.to_lowercase()),
            "reverse" => Ok(input.chars().rev().collect()),
            "word_count" => Ok(input.split_whitespace().count().to_string()),
            _ => Err(format!("Unknown operation: {}", operation)),
        }
    }

    fn validate_file_extension(filename: String, expected_ext: String) -> bool {
        filename.ends_with(&format!(".{}", expected_ext))
    }

    fn get_file_info(filename: String) -> String {
        format!(
            "File: {}, Extension: {:?}",
            filename,
            std::path::Path::new(&filename).extension()
        )
    }
}

// Export the component for other components to use
file_processor_component_bindings::export!(FileProcessor with_types_in file_processor_component_bindings);

/*
This component demonstrates rust_wasm_component_bindgen usage:

1. Custom interfaces: Exports functions defined in WIT for other components
2. Component library: Designed to be used by other components, not CLI
3. Interface contracts: Functions match WIT interface exactly
4. Automatic bindings: WIT bindings generated automatically

Perfect for rust_wasm_component_bindgen because:
- Custom WIT interfaces need binding generation
- Exports functions for inter-component communication
- Standard component development pattern
- Automatic dependency management

Usage (from other components):
let result = file_processor.process_text("hello world", "uppercase");
let valid = file_processor.validate_file_extension("doc.txt", "txt");
let info = file_processor.get_file_info("document.pdf");
*/
