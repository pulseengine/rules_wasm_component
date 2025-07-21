# Advanced Examples

Complex scenarios including component composition and multi-language integration.

## Example 1: WAC Component Composition

**Purpose**: Compose multiple WASM components into a single application

```starlark
# BUILD.bazel
load("@rules_wasm_component//wit:defs.bzl", "wit_library")
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")

# Define interfaces for both components
wit_library(
    name = "database_interfaces",
    package_name = "app:database@1.0.0",
    srcs = ["database.wit"],
)

wit_library(
    name = "http_interfaces", 
    package_name = "app:http@1.0.0",
    srcs = ["http.wit"],
    deps = [":database_interfaces"],
)

# Build individual components
rust_wasm_component_bindgen(
    name = "database_component",
    srcs = ["src/database.rs"],
    wit = ":database_interfaces",
)

rust_wasm_component_bindgen(
    name = "http_component",
    srcs = ["src/http.rs"],
    wit = ":http_interfaces",
)

# Compose into final application
wac_compose(
    name = "web_app",
    components = {
        ":database_component": "db",
        ":http_component": "server",
    },
    composition = '''
        let database = new db {};
        let server = new server { db: database };
        export server;
    ''',
)
```

```wit
// database.wit
package app:database@1.0.0;

interface storage {
    get: func(key: string) -> option<string>;
    set: func(key: string, value: string);
}

world database {
    export storage;
}
```

```wit
// http.wit
package app:http@1.0.0;

use app:database/storage@1.0.0;

interface server {
    handle-request: func(path: string) -> string;
}

world http-server {
    import storage;
    export server;
}
```

## Example 2: Custom Rule Integration

**Purpose**: Create custom rules that work with WIT libraries

```starlark
# custom_rules.bzl
load("//providers:providers.bzl", "WitInfo")

def _wit_validator_impl(ctx):
    """Custom rule that validates WIT files"""
    wit_info = ctx.attr.wit[WitInfo]
    
    # Access WIT metadata
    package_name = wit_info.package_name
    wit_files = wit_info.wit_files.to_list()
    
    # Run validation
    output = ctx.actions.declare_file(ctx.label.name + "_validation.txt")
    ctx.actions.run(
        executable = ctx.executable._validator_tool,
        arguments = [package_name, output.path] + [f.path for f in wit_files],
        inputs = wit_info.wit_files,
        outputs = [output],
        mnemonic = "ValidateWit",
    )
    
    return [DefaultInfo(files = depset([output]))]

wit_validator = rule(
    implementation = _wit_validator_impl,
    attrs = {
        "wit": attr.label(providers = [WitInfo], mandatory = True),
        "_validator_tool": attr.label(
            default = "//tools:wit_validator",
            executable = True,
            cfg = "exec",
        ),
    },
)
```

## Example 3: Multi-Language Component System

**Purpose**: Prepare for future multi-language support

```starlark
# BUILD.bazel - Future capability demonstration
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

# Shared WIT interfaces
wit_library(
    name = "shared_interfaces",
    package_name = "system:shared@1.0.0",
    srcs = ["shared.wit"],
    visibility = ["//visibility:public"],
)

# Rust implementation
rust_wasm_component_bindgen(
    name = "rust_implementation",
    srcs = ["src/rust_impl.rs"],
    wit = ":shared_interfaces",
)

# Future: Go implementation
# go_wasm_component_bindgen(
#     name = "go_implementation", 
#     srcs = ["go_impl.go"],
#     wit = ":shared_interfaces",
# )

# Future: Python implementation  
# python_wasm_component_bindgen(
#     name = "python_implementation",
#     srcs = ["python_impl.py"], 
#     wit = ":shared_interfaces",
# )
```

## Example 4: Large-Scale Dependency Management

**Purpose**: Manage complex dependency graphs

```starlark
# workspace/BUILD.bazel
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

# Core utilities used by many components
wit_library(
    name = "core_utilities",
    package_name = "workspace:core@1.0.0",
    srcs = ["core.wit"],
    visibility = ["//visibility:public"],
)

# Database abstraction layer
wit_library(
    name = "database_layer",
    package_name = "workspace:database@1.0.0", 
    srcs = ["database.wit"],
    deps = [":core_utilities"],
    visibility = ["//visibility:public"],
)

# HTTP service layer
wit_library(
    name = "http_layer",
    package_name = "workspace:http@1.0.0",
    srcs = ["http.wit"], 
    deps = [":core_utilities", ":database_layer"],
    visibility = ["//visibility:public"],
)

# Business logic components depend on service layers
wit_library(
    name = "business_logic",
    package_name = "workspace:business@1.0.0",
    srcs = ["business.wit"],
    deps = [":http_layer", ":database_layer"],
)
```

This creates a dependency hierarchy:
```
business_logic
├── http_layer
│   ├── database_layer
│   │   └── core_utilities
│   └── core_utilities
└── database_layer
    └── core_utilities
```