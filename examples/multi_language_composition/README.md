# Multi-Language WebAssembly Component Composition

> **State-of-the-art WebAssembly Component Model implementation with Bazel**

This example demonstrates WebAssembly component composition using **wac_compose**, the official WebAssembly Composition (WAC) standard from the Bytecode Alliance.

## 🚀 Quick Start

### Simple Component Usage

```bash
# Build the checksum updater component
bazel build //examples/multi_language_composition:checksum_updater_simple

# Run the component
wasmtime run bazel-bin/examples/multi_language_composition/checksum_updater_simple.wasm test --verbose
```

### Real Multi-Language Composition Examples

For actual multi-language component composition, see these production examples:

#### 1. **Multi-Profile Composition**
See `//examples/multi_profile:*` for components with different build profiles:

```starlark
wac_compose(
    name = "development_system",
    components = {
        ":camera_sensor_debug": "sensor:interfaces",
        ":object_detection_release": "ai:interfaces",  # Mix profiles!
    },
    component_profiles = {
        "ai:interfaces": "release",  # Override per-component
    },
    composition = """
        let camera = new sensor:interfaces { ... };
        let ai = new ai:interfaces { ... };
        export ai as main;
    """,
)
```

#### 2. **Multi-Service Integration**
See `//test/integration:multi_service_system` for component interconnection:

```starlark
wac_compose(
    name = "multi_service_system",
    components = {
        ":service_a_component": "test:service-a",
        ":service_b_component": "test:service-b",
    },
    composition = """
        let service-a = new test:service-a { ... };
        let service-b = new test:service-b {
            storage: service-a.storage,  // Connect components!
            ...
        };
        export service-b as main;
    """,
)
```

#### 3. **OCI Registry Composition**
See `//examples/wac_oci_composition:*` for production deployment:

```starlark
wac_remote_compose(
    name = "production_system",
    components = {
        "frontend": "ghcr.io/org/frontend:v1.0",
        "backend": "ghcr.io/org/backend:v1.0",
    },
    composition_file = "production.wac",
)
```

## 📋 Why wac_compose?

### ✅ Official WebAssembly Standard

`wac_compose` uses the **official WAC tool** from the Bytecode Alliance, ensuring:
- **Standards compliance** with WebAssembly Component Model
- **Proper component interconnection** through WIT interfaces
- **Full composition language** support
- **Active development** and ecosystem support

### ✅ Production Features

- **Multi-profile builds** - Mix debug/release components
- **Per-component configuration** - Granular control
- **No Python scripts** - Windows compatible
- **Hermetic builds** - Reproducible across platforms
- **Component interconnection** - Real inter-component communication

### ✅ Working Examples

| Example | Description | Location |
|---------|-------------|----------|
| Multi-Profile | Different build profiles per component | `//examples/multi_profile:*` |
| Service Integration | Component interconnection patterns | `//test/integration:multi_service_system` |
| WAC OCI | Production deployment with registries | `//examples/wac_oci_composition:*` |
| WAC Remote | Remote component composition | `//examples/wac_remote_compose:*` |

## 🔧 Component Composition with wac_compose

### Basic Composition

```starlark
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")

wac_compose(
    name = "my_system",
    components = {
        ":frontend_component": "app:frontend",
        ":backend_component": "app:backend",
    },
    composition = """
        let frontend = new app:frontend { ... };
        let backend = new app:backend { ... };

        connect frontend.request -> backend.handler;

        export frontend as main;
    """,
)
```

### Auto-Generated Composition

If you don't specify a composition, wac_compose auto-generates one:

```starlark
wac_compose(
    name = "simple_system",
    components = {
        ":component_a": "pkg:component-a",
        ":component_b": "pkg:component-b",
    },
    # No composition specified - auto-generated
)
```

Generates:
```wac
let component-a = new pkg:component-a { ... };
let component-b = new pkg:component-b { ... };
export component-a as main;
```

## 📚 WebAssembly Component Model

### WIT Interface Definitions

Components communicate through WebAssembly Interface Types (WIT):

```wit
// wit/frontend.wit
package app:frontend@1.0.0;

interface display {
    show-message: func(message: string);
}

interface client {
    make-request: func(data: string) -> string;
}

world frontend {
    export display;
    import client;
}
```

### Component Implementation

```rust
use app_frontend_bindings::{
    exports::app::frontend::display::Guest,
    app::frontend::client,
};

struct Frontend;

impl Guest for Frontend {
    fn show_message(message: String) {
        println!("Frontend: {}", message);
    }
}

app_frontend_bindings::export!(Frontend with_types_in app_frontend_bindings);
```

## 🏗️ Bazel Integration

### Complete Build

```starlark
# Define WIT interfaces
wit_library(
    name = "interfaces",
    srcs = ["wit/interfaces.wit"],
    package_name = "app:interfaces@1.0.0",
    world = "app",
)

# Build Rust component
rust_wasm_component_bindgen(
    name = "app_component",
    srcs = ["src/lib.rs"],
    wit = ":interfaces",
    profiles = ["debug", "release"],
)

# Compose with other components
wac_compose(
    name = "full_system",
    components = {
        ":app_component": "app:interfaces",
        ":other_component": "other:interfaces",
    },
)
```

## 🧪 Testing Compositions

```bash
# Run build tests
bazel test //examples/multi_language_composition:multi_language_tests

# Build all targets
bazel build //examples/multi_language_composition:all

# Run specific composition
wasmtime run bazel-bin/examples/multi_profile/development_system.wasm
```

## 📊 Performance Benefits

WAC compositions provide:

- **Near-native speed** - Direct function calls between components
- **Zero-copy sharing** - Efficient memory management
- **Lazy loading** - Components loaded on demand
- **Memory isolation** - Security through sandboxing

## 🎯 Migration from Old Patterns

If you're using older composition patterns:

```starlark
# ❌ OLD: multi_language_wasm_component (removed)
multi_language_wasm_component(
    name = "old_composition",
    components = [":component"],
    composition_type = "simple",
)

# ✅ NEW: wac_compose (official standard)
wac_compose(
    name = "new_composition",
    components = {":component": "pkg:component"},
)

# Or for single component, just use directly:
alias(
    name = "new_composition",
    actual = ":component",
)
```

## 📖 Further Reading

- [WAC Composition Guide](../../docs-site/src/content/docs/composition/wac.md)
- [Multi-Profile Builds](../../docs-site/src/content/docs/guides/multi-profile-builds.mdx)
- [WebAssembly Component Model](https://component-model.bytecodealliance.org/)
- [WIT Language Specification](https://component-model.bytecodealliance.org/design/wit.html)

---

> **This example demonstrates state-of-the-art WebAssembly Component Model implementation with Bazel using the official WAC composition standard from the Bytecode Alliance.**
