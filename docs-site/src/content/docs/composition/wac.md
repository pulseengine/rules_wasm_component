---
title: WAC Composition
description: Build complex multi-component systems using WebAssembly Composition (WAC)
---

## Building Applications from Components

Think of **WAC (WebAssembly Composition)** as "wiring" for your WebAssembly components. Just like connecting
electronic components on a circuit board, you can connect software components to create complete applications.

**The magic of composition:** You can take a Rust authentication service, a Go database connector, a JavaScript
frontend, and a C++ data processor - all built as separate WebAssembly components - and wire them together into a
single application.

**Why this matters:**

- **Team independence** - Different teams can work on different components in their preferred languages
- **Component reuse** - Build once, compose into multiple applications
- **Easy testing** - Test components in isolation, then test the composition
- **Flexible deployment** - Swap components without rebuilding everything

**How it works:** You write a simple "composition script" that describes which components to instantiate and how to
connect their interfaces. WAC handles all the complexity of making them work together.

## Key Concepts

WAC (WebAssembly Composition) allows you to:

- **Connect Components** - Link multiple components together through their interfaces
- **Define Data Flow** - Specify how data moves between components
- **Create Applications** - Build complete systems from component parts
- **Maintain Isolation** - Components remain independent and secure

## Basic Composition

Let's start with a simple example to understand the fundamentals of component composition.

### Simple Two-Component System

**What we're building:** A web application where a frontend component talks to a backend component. The frontend
handles user interaction while the backend processes requests.

**The composition process:** We'll define interfaces for both components, implement them separately, then use WAC to wire
them together. The beauty is that you could swap either component for a different implementation without changing the
other.

```python title="BUILD.bazel"
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

# Frontend component
wit_library(
    name = "frontend_interfaces",
    srcs = ["wit/frontend.wit"],
    package_name = "frontend:ui@1.0.0",
)

rust_wasm_component_bindgen(
    name = "frontend_component",
    srcs = ["src/frontend.rs"],
    wit = ":frontend_interfaces",
)

# Backend component
wit_library(
    name = "backend_interfaces",
    srcs = ["wit/backend.wit"],
    package_name = "backend:api@1.0.0",
)

rust_wasm_component_bindgen(
    name = "backend_component",
    srcs = ["src/backend.rs"],
    wit = ":backend_interfaces",
)

# Compose them together
wac_compose(
    name = "complete_application",
    components = {
        ":frontend_component": "frontend:ui",
        ":backend_component": "backend:api",
    },
    composition = """
        package composed:app@1.0.0;

        let frontend = new frontend:ui { ... };
        let backend = new backend:api { ... };

        // Connect frontend requests to backend
        connect frontend.make-request -> backend.handle-request;

        // Export the frontend as the main interface
        export frontend as main;
    """,
)
```

> **📋 Rule Reference:** For complete details on composition rule attributes, see [`wac_compose`](/reference/rules/#wac_compose)
> and [`wac_remote_compose`](/reference/rules/#wac_remote_compose).

### Component Interface Definitions

Define interfaces that allow composition:

```wit title="wit/frontend.wit"
package frontend:ui@1.0.0;

interface display {
    show-message: func(message: string);
    get-user-input: func() -> string;
}

interface client {
    make-request: func(data: string) -> string;
}

world frontend {
    export display;
    import client;
}
```

```wit title="wit/backend.wit"
package backend:api@1.0.0;

interface handler {
    handle-request: func(request: string) -> string;
    process-data: func(data: list<u8>) -> list<u8>;
}

world backend {
    export handler;
}
```

## Advanced Composition Patterns

### Multi-Service Architecture

Build a microservices-style application:

```python title="BUILD.bazel"
wac_compose(
    name = "microservices_app",
    components = {
        ":api_gateway": "gateway:service",
        ":auth_service": "auth:service",
        ":data_service": "data:service",
        ":user_service": "user:service",
    },
    composition = """
        package microservices:system@1.0.0;

        // Instantiate all services
        let gateway = new gateway:service { ... };
        let auth = new auth:service { ... };
        let data = new data:service { ... };
        let users = new user:service { ... };

        // Connect authentication flow
        connect gateway.authenticate -> auth.verify-token;
        connect auth.get-user-info -> users.get-user;

        // Connect data operations
        connect gateway.fetch-data -> data.query;
        connect gateway.store-data -> data.save;

        // Connect user operations
        connect gateway.user-action -> users.handle-action;

        // Export gateway as main entry point
        export gateway as main;
    """,
)
```

### Conditional Composition

Use different backends based on configuration:

```python title="BUILD.bazel"
wac_compose(
    name = "production_app",
    components = {
        ":frontend": "app:ui",
        ":database_backend": "db:postgres",
        ":cache_backend": "cache:redis",
        ":auth_backend": "auth:oauth",
    },
    composition = """
        package production:app@1.0.0;

        let ui = new app:ui { ... };
        let db = new db:postgres { ... };
        let cache = new cache:redis { ... };
        let auth = new auth:oauth { ... };

        // Primary data flow through database
        connect ui.fetch-data -> db.query;
        connect ui.save-data -> db.store;

        // Cache layer for performance
        connect db.check-cache -> cache.get;
        connect db.update-cache -> cache.set;

        // Authentication flow
        connect ui.login -> auth.authenticate;
        connect auth.verify -> db.check-permissions;

        export ui as main;
    """,
)
```

### Development vs Production Composition

Use different compositions for different environments:

```python title="BUILD.bazel"
# Development composition with mock services
wac_compose(
    name = "dev_app",
    components = {
        ":frontend": "app:ui",
        ":mock_backend": "mock:api",
        ":dev_auth": "dev:auth",
    },
    composition = """
        package dev:app@1.0.0;

        let ui = new app:ui { ... };
        let api = new mock:api { ... };
        let auth = new dev:auth { ... };

        connect ui.api-call -> api.handle;
        connect ui.authenticate -> auth.dev-login;

        export ui as main;
    """,
)

# Production composition with real services
wac_compose(
    name = "prod_app",
    components = {
        ":frontend": "app:ui",
        ":real_backend": "prod:api",
        ":oauth_auth": "oauth:service",
    },
    composition = """
        package prod:app@1.0.0;

        let ui = new app:ui { ... };
        let api = new prod:api { ... };
        let auth = new oauth:service { ... };

        connect ui.api-call -> api.handle;
        connect ui.authenticate -> auth.oauth-flow;

        export ui as main;
    """,
)
```

## Component Implementation Examples

### Frontend Component

```rust title="src/frontend.rs"
use frontend_component_bindings::{
    exports::frontend::ui::display::Guest as DisplayGuest,
    frontend::ui::client,
};

struct Frontend;

impl DisplayGuest for Frontend {
    fn show_message(message: String) {
        println!("Frontend: {}", message);
    }

    fn get_user_input() -> String {
        // In a real implementation, this would get actual user input
        "user input".to_string()
    }
}

// The frontend can make requests to other components
fn process_user_action(action: String) -> String {
    // This will be connected to the backend via WAC composition
    client::make_request(&action)
}

frontend_component_bindings::export!(Frontend with_types_in frontend_component_bindings);
```

### Backend Component

```rust title="src/backend.rs"
use backend_component_bindings::exports::backend::api::handler::Guest;

struct Backend;

impl Guest for Backend {
    fn handle_request(request: String) -> String {
        match request.as_str() {
            "ping" => "pong".to_string(),
            "hello" => "Hello from backend!".to_string(),
            data => format!("Processed: {}", data),
        }
    }

    fn process_data(data: Vec<u8>) -> Vec<u8> {
        // Simple data transformation
        data.iter().map(|b| b.wrapping_add(1)).collect()
    }
}

backend_component_bindings::export!(Backend with_types_in backend_component_bindings);
```

## Testing Compositions

### Component Integration Tests

```python title="BUILD.bazel"
load("@rules_wasm_component//wasm:defs.bzl", "wasm_validate")

# Validate the composed application
wasm_validate(
    name = "validate_composition",
    wasm_file = ":complete_application",
)

# Test the composition
sh_test(
    name = "composition_test",
    srcs = ["test_composition.sh"],
    data = [":complete_application"],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)
```

```bash title="test_composition.sh"
#!/bin/bash

# Test the composed application
wasmtime run --wasi preview2 "$1" << EOF
test input data
EOF

# Check the output
if [[ $? -eq 0 ]]; then
    echo "Composition test passed"
else
    echo "Composition test failed"
    exit 1
fi
```

## Advanced WAC Features

### Resource Management

Components can share resources efficiently:

```wit title="wit/shared.wit"
package shared:resources@1.0.0;

interface database {
    resource connection {
        constructor(url: string);
        query: func(sql: string) -> list<string>;
        close: func();
    }
}

world shared {
    export database;
}
```

### Streaming Data

Handle continuous data streams between components:

```wit title="wit/streaming.wit"
package streaming:data@1.0.0;

interface stream {
    resource data-stream {
        constructor();
        write: func(data: list<u8>);
        read: func() -> option<list<u8>>;
        close: func();
    }
}

world streaming {
    export stream;
}
```

### Plugin Architecture

Build extensible applications with plugin systems:

```python title="BUILD.bazel"
wac_compose(
    name = "extensible_app",
    components = {
        ":core_app": "core:application",
        ":plugin_a": "plugins:feature-a",
        ":plugin_b": "plugins:feature-b",
        ":plugin_c": "plugins:feature-c",
    },
    composition = """
        package extensible:system@1.0.0;

        let core = new core:application { ... };
        let pluginA = new plugins:feature-a { ... };
        let pluginB = new plugins:feature-b { ... };
        let pluginC = new plugins:feature-c { ... };

        // Register plugins with core
        connect core.register-plugin -> pluginA.initialize;
        connect core.register-plugin -> pluginB.initialize;
        connect core.register-plugin -> pluginC.initialize;

        // Plugin event handling
        connect core.dispatch-event -> pluginA.handle-event;
        connect core.dispatch-event -> pluginB.handle-event;
        connect core.dispatch-event -> pluginC.handle-event;

        export core as main;
    """,
)
```

## Troubleshooting Compositions

### Common Issues

**Interface mismatch between components:**

```bash
# Check component interfaces
wasm-tools component wit component1.wasm
wasm-tools component wit component2.wasm

# Compare exported vs imported functions
```

**Connection syntax errors:**

```shell
// ❌ Wrong - missing package context
connect frontend.request -> backend.handle;

// ✅ Correct - full component instance reference
connect frontend.make-request -> backend.handle-request;
```

**WASI import satisfaction:**

```shell
// ✅ Use ... syntax to pass through WASI imports
let component = new my:component { ... };
```

<div class="demo-buttons">
  <a href="https://stackblitz.com/github/pulseengine/rules_wasm_component/tree/main/examples/wac_oci_composition" class="demo-button">
    Try WAC Composition
  </a>
  <a href="/examples/multi-language/" class="demo-button">
    Multi-Language Example
  </a>
</div>

## Performance Considerations

**Composition performance characteristics:**

<div class="perf-indicator">Near-native component communication</div>
<div class="perf-indicator">Zero-copy data sharing where possible</div>
<div class="perf-indicator">Modular loading and execution</div>

WAC compositions provide:

- **Efficient Inter-component Communication** - Direct function calls
- **Lazy Loading** - Components loaded only when needed
- **Memory Isolation** - Components can't access each other's memory
- **Type Safety** - Interface contracts enforced at composition time

WAC composition enables building sophisticated, modular WebAssembly applications while maintaining the security and
performance benefits of the Component Model.
