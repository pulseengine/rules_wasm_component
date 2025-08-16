# WAC + OCI Composition Examples

This directory demonstrates comprehensive WebAssembly Component composition using WAC (WebAssembly Composition) with components sourced from OCI (Open Container Initiative) registries.

## Overview

The examples show how to build distributed WebAssembly applications by composing:

- **Local components** built with Bazel in your workspace
- **Remote components** pulled from OCI registries (GitHub Container Registry, Docker Hub, etc.)

## Key Features Demonstrated

### 🔄 Component Integration

- Pull WebAssembly components from multiple OCI registries
- Compose local and remote components seamlessly
- Support for different authentication methods (tokens, OAuth, basic auth)

### 🔐 Security & Verification

- Component signature verification during pull operations
- Registry authentication and credential management
- Security policy enforcement for production environments

### 🏗️ Architecture Patterns

- **Microservices**: Frontend + multiple backend services
- **IoT Platform**: Edge gateway + cloud processing services
- **Enterprise**: SSO + audit + backup + monitoring services

### 🌐 Multi-Registry Support

- GitHub Container Registry (`ghcr.io`)
- Docker Hub (`docker.io`)
- AWS Elastic Container Registry (`*.dkr.ecr.*.amazonaws.com`)
- Azure Container Registry (`*.azurecr.io`)
- Local registries (`localhost:5000`)

## Examples Overview

### Basic Examples

#### 1. Basic OCI Component Pulling

```bazel
wasm_component_from_oci(
    name = "auth_service_from_oci",
    registry = "localhost:5000",
    namespace = "wasm-examples",
    component_name = "auth-service",
    tag = "v1.0.0",
    registry_config = ":example_registries",
)
```

#### 2. Simple Distributed App

```bazel
wac_compose_with_oci(
    name = "basic_distributed_app",
    local_components = {
        "frontend": ":frontend_component",
    },
    oci_components = {
        "auth_service": "localhost:5000/wasm-examples/auth-service:v1.0.0",
        "data_service": "localhost:5000/wasm-examples/data-service:latest",
    },
    # ... composition code
)
```

### Advanced Examples

#### 3. Secure Multi-Registry Composition

```bazel
wac_compose_with_oci(
    name = "secure_distributed_app",
    oci_components = {
        "auth_service": "localhost:5000/wasm-examples/signed-service:v1.0.0",
        "payment_service": "ghcr.io/example/payment-service:v2.1.0",
    },
    registry_config = ":production_registries",
    verify_signatures = True,
    public_key = ":verification_keys",
)
```

#### 4. Microservices with Convenience Macro

```bazel
wac_microservices_app(
    name = "ecommerce_app",
    frontend_component = ":frontend_component",
    services = {
        "user_service": "ghcr.io/ecommerce/users:v2.0.0",
        "product_service": "ghcr.io/ecommerce/products:v1.8.0",
        "order_service": "ghcr.io/ecommerce/orders:v1.2.0",
        "payment_service": "docker.io/payments/processor:v3.1.0",
    },
    registry_config = ":production_registries",
    verify_signatures = True,
)
```

#### 5. IoT Platform Architecture

```bazel
wac_distributed_system(
    name = "iot_platform",
    components = {
        "local": {
            "gateway": ":gateway_component",
            "frontend": ":frontend_component",
        },
        "oci": {
            "device_manager": "ghcr.io/iot/device-manager:v1.0.0",
            "data_processor": "aws-ecr.amazonaws.com/iot/processor:v2.3.0",
            "alert_system": "azure.azurecr.io/iot/alerts:v1.1.0",
            "time_series_db": "docker.io/timeseries/influxdb-wasm:v2.0.0",
        },
    },
)
```

### Enterprise Examples

#### 6. Enterprise System with External Composition

```bazel
wac_compose_with_oci(
    name = "enterprise_system",
    composition_file = "compositions/enterprise.wac",
    local_components = {
        "gateway": ":gateway_component",
    },
    oci_components = {
        "auth": "ghcr.io/enterprise/sso:v3.0.0",
        "audit": "ghcr.io/enterprise/audit-log:v1.5.0",
        "backup": "azure.azurecr.io/enterprise/backup:v2.0.0",
    },
    verify_signatures = True,
)
```

## Registry Configuration

### Basic Configuration

```bazel
wkg_registry_config(
    name = "example_registries",
    default_registry = "localhost",
    registries = [
        "localhost|localhost:5000|oci",
        "github|ghcr.io|oci|env|GITHUB_TOKEN",
        "docker|docker.io|oci|env|DOCKER_TOKEN",
    ],
)
```

### Production Configuration

```bazel
wkg_registry_config(
    name = "production_registries",
    cache_dir = "/tmp/wkg_cache",
    default_registry = "github",
    enable_mirror_fallback = True,
    registries = [
        "local|localhost:5000|oci",
        "github|ghcr.io|oci|env|GITHUB_TOKEN",
        "docker|docker.io|oci|env|DOCKER_TOKEN",
        "aws|123456789.dkr.ecr.us-west-2.amazonaws.com|oci|oauth|client_id|client_secret",
        "azure|myregistry.azurecr.io|oci|basic|username|password",
    ],
    timeout_seconds = 60,
)
```

## Component Interfaces

### Frontend Component (wit/frontend.wit)

- **Exports**: HTTP handler for web requests
- **Imports**: Auth service, data service, logging service
- **Use Cases**: Web frontends, API clients, user interfaces

### Gateway Component (wit/gateway.wit)

- **Exports**: HTTP handler, routing interface
- **Imports**: User API, analytics API, metrics, device management
- **Use Cases**: API gateways, reverse proxies, service meshes

## Development Workflow

### 1. Local Development

```bash
# Build local components
bazel build //examples/wac_oci_composition:frontend_component
bazel build //examples/wac_oci_composition:gateway_component

# Test with local mock services
bazel build //examples/wac_oci_composition:app_development
```

### 2. Integration Testing

```bash
# Compose with mix of local and OCI components
bazel build //examples/wac_oci_composition:basic_distributed_app

# Test signature verification
bazel build //examples/wac_oci_composition:secure_distributed_app
```

### 3. Production Deployment

```bash
# Build production composition with full OCI services
bazel build //examples/wac_oci_composition:app_production

# Enterprise composition with security policies
bazel build //examples/wac_oci_composition:enterprise_system
```

## Authentication Setup

### Environment Variables

```bash
# GitHub Container Registry
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# Docker Hub
export DOCKER_TOKEN=dckr_pat_xxxxxxxxxxxxxxxxxxxx

# AWS ECR (when using OAuth)
export AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Credential Files

```bash
# Docker config file
~/.docker/config.json

# Kubernetes service account
/var/run/secrets/kubernetes.io/serviceaccount/token
```

## Security Considerations

### Component Signing

- All production components should be signed using `wasmsign2`
- Use `verify_signatures = True` for production compositions
- Maintain separate keys for development and production

### Registry Authentication

- Store registry credentials securely (environment variables, credential files)
- Use least-privilege access tokens
- Rotate credentials regularly

### Network Security

- Use HTTPS registries only in production
- Consider registry mirrors for air-gapped environments
- Implement network policies for component communication

## Troubleshooting

### Common Issues

#### 1. Authentication Failures

```bash
# Check environment variables
echo $GITHUB_TOKEN

# Verify registry configuration
bazel build //examples/wac_oci_composition:example_registries
```

#### 2. Component Pull Failures

```bash
# Test component pulling individually
bazel build //examples/wac_oci_composition:auth_service_from_oci

# Check registry connectivity
curl -I https://ghcr.io/v2/
```

#### 3. Composition Errors

```bash
# Validate WAC composition syntax
wac --help compose

# Check component interfaces match
bazel build //examples/wac_oci_composition:frontend_component --verbose_failures
```

### Debug Mode

Enable verbose logging by setting:

```bash
export WKG_LOG_LEVEL=debug
export WAC_LOG_LEVEL=debug
```

## Best Practices

### 1. Component Versioning

- Use semantic versioning for component tags
- Pin specific versions in production compositions
- Use `latest` only for development

### 2. Registry Organization

- Use consistent namespace conventions
- Group related components under common namespaces
- Document component dependencies

### 3. Composition Patterns

- Keep compositions focused and modular
- Use external composition files for complex systems
- Document service connections and data flow

### 4. Testing Strategy

- Test local components independently
- Use mock services for development
- Validate full compositions in staging environment

## Further Reading

- [WAC Specification](https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md)
- [WebAssembly Component Model](https://component-model.bytecodealliance.org/)
- [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec)
- [Component Signing with wasmsign2](../wasm_signing/README.md)
- [OCI Publishing Examples](../oci_publishing/README.md)
