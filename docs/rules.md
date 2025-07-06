# Rule Reference

## WIT Rules

### wit_library

Defines a WIT (WebAssembly Interface Types) library.

**Attributes:**
- `srcs` (label_list): WIT source files (.wit)
- `deps` (label_list): WIT dependencies
- `package_name` (string): WIT package name (defaults to target name)
- `world` (string): Optional world name to export
- `interfaces` (string_list): List of interface names

**Example:**
```starlark
wit_library(
    name = "my_interfaces",
    srcs = ["api.wit", "types.wit"],
    package_name = "my:interfaces",
    interfaces = ["api", "types"],
)
```

### wit_bindgen

Generates language bindings from WIT files.

**Attributes:**
- `wit` (label): WIT library to generate bindings for
- `language` (string): Target language ("rust", "c", "go", "python")
- `options` (string_list): Additional options for wit-bindgen

**Example:**
```starlark
wit_bindgen(
    name = "rust_bindings",
    wit = ":my_interfaces",
    language = "rust",
)
```

## Rust Rules

### rust_wasm_component

Builds a Rust WebAssembly component.

**Attributes:**
- `srcs` (label_list): Rust source files
- `deps` (label_list): Rust dependencies
- `wit_bindgen` (label): WIT library for binding generation
- `adapter` (label): Optional WASI adapter
- `crate_features` (string_list): Rust crate features
- `rustc_flags` (string_list): Additional rustc flags

**Example:**
```starlark
rust_wasm_component(
    name = "my_component",
    srcs = ["src/lib.rs"],
    wit_bindgen = ":my_interfaces",
    deps = ["@crates//:serde"],
)
```

### rust_wasm_component_test

Tests a Rust WASM component.

**Attributes:**
- `component` (label): WASM component to test

**Example:**
```starlark
rust_wasm_component_test(
    name = "my_component_test",
    component = ":my_component",
)
```

## Composition Rules

### wac_compose

Composes multiple WebAssembly components using WAC.

**Attributes:**
- `components` (label_keyed_string_dict): Components to compose
- `composition` (string): Inline WAC composition code
- `composition_file` (label): External WAC composition file

**Example:**
```starlark
wac_compose(
    name = "my_system",
    components = {
        "frontend": ":frontend_component",
        "backend": ":backend_component",
    },
    composition = '''
        let frontend = new frontend:component { ... };
        let backend = new backend:component { ... };
        
        connect frontend.request -> backend.handler;
        
        export frontend as main;
    ''',
)
```

## Providers

### WitInfo

Information about a WIT library.

**Fields:**
- `wit_files`: Depset of WIT source files
- `wit_deps`: Depset of WIT dependencies
- `package_name`: WIT package name
- `world_name`: Optional world name
- `interface_names`: List of interface names

### WasmComponentInfo

Information about a WebAssembly component.

**Fields:**
- `wasm_file`: The compiled WASM component file
- `wit_info`: WitInfo provider from the component's interfaces
- `component_type`: Type of component (module or component)
- `imports`: List of imported interfaces
- `exports`: List of exported interfaces
- `metadata`: Component metadata dict

### WacCompositionInfo

Information about a WAC composition.

**Fields:**
- `composed_wasm`: The composed WASM file
- `components`: Dict of component name to WasmComponentInfo
- `composition_wit`: WIT file describing the composition
- `instantiations`: List of component instantiations
- `connections`: List of inter-component connections