// WebAssembly Signing Example Component
// 
// This is a simple component that demonstrates cryptographic signing
// capabilities for WebAssembly components.

// Import the generated WIT bindings
use example_component_bindings::exports::example::signature::demo::{Guest, SigningInfo, VerificationResult};

// Component implementation
struct ExampleComponent;

impl Guest for ExampleComponent {
    fn get_component_info() -> SigningInfo {
        SigningInfo {
            name: "example-signing-component".to_string(),
            version: "1.0.0".to_string(),
            description: "Demonstrates WebAssembly component signing with wasmsign2".to_string(),
            author: "WebAssembly Component Rules".to_string(),
        }
    }

    fn compute_hash(data: String) -> String {
        // Simple demonstration hash function (not cryptographically secure)
        let mut hash = 0u32;
        for byte in data.bytes() {
            hash = hash.wrapping_mul(31).wrapping_add(byte as u32);
        }
        format!("hash:{:08x}", hash)
    }

    fn verify_integrity(expected_hash: String, data: String) -> VerificationResult {
        let computed_hash = Self::compute_hash(data);
        let is_valid = computed_hash == expected_hash;
        
        let message = if is_valid {
            "Data integrity verified successfully".to_string()
        } else {
            format!("Integrity check failed: expected {}, got {}", expected_hash, computed_hash)
        };
        
        VerificationResult {
            is_valid,
            computed_hash,
            message,
        }
    }

    fn demonstrate_signing_flow() -> String {
        let info = Self::get_component_info();
        let test_data = format!("{}:{}", info.name, info.version);
        let hash = Self::compute_hash(test_data.clone());
        let verification = Self::verify_integrity(hash.clone(), test_data);
        
        format!(
            "Signing Demo:\n\
             Component: {}\n\
             Test Hash: {}\n\
             Verification: {}\n\
             Status: {}",
            info.name,
            hash,
            verification.message,
            if verification.is_valid { "✅ READY FOR SIGNING" } else { "❌ FAILED" }
        )
    }
}

// Export the component implementation
example_component_bindings::export!(ExampleComponent with_types_in example_component_bindings);