# Multi-File Component Packaging Examples

This directory demonstrates **four proven approaches** for packaging WebAssembly components with additional files like configuration, templates, assets, and documentation.

## 🎯 Quick Start

```bash
# Build all packaging examples
bazel build //examples/multi_file_packaging:all_examples

# Test all approaches
bazel test //examples/multi_file_packaging:multi_file_packaging_tests

# Run specific examples
bazel run //examples/multi_file_packaging:embedded_service_signed
```

## 📦 Packaging Approaches

### 1. **Embedded Resources** (Recommended)

- **Files**: Built directly into the component at compile time
- **Access**: Via `include_str!()` and `include_bytes!()` macros
- **Best for**: Configuration files, small templates, schemas under 1MB
- **Security**: Single signature covers everything
- **Example**: `src/embedded_service.rs`

```rust
// Files embedded at compile time
const CONFIG: &str = include_str!("../config/production.json");
const TEMPLATE: &str = include_str!("../templates/response.html");
```

### 2. **OCI Image Layers** (Advanced)

- **Files**: Separate container layers accessed via WASI filesystem
- **Access**: Via `std::fs` APIs with mounted paths
- **Best for**: Large assets, shared files, independent updates
- **Security**: Dual signing (component + OCI manifest)
- **Example**: `src/layered_service.rs`

```rust
// Read from mounted layer
let config = std::fs::read_to_string("/etc/service/config.json")?;
let template = std::fs::read_to_string("/etc/templates/response.html")?;
```

### 3. **Bundle Archives**

- **Files**: Pre-packaged tar/zip archive with component
- **Access**: Runtime extraction and parsing
- **Best for**: Document collections, related file sets
- **Security**: Single signature for entire bundle
- **Example**: `src/bundled_service.rs`

```rust
// Extract from embedded bundle
let bundle_data = include_bytes!("../bundle.tar");
let archive = Archive::new(Cursor::new(bundle_data));
```

### 4. **Sidecar Artifacts** (Complex)

- **Files**: Separate OCI artifacts with coordinated deployment
- **Access**: Service discovery, shared volumes, or APIs
- **Best for**: Multi-team ownership, independent lifecycles
- **Security**: Multiple signatures requiring coordination
- **Example**: `src/sidecar_service.rs`

```rust
// Access via sidecar coordination
let config_endpoint = std::env::var("CONFIG_SIDECAR_ENDPOINT")?;
let config = fetch_from_sidecar(&config_endpoint).await?;
```

## 🚀 Building Examples

### Build Individual Examples

```bash
# Embedded resources approach
bazel build //examples/multi_file_packaging:embedded_service_signed

# Multi-layer OCI approach
bazel build //examples/multi_file_packaging:layered_service_signed

# Bundle archive approach
bazel build //examples/multi_file_packaging:bundled_service_image

# Sidecar artifacts approach
bazel build //examples/multi_file_packaging:sidecar_core_service
```

### Generated Files

Each example produces different artifacts:

```
bazel-bin/examples/multi_file_packaging/
├── embedded_service_signed_oci_image_oci.wasm          # Embedded: Single file
├── embedded_service_signed_oci_image_oci_metadata.json
├── layered_service_signed_oci_image_oci.wasm           # Layered: Component + layers
├── layered_service_signed_oci_image_oci_metadata.json
├── bundled_service_image_oci.wasm                      # Bundle: Archive artifact
├── bundled_service_image_oci_metadata.json
├── sidecar_core_service_oci.wasm                       # Sidecar: Core component
├── sidecar_core_service_oci_metadata.json
└── sidecar_deployment.yaml                            # Sidecar: Coordination manifest
```

## 🔐 Security Features

All examples demonstrate component signing:

```bash
# Keys are generated automatically
ls bazel-bin/examples/multi_file_packaging/
# ├── example.public    # Public key for verification
# └── example.secret    # Private key for signing
```

### Signature Coverage

| Approach     | Component Signature | Additional Protection            |
| ------------ | ------------------- | -------------------------------- |
| **Embedded** | ✅ Covers all files | Single signature                 |
| **Layered**  | ✅ Component only   | + OCI manifest signature         |
| **Bundle**   | ✅ Entire archive   | Single signature                 |
| **Sidecar**  | ✅ Component only   | + Individual artifact signatures |

## 📊 Comparison Matrix

| Factor                 | Embedded       | Layered     | Bundle         | Sidecar      |
| ---------------------- | -------------- | ----------- | -------------- | ------------ |
| **Simplicity**         | ⭐⭐⭐⭐⭐     | ⭐⭐⭐      | ⭐⭐⭐⭐       | ⭐⭐         |
| **Performance**        | ⭐⭐⭐⭐⭐     | ⭐⭐⭐⭐    | ⭐⭐⭐         | ⭐⭐⭐       |
| **Flexibility**        | ⭐⭐           | ⭐⭐⭐⭐    | ⭐⭐⭐         | ⭐⭐⭐⭐⭐   |
| **File Size Limit**    | < 1MB          | No limit    | < 50MB         | No limit     |
| **Update Granularity** | All-or-nothing | Per layer   | All-or-nothing | Per artifact |
| **Team Coordination**  | Single team    | Single team | Single team    | Multi-team   |

## 🛠 Development Workflow

### Adding Files to Embedded Approach

1. **Add file to BUILD.bazel**:

```python
genrule(
    name = "my_config",
    outs = ["config/my_config.json"],
    cmd = "echo '{\"key\": \"value\"}' > $@",
)
```

2. **Reference in component data**:

```python
rust_wasm_component_bindgen(
    name = "my_component",
    data = [":my_config"],
    # ...
)
```

3. **Embed in Rust code**:

```rust
const MY_CONFIG: &str = include_str!("../config/my_config.json");
```

### Adding Layers to OCI Approach

1. **Create file layer**:

```python
genrule(
    name = "assets_layer",
    srcs = ["//assets:all_files"],
    outs = ["assets.tar"],
    cmd = "tar -cf $@ $(SRCS)",
)
```

2. **Add to OCI image**:

```python
wasm_component_signed_oci_image(
    name = "layered_component",
    # Would add layer configuration in real implementation
)
```

## 🧪 Testing

### Run All Tests

```bash
bazel test //examples/multi_file_packaging:multi_file_packaging_tests
```

### Verify Signatures

```bash
# Extract public key
cp bazel-bin/examples/multi_file_packaging/example.public /tmp/

# Verify component signatures
wasmsign2 verify bazel-bin/examples/multi_file_packaging/embedded_service_signed_oci_image_oci.wasm \
  --public-key /tmp/example.public
```

### Test Component Loading

```bash
# Run with wasmtime (if available)
wasmtime run bazel-bin/examples/multi_file_packaging/embedded_service_signed_oci_image_oci.wasm
```

## 📖 Related Documentation

- **[Multi-File Packaging Guide](../../docs-site/src/content/docs/guides/multi-file-packaging.mdx)** - Complete documentation
- **[Component Signing](../../docs-site/src/content/docs/security/component-signing.mdx)** - Security details
- **[OCI Integration](../../docs-site/src/content/docs/security/oci-signing.mdx)** - OCI signing patterns
- **[Production Deployment](../../docs-site/src/content/docs/production/deployment-guide.mdx)** - Deployment strategies

## 🎯 Next Steps

1. **Start with embedded resources** for most use cases
2. **Move to layered approach** when files are large or update independently
3. **Consider bundles** for document collections
4. **Use sidecars** only for complex multi-team scenarios

Each approach is production-ready and includes comprehensive examples you can adapt for your specific needs.
