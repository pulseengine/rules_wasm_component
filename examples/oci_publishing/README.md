# WebAssembly Component OCI Publishing Example

This example demonstrates the complete workflow for publishing WebAssembly components to OCI registries with optional cryptographic signing using wasmsign2.

## Features Demonstrated

- **Component Preparation**: Building Rust WebAssembly components
- **Cryptographic Signing**: Using wasmsign2 with OpenSSH keys (embedded and detached signatures)
- **OCI Image Creation**: Preparing components for OCI registry publishing
- **Registry Publishing**: Publishing to local and remote OCI registries
- **Registry Authentication**: Supporting multiple registry types with authentication
- **Metadata Handling**: OCI annotations and component metadata
- **Workflow Automation**: Single-step publishing with convenience macros
- **Security Policies**: Enterprise-grade security policy enforcement
- **Automated Security**: Policy-driven signing and validation workflows
- **Multi-Registry Publishing**: Synchronized publishing to multiple registries

## Example Components

### 1. Basic OCI Image Preparation

```bash
# Prepare unsigned OCI image
bazel build //examples/oci_publishing:hello_oci_unsigned_image

# Prepare signed OCI image with embedded signature
bazel build //examples/oci_publishing:hello_oci_signed_image

# Prepare signed OCI image with detached signature
bazel build //examples/oci_publishing:hello_oci_detached_image
```

### 2. Registry Publishing

```bash
# Publish unsigned component (requires local OCI registry at localhost:5000)
bazel run //examples/oci_publishing:publish_unsigned

# Publish signed component
bazel run //examples/oci_publishing:publish_signed

# Dry run publishing (for testing)
bazel run //examples/oci_publishing:publish_dry_run
```

### 3. Complete Workflow

```bash
# One-step component preparation and publishing
bazel run //examples/oci_publishing:publish_complete_workflow

# Publish to GitHub Container Registry (requires GITHUB_TOKEN)
# Set GITHUB_TOKEN environment variable and modify dry_run=False
bazel run //examples/oci_publishing:publish_to_github

# Multi-registry publishing
bazel run //examples/oci_publishing:publish_to_all_registries
```

### 4. Security Policy Management

```bash
# Build security policies
bazel build //examples/oci_publishing:basic_security_policy
bazel build //examples/oci_publishing:strict_security_policy
bazel build //examples/oci_publishing:enterprise_security_policy

# Secure publishing with policy enforcement
bazel run //examples/oci_publishing:secure_publish_basic
bazel run //examples/oci_publishing:secure_publish_strict
bazel run //examples/oci_publishing:secure_publish_enterprise
```

## Registry Setup

### Local Registry

Start a local OCI registry for testing:

```bash
docker run -d -p 5000:5000 --name registry registry:2
```

### GitHub Container Registry

1. Create a Personal Access Token with `write:packages` permission
2. Set the environment variable:

   ```bash
   export GITHUB_TOKEN=ghp_your_token_here
   ```

3. Modify the `dry_run = False` in the GitHub publish target

### Docker Hub

1. Create a Docker Hub access token
2. Set the environment variable:

   ```bash
   export DOCKER_TOKEN=your_docker_token_here
   ```

3. Configure the registry in `wkg_registry_config`

## Registry Configuration

The example includes a comprehensive registry configuration supporting:

- **Local Registry**: `localhost:5000` (for testing)
- **GitHub Container Registry**: `ghcr.io` (with token authentication)
- **Docker Hub**: `docker.io` (with token authentication)

```starlark
wkg_registry_config(
    name = "registry_config",
    registries = [
        "localhost|localhost:5000|oci",
        "github|ghcr.io|oci|token|${GITHUB_TOKEN}",
        "docker|docker.io|oci|token|${DOCKER_TOKEN}",
    ],
    default_registry = "localhost",
)
```

## Signature Verification

The published components include cryptographic signatures that can be verified:

```bash
# Verify embedded signature
wasmsign2 verify -i bazel-bin/examples/oci_publishing/hello_oci_signed_image_oci.wasm

# Verify detached signature
wasmsign2 verify -i bazel-bin/examples/oci_publishing/hello_oci_detached_image_oci.wasm \
  -S bazel-bin/examples/oci_publishing/hello_oci_detached_image_signature.sig
```

### Known Limitations

**OpenSSH Key Format**: Currently, wasmsign2 with OpenSSH format keys (`-Z` flag) has compatibility issues in the Bazel sandbox environment on some platforms. Use compact format keys (default) for reliable signing:

```starlark
# ✅ WORKS: Compact format keys
wasm_keygen(
    name = "signing_keys",
    openssh_format = False,  # Default
)

# ⚠️ ISSUE: OpenSSH format keys may fail in sandbox
wasm_keygen(
    name = "openssh_keys",
    openssh_format = True,   # May cause I/O errors in sandbox
)
```

The compact format provides the same security guarantees and is fully compatible with wasmsign2 verification.

## OCI Annotations

The published images include comprehensive OCI annotations:

- `org.opencontainers.image.description`: Component description
- `org.opencontainers.image.source`: Source repository URL
- `org.opencontainers.image.version`: Component version
- `com.wasm.component.type`: WebAssembly component type
- `com.wasm.component.security`: Security/signing status
- `com.wasmsign2.signature.type`: Signature type (if signed)
- `com.wasmsign2.key.format`: Key format used for signing

## Workflow Architecture

1. **Component Building**: Rust → WASM component (using rust_wasm_component)
2. **Key Generation**: OpenSSH key pairs (using wasm_keygen)
3. **Component Signing**: wasmsign2 integration (optional)
4. **OCI Image Preparation**: Metadata creation and annotation (using wasm_component_oci_image)
5. **Registry Publishing**: wkg-based OCI push (using wasm_component_publish)
6. **End-to-End**: Single macro for complete workflow (using wasm_component_oci_publish)

## Testing the Example

1. **Build all components**:

   ```bash
   bazel build //examples/oci_publishing/...
   ```

2. **Start local registry**:

   ```bash
   docker run -d -p 5000:5000 --name registry registry:2
   ```

3. **Test dry run publishing**:

   ```bash
   bazel run //examples/oci_publishing:publish_dry_run
   ```

4. **Publish to local registry**:

   ```bash
   bazel run //examples/oci_publishing:publish_complete_workflow
   ```

5. **Verify the published component**:

   ```bash
   # Pull the component back
   wkg pull --registry localhost:5000 --package examples/hello-complete --version complete-v1.0.0

   # Verify signature
   wasmsign2 verify -i hello-complete.wasm
   ```

This example demonstrates the complete production-ready workflow for publishing signed WebAssembly components to OCI registries using Bazel.

## Security Policy Management

The example includes comprehensive security policy management for enterprise deployments:

### Security Policy Types

1. **Basic Security Policy** (`basic_security_policy`):
   - No signing required by default
   - Suitable for development and testing environments
   - Flexible configuration for different use cases

2. **Strict Security Policy** (`strict_security_policy`):
   - Signing required for production registries
   - Registry-specific signing requirements
   - Component pattern-based policies

3. **Enterprise Security Policy** (`enterprise_security_policy`):
   - All components must be signed
   - OpenSSH format signatures for compliance
   - Detached signatures for audit trails

### Security Features

- **Policy-Driven Signing**: Automatic signing based on registry and component policies
- **Component Validation**: Built-in WebAssembly component validation
- **Registry Security Checks**: Registry-specific security requirement enforcement
- **Compliance Annotations**: Automatic security metadata in OCI annotations
- **Audit Trail**: Comprehensive logging and security tracking
- **Key Management**: Support for multiple key formats and sources

### Policy Configuration

Security policies support:

- **Registry Policies**: Different signing requirements per registry
- **Component Policies**: Pattern-based rules for component names
- **Key Source Configuration**: File, environment, or keychain-based keys
- **Signature Types**: Embedded or detached signatures
- **Key Formats**: Compact or OpenSSH format keys

Example policy configuration:

```starlark
wasm_security_policy(
    name = "enterprise_policy",
    default_signing_required = True,
    signature_type = "detached",
    openssh_format = True,
    registry_policies = [
        "production|required|enterprise_keys",
        "staging|required|staging_keys",
        "development|optional",
    ],
    component_policies = [
        "prod-*|required|enterprise_keys",
        "test-*|optional",
    ],
)
```
