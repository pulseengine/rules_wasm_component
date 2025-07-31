# WAC Remote Composition Example

This example demonstrates how to use the `wac_remote_compose` rule to compose local WebAssembly components with remote components fetched from registries using wkg.

## Overview

The `wac_remote_compose` rule extends the existing WAC composition capabilities by:

1. **Fetching remote components** from registries using wkg
2. **Combining local and remote components** in a single composition
3. **Supporting multiple registry types** (OCI, Warg, local)
4. **Maintaining build reproducibility** through explicit versioning

## Example Structure

```
examples/wac_remote_compose/
├── BUILD.bazel           # Build configuration
├── src/lib.rs           # Local component implementation
├── wit/frontend.wit     # Local component interface
├── composition/         # WAC composition files
│   └── microservices.wac
└── README.md           # This file
```

## Usage

### Basic Remote Composition

```starlark
wac_remote_compose(
    name = "distributed_system",
    local_components = {
        "frontend": ":local_frontend",
    },
    remote_components = {
        "auth_service": "example-registry/auth@1.0.0",
        "data_service": "wasi:data@0.2.0",
    },
    composition = """
        let frontend = new frontend:component { ... };
        let auth = new auth_service:component { ... };
        let data = new data_service:component { ... };

        connect frontend.auth_request -> auth.validate;
        connect frontend.data_request -> data.query;

        export frontend as main;
    """,
)
```

### Using External Composition Files

```starlark
wac_remote_compose(
    name = "microservices_system",
    local_components = {
        "gateway": ":local_frontend",
    },
    remote_components = {
        "user_service": "my-org/users@2.1.0",
        "payment_service": "my-org/payments@1.5.0",
    },
    composition_file = "composition/microservices.wac",
)
```

## Remote Component Specifications

Remote components are specified using the format:

- `"package@version"` - Uses default registry
- `"registry/package@version"` - Uses specific registry

Examples:

- `"auth@1.0.0"` - Package "auth" version 1.0.0 from default registry
- `"my-registry/auth@1.0.0"` - Package "auth" from "my-registry"
- `"wasi:http@0.2.0"` - WASI HTTP interface version 0.2.0

## Building

```bash
# Build the distributed system composition
bazel build //examples/wac_remote_compose:distributed_system

# Build the microservices system composition
bazel build //examples/wac_remote_compose:microservices_system
```

## Integration Benefits

1. **Distributed Development**: Teams can develop components independently and compose them at build time
2. **Version Management**: Explicit versioning ensures reproducible builds
3. **Registry Flexibility**: Support for multiple registry types and custom registries
4. **Build-time Fetching**: Components are fetched during build, not runtime
5. **Local Development**: Mix local development components with stable remote dependencies

## Requirements

- wkg toolchain configured (automatically set up by the wasm_toolchain extension)
- Access to component registries (OCI, Warg, or local)
- WAC toolchain (part of the standard wasm toolchain)

## Troubleshooting

- Ensure remote components exist in the specified registries
- Check network access if using remote registries
- Verify component interface compatibility in WAC compositions
- Use `--no-validate` flag in WAC if encountering validation issues during development
