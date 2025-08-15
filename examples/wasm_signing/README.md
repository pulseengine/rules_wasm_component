# WebAssembly Signing Example

This example demonstrates the complete WebAssembly component signing workflow using the integrated wasmsign2 support in rules_wasm_component.

## Overview

This example shows how to:

1. **Generate cryptographic keys** for signing WebAssembly components
2. **Sign components** with both embedded and detached signatures
3. **Verify signatures** using public keys
4. **Integrate signature verification** into validation workflows
5. **Use different key formats** (OpenSSH and compact)

## Components

### Source Code

- `src/lib.rs` - Simple Rust component demonstrating integrity checking
- `wit/example.wit` - WebAssembly Interface Type definitions

### Build Targets

#### Key Generation

```bash
# Generate OpenSSH format keys
bazel build //examples/wasm_signing:example_keys

# Generate compact format keys
bazel build //examples/wasm_signing:compact_keys
```

#### Component Building

```bash
# Build the example component
bazel build //examples/wasm_signing:example_component
```

#### Signing Workflow

```bash
# Sign with embedded signature
bazel build //examples/wasm_signing:signed_component_embedded

# Sign with detached signature
bazel build //examples/wasm_signing:signed_component_detached

# Sign raw WASM file
bazel build //examples/wasm_signing:signed_raw_wasm
```

#### Verification

```bash
# Verify embedded signature
bazel build //examples/wasm_signing:verify_embedded

# Verify detached signature
bazel build //examples/wasm_signing:verify_detached

# Validate component with signature check
bazel build //examples/wasm_signing:validate_with_signature_check
```

#### Complete Test

```bash
# Run the complete signing workflow test
bazel build //examples/wasm_signing:test_signing_workflow

# View test results
cat bazel-bin/examples/wasm_signing/signing_test_results.txt
```

## Usage Patterns

### Basic Signing

```starlark
# Generate keys
wasm_keygen(
    name = "my_keys",
    openssh_format = True,
)

# Sign component
wasm_sign(
    name = "signed_component",
    component = ":my_component",
    keys = ":my_keys",
    detached = False,
)

# Verify signature
wasm_verify(
    name = "verify_component",
    signed_component = ":signed_component",
    keys = ":my_keys",
)
```

### Validation with Signature Check

```starlark
# Validate and verify signature in one step
wasm_validate(
    name = "validate_signed",
    component = ":signed_component",
    verify_signature = True,
    signing_keys = ":my_keys",
)
```

### Different Key Formats

```starlark
# OpenSSH format (compatible with GitHub)
wasm_keygen(
    name = "ssh_keys",
    openssh_format = True,
)

# Compact format (wasmsign2 native)
wasm_keygen(
    name = "compact_keys",
    openssh_format = False,
)
```

### GitHub Integration

```starlark
# Verify using GitHub public keys
wasm_verify(
    name = "verify_github",
    signed_component = ":signed_component",
    github_account = "myusername",
)
```

## Security Features

### Supported Signature Types

- **Embedded signatures**: Signature embedded in the WASM component
- **Detached signatures**: Separate `.sig` file containing the signature

### Key Formats

- **OpenSSH**: Ed25519 keys compatible with GitHub SSH keys
- **Compact**: Native wasmsign2 format for optimal performance

### Verification Methods

- **Public key files**: Direct verification using public key
- **Key pairs**: Use generated key pairs for signing and verification
- **GitHub accounts**: Fetch and verify using GitHub SSH keys
- **Auto-detection**: Automatically detect embedded signatures

## Integration Points

This example demonstrates integration with:

- **Bazel toolchain system**: wasmsign2 as a first-class tool
- **Provider system**: Structured data flow between signing rules
- **Validation pipeline**: Signature verification in wasm_validate
- **Multi-format support**: OpenSSH and compact key formats
- **Cross-platform builds**: Works on Linux, macOS, and Windows

## Production Usage

For production use:

1. **Generate keys securely** and store private keys safely
2. **Use detached signatures** for components that will be distributed
3. **Integrate with CI/CD** by automating key management
4. **Verify signatures** in deployment pipelines
5. **Monitor signature status** in production environments

## Advanced Features

### Partial Verification

```starlark
wasm_verify(
    name = "partial_verify",
    signed_component = ":signed_component",
    keys = ":my_keys",
    split_regex = "function.*",  # Only verify specific sections
)
```

### Multi-signature Support

Multiple signatures can be added to the same component by chaining signing operations.

### Custom Verification Workflows

The provider system allows building custom verification workflows that combine multiple verification methods.
