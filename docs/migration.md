# Migration Guide

This guide helps you migrate from shell scripts or other build systems to Bazel rules for WebAssembly components.

## From Shell Scripts

### Before (Shell Script)

```bash
#!/bin/bash

# Build component
cargo build --release --target wasm32-wasip2

# Convert to component
wasm-tools component new target/wasm32-wasip2/release/my_component.wasm \
    -o my_component.wasm

# Compose components
wac compose my_composition.wac -o final_system.wasm
```

### After (Bazel)

```starlark
# BUILD.bazel

load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component")
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")

wit_library(
    name = "interfaces",
    srcs = ["my_interface.wit"],
)

rust_wasm_component(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit = ":interfaces",
)

wac_compose(
    name = "final_system",
    components = {
        "main": ":my_component",
    },
    composition_file = "my_composition.wac",
)
```

## From ADAS Shell Scripts

The ADAS project used several shell scripts for building and composition.

### Shell Script Approach

- `build-composed.sh` - Build all components and compose
- `fix-profiles.sh` - Fix Cargo.toml issues
- Manual dependency management

### Bazel Approach

- Declarative BUILD files
- Automatic dependency resolution
- Parallel builds
- Incremental compilation
- Better caching

### Migration Steps

1. **Add MODULE.bazel** to your project root:

```starlark
module(name = "my_adas_project", version = "1.0.0")

bazel_dep(name = "rules_wasm_component", version = "0.1.0")
bazel_dep(name = "rules_rust", version = "0.46.0")
```

2. **Convert component builds** from individual Cargo.toml to BUILD.bazel:

```starlark
# components/camera-front/BUILD.bazel
rust_wasm_component(
    name = "camera_front",
    srcs = ["src/lib.rs"],
    wit_bindgen = "//wit:sensor_interfaces",
)
```

3. **Replace wac.toml** with wac_compose rules:

```starlark
# BUILD.bazel (root)
wac_compose(
    name = "adas_complete_system",
    components = {
        "camera-front": "//components/camera-front",
        "object-detection": "//components/ai/object-detection",
        # ... more components
    },
    composition_file = "adas-system.wac",
)
```

4. **Remove shell scripts** and use Bazel commands:

```bash
# Instead of ./build-composed.sh
bazel build //:adas_complete_system

# Instead of ./build-and-run.sh
bazel run //:adas_complete_system
```

## Benefits of Migration

### Build Performance

- **Parallel compilation**: Components build in parallel
- **Incremental builds**: Only changed components rebuild
- **Distributed builds**: Scale across multiple machines
- **Build caching**: Share build artifacts across team

### Dependency Management

- **Hermetic builds**: Reproducible across environments
- **Version pinning**: Exact dependency versions
- **Transitive deps**: Automatic dependency resolution
- **Cross-platform**: Works on Linux, macOS, Windows

### Developer Experience

- **IDE integration**: Better code completion and navigation
- **Error reporting**: Clear, actionable build errors
- **Testing**: Integrated test execution
- **Documentation**: Self-documenting build rules

## Common Issues

### Target Configuration

Make sure your MODULE.bazel configures WASM targets:

```starlark
rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
rust.toolchain(
    extra_target_triples = [
        "wasm32-wasip2",
        "wasm32-wasi",
    ],
)
```

### WIT Dependencies

Organize WIT files in a dedicated package:

```
wit/
├── BUILD.bazel
├── interfaces/
│   ├── sensor.wit
│   ├── ai.wit
│   └── control.wit
└── deps/
    └── wasi/
```

### Component Adapter

For WASI Preview 1 compatibility:

```starlark
rust_wasm_component(
    name = "legacy_component",
    srcs = ["src/lib.rs"],
    adapter = "@wasi_preview1_adapter//file",
)
```
