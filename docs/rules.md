# Rule Reference

Complete reference for all public Bazel rules in `rules_wasm_component`.

> **⚠️ Important**: This documentation provides an overview of available rules and their common attributes. For the authoritative and complete list of attributes, **always refer to the source `.bzl` files** linked in each rule section. Attribute lists here may not be exhaustive.

## Table of Contents

- [WIT Rules](#wit-rules)
- [Rust Component Rules](#rust-component-rules)
- [Go Component Rules](#go-component-rules)
- [C/C++ Component Rules](#cc-component-rules)
- [JavaScript/TypeScript Component Rules](#javascripttypescript-component-rules)
- [Composition Rules](#composition-rules)
- [WASM Utility Rules](#wasm-utility-rules)
- [Providers](#providers)

---

## WIT Rules

### wit_library

Defines a WIT (WebAssembly Interface Types) library with dependency resolution.

**Location**: `@rules_wasm_component//wit:defs.bzl`

**Attributes:**

- `srcs` (label_list, **required**): WIT source files (.wit)
- `world` (string, **required**): World name defined in WIT interfaces
- `deps` (label_list): WIT library dependencies
- `package_name` (string): WIT package name (defaults to target name)
- `interfaces` (string_list): List of interface names defined

**Outputs:**
- `WitInfo` provider with organized WIT directory structure

**Example:**

```starlark
wit_library(
    name = "my_interfaces",
    srcs = ["api.wit", "types.wit"],
    world = "my-world",
    package_name = "my:interfaces@1.0.0",
    interfaces = ["api", "types"],
)
```

---

### wit_bindgen

Generates language-specific bindings from WIT files.

**Location**: `@rules_wasm_component//wit:defs.bzl`

**Attributes:**

- `wit` (label, **required**): WIT library to generate bindings for
- `language` (string): Target language - "rust" (default), "c", "go", "python"
- `generation_mode` (string): "guest" (WASM, default) or "native-guest" (native)
- `with_mappings` (string_dict): Interface remapping (e.g., `{"wasi:io/poll": "wasi::io::poll"}`)
- `ownership` (string): Memory ownership - "owning" (default), "borrowing", "borrowing-duplicate-if-necessary"
- `additional_derives` (string_list): Extra derive attributes for Rust (e.g., `["Clone", "Debug"]`)
- `async_interfaces` (string_list): Interfaces to generate as async
- `format_code` (bool): Run formatter on generated code (default: True)
- `generate_all` (bool): Generate all interfaces not in with_mappings (default: False)
- `options` (string_list): Additional wit-bindgen CLI options

**Outputs:**
- Generated binding files (language-specific)

**Example:**

```starlark
wit_bindgen(
    name = "rust_bindings",
    wit = ":my_interfaces",
    language = "rust",
    with_mappings = {
        "wasi:io/poll": "wasi::io::poll",
    },
    additional_derives = ["Clone", "Debug", "Serialize"],
)
```

---

### symmetric_wit_bindgen

Generates symmetric bindings for dual native/WASM execution (uses cpetig's fork).

**Location**: `@rules_wasm_component//wit:defs.bzl`

**Attributes:**

- `wit` (label, **required**): WIT library
- `language` (string): Currently only "rust" supported
- `invert_direction` (bool): Invert symmetric direction (default: False)
- `options` (string_list): Additional options

**Example:**

```starlark
symmetric_wit_bindgen(
    name = "symmetric_bindings",
    wit = ":my_interfaces",
    language = "rust",
)
```

---

### wit_markdown

Generates markdown documentation from WIT files.

**Location**: `@rules_wasm_component//wit:defs.bzl`

**Attributes:**

- `wit` (label, **required**): WIT library to document

**Outputs:**
- Directory with generated `.md` and `.html` documentation

**Example:**

```starlark
wit_markdown(
    name = "api_docs",
    wit = ":my_interfaces",
)
```

---

### wit_docs_collection

Collects multiple WIT documentation outputs into unified directory with index.

**Location**: `@rules_wasm_component//wit:defs.bzl`

**Attributes:**

- `docs` (label_list, **required**): List of `wit_markdown` targets

**Outputs:**
- Consolidated documentation directory with `index.md`

**Example:**

```starlark
wit_docs_collection(
    name = "all_docs",
    docs = [
        "//frontend:api_docs",
        "//backend:service_docs",
    ],
)
```

---

## Rust Component Rules

### rust_wasm_component

Builds Rust WebAssembly components with multi-profile support.

**Location**: `@rules_wasm_component//rust:defs.bzl`

**Attributes:**

- `srcs` (label_list, **required**): Rust source files (.rs)
- `deps` (label_list): Rust dependencies
- `wit` (label): WIT library for interface definitions
- `adapter` (label): WASI adapter module (optional for wasip2)
- `crate_features` (string_list): Rust crate features (e.g., `["serde", "std"]`)
- `rustc_flags` (string_list): Additional rustc compiler flags
- `profiles` (string_list): Build profiles - "debug", "release" (default), "custom"
- `validate_wit` (bool): Enable WIT validation (default: False)
- `crate_root` (label): Custom crate root (defaults to src/lib.rs)
- `edition` (string): Rust edition (default: "2021")

**Profiles:**
- **debug**: opt-level=1, debug=true, strip=false
- **release**: opt-level=s (size), debug=false, strip=true
- **custom**: opt-level=2, debug=true, strip=false

**Outputs:**
- `<name>.wasm`: Component file (default or first profile)
- `<name>_<profile>.wasm`: Profile-specific components
- `<name>_all_profiles`: Filegroup with all variants

**Providers:**
- `WasmComponentInfo` with language="rust"

**Example:**

```starlark
rust_wasm_component(
    name = "my_service",
    srcs = ["src/lib.rs"],
    wit = ":service_wit",
    deps = [
        "@crates//:serde",
        "@crates//:serde_json",
    ],
    crate_features = ["default"],
    profiles = ["debug", "release"],
)
```

---

### rust_wasm_component_bindgen

Builds a Rust WASM component with automatic WIT binding generation.

**Location**: `@rules_wasm_component//rust:defs.bzl`

**Note**: This is a **macro** that generates bindings as a separate library and builds a component.

**Attributes:**

- `name` (string, **required**): Target name
- `srcs` (label_list, **required**): Rust source files
- `wit` (label, **required**): WIT library for binding generation
- `deps` (label_list): Additional Rust dependencies
- `crate_features` (string_list): Rust crate features
- `rustc_flags` (string_list): Additional rustc flags
- `profiles` (string_list): Build profiles (default: ["release"])
- `validate_wit` (bool): Enable WIT validation (default: False)
- `symmetric` (bool): Use symmetric bindings (default: False)
- `invert_direction` (bool): Invert symmetric direction (default: False)

**Generated Targets:**
- `{name}_bindings_host`: Host-platform bindings library
- `{name}_bindings`: WASM-platform bindings library
- `{name}`: Final WASM component

**Example:**

```starlark
rust_wasm_component_bindgen(
    name = "calculator",
    srcs = ["src/lib.rs"],
    wit = ":calculator_wit",
    profiles = ["debug", "release"],
)
```

---

### rust_wasm_component_wizer

Applies Wizer pre-initialization to Rust components for 1.35-6x startup improvement.

**Location**: `@rules_wasm_component//rust:defs.bzl`

**Attributes:**

- `component` (label, **required**): Rust component to pre-initialize
- `init_function` (string): Initialization function name (default: "wizer.initialize")

**Outputs:**
- `<name>_wizer.wasm`: Pre-initialized component

**Example:**

```starlark
rust_wasm_component_wizer(
    name = "my_service_wizer",
    component = ":my_service",
    init_function = "wizer.initialize",
)
```

---

### rust_wasm_component_test

Tests Rust WASM components using Wasmtime.

**Location**: `@rules_wasm_component//rust:defs.bzl`

**Attributes:**

- `component` (label, **required**): Component to test
- `test_data` (label_list): Additional test data files

**Example:**

```starlark
rust_wasm_component_test(
    name = "my_component_test",
    component = ":my_component",
)
```

---

### rust_wasm_binary

Builds standalone Rust WASM binaries (non-component modules).

**Location**: `@rules_wasm_component//rust:defs.bzl`

**Attributes:**

- `srcs` (label_list, **required**): Rust source files
- `deps` (label_list): Dependencies
- `crate_features` (string_list): Enabled features

**Example:**

```starlark
rust_wasm_binary(
    name = "my_module",
    srcs = ["src/main.rs"],
)
```

---

## Go Component Rules

### go_wasm_component

Builds WebAssembly components from Go source using TinyGo v0.39.0+ with native WASI Preview 2 support.

**Location**: `@rules_wasm_component//go:defs.bzl`

**Attributes:**

- `srcs` (label_list, **required**): Go source files (.go)
- `go_mod` (label): go.mod file
- `go_sum` (label): go.sum file
- `wit` (label): WIT library for interface bindings
- `world` (string): WIT world name
- `optimization` (string): "debug", "release" (default), "size"
- `validate_wit` (bool): Enable WIT validation (default: False)

**Optimization Levels:**
- **debug**: opt-level=1
- **release**: opt-level=2, no-debug, wasm-opt
- **size**: opt-level=s, no-debug, wasm-opt

**Outputs:**
- `<name>.wasm`: TinyGo-compiled component

**Providers:**
- `WasmComponentInfo` with language="go", tinygo_version="0.39.0"

**Example:**

```starlark
go_wasm_component(
    name = "calculator",
    srcs = ["main.go"],
    go_mod = ":go.mod",
    go_sum = ":go.sum",
    wit = ":calculator_wit",
    world = "calculator",
    optimization = "release",
)
```

---

## C/C++ Component Rules

### cpp_component

Builds WebAssembly components from C/C++ source using WASI SDK v27+ with native Preview2 support.

**Location**: `@rules_wasm_component//cpp:defs.bzl`

**Attributes:**

- `srcs` (label_list, **required**): C/C++ source files (.c, .cpp, .cc, .cxx)
- `wit` (label, **required**): WIT interface definition
- `hdrs` (label_list): Header files (.h, .hpp)
- `deps` (label_list): Dependencies (cc_component_library)
- `language` (string): "c" or "cpp" (default: "cpp")
- `world` (string): WIT world to target
- `package_name` (string): WIT package name (auto-generated if not provided)
- `includes` (string_list): Additional include directories
- `defines` (string_list): Preprocessor definitions
- `copts` (string_list): Additional compiler options
- `optimize` (bool): Enable optimizations -O3, -flto (default: True)
- `cxx_std` (string): C++ standard - "c++17", "c++20", "c++23"
- `enable_rtti` (bool): Enable C++ RTTI (default: False)
- `enable_exceptions` (bool): Enable C++ exceptions (default: False)
- `nostdlib` (bool): Disable standard library linking (default: False)
- `libs` (string_list): Libraries to link (e.g., `["m", "dl"]`)
- `validate_wit` (bool): Validate component (default: False)

**Outputs:**
- `<name>.wasm`: Component file
- `<name>_module.wasm`: Intermediate module
- `<name>_bindings/`: Generated WIT bindings

**Providers:**
- `WasmComponentInfo` with language="cpp"

**Example:**

```starlark
cpp_component(
    name = "calculator",
    srcs = ["calculator.cpp"],
    hdrs = ["calculator.hpp"],
    wit = ":calculator_wit",
    world = "calculator",
    cxx_std = "c++20",
    optimize = True,
    libs = ["m"],
)
```

---

### cc_component_library

Creates static libraries (.a) for use in WebAssembly components with proper dependency propagation.

**Location**: `@rules_wasm_component//cpp:defs.bzl`

**Attributes:**

- `srcs` (label_list, **required**): C/C++ source files
- `hdrs` (label_list): Public header files
- `deps` (label_list): Dependencies (other cc_component_library)
- `language` (string): "c" or "cpp" (default: "cpp")
- `includes` (string_list): Include directories
- `defines` (string_list): Preprocessor definitions
- `copts` (string_list): Compiler options
- `optimize` (bool): Enable optimizations (default: True)
- `cxx_std` (string): C++ standard
- `enable_exceptions` (bool): Enable exceptions (default: False)

**Outputs:**
- `lib<name>.a`: Static library

**Providers:**
- `CcInfo`: Compilation and linking contexts

**Example:**

```starlark
cc_component_library(
    name = "math_lib",
    srcs = ["math.cpp"],
    hdrs = ["math.hpp"],
    cxx_std = "c++17",
    optimize = True,
)
```

---

### cpp_wit_bindgen

Standalone WIT binding generation for C/C++ without building a complete component.

**Location**: `@rules_wasm_component//cpp:defs.bzl`

**Attributes:**

- `wit` (label, **required**): WIT interface definition
- `world` (string): WIT world
- `stubs_only` (bool): Generate only stub functions (default: False)
- `string_encoding` (string): "utf8", "utf16", "compact-utf16"

**Outputs:**
- `<name>_bindings/` directory with `.h` and `.c` files

**Example:**

```starlark
cpp_wit_bindgen(
    name = "api_bindings",
    wit = ":api_wit",
    world = "api",
)
```

---

## JavaScript/TypeScript Component Rules

### js_component

Builds WebAssembly components from JavaScript/TypeScript using jco (JavaScript Component Compiler).

**Location**: `@rules_wasm_component//js:defs.bzl`

**Attributes:**

- `srcs` (label_list, **required**): JavaScript/TypeScript files (.js, .ts, .mjs)
- `wit` (label, **required**): WIT interface definition
- `deps` (label_list): JavaScript library dependencies
- `package_json` (label): package.json file (auto-generated if not provided)
- `entry_point` (string): Main entry point (default: "index.js")
- `world` (string): WIT world to target
- `package_name` (string): WIT package name (auto-generated if not provided)
- `npm_dependencies` (string_dict): NPM dependencies (e.g., `{"express": "^4.18.0"}`)
- `optimize` (bool): Enable optimizations (default: True)
- `minify` (bool): Minify generated code (default: False)
- `disable_feature_detection` (bool): Disable WASM feature detection (default: False)
- `compat` (bool): Enable compatibility mode (default: False)

**Outputs:**
- `<name>.wasm`: Component file

**Providers:**
- `WasmComponentInfo` with language="javascript"

**Example:**

```starlark
js_component(
    name = "hello",
    srcs = ["index.js"],
    wit = ":hello_wit",
    world = "hello",
    npm_dependencies = {
        "lodash": "^4.17.21",
    },
)
```

---

### jco_transpile

Transpiles WebAssembly components back to JavaScript bindings.

**Location**: `@rules_wasm_component//js:defs.bzl`

**Attributes:**

- `component` (label, **required**): WebAssembly component to transpile
- `name_override` (string): Override component name
- `no_typescript` (bool): Disable TypeScript definitions (default: False)
- `instantiation` (string): "async" or "sync"
- `map` (string_list): Interface mappings (e.g., `["wasi:http/types@0.2.0=@wasi/http#types"]`)
- `world_name` (string): Generated world interface name

**Outputs:**
- `<name>_transpiled/` directory with JavaScript and TypeScript files

**Example:**

```starlark
jco_transpile(
    name = "component_bindings",
    component = ":my_component",
)
```

---

## Composition Rules

### wac_compose

Composes multiple WebAssembly components into a unified component using the official WAC tool.

**Location**: `@rules_wasm_component//wac:defs.bzl`

**Attributes:**

- `components` (label_keyed_string_dict, **required**): Components to compose - label keys with WIT package names as values
- `composition` (string): Inline WAC composition code
- `composition_file` (label): External `.wac` file
- `profile` (string): Default build profile - "debug", "release" (default), "custom"
- `component_profiles` (string_dict): Per-component profile overrides - component_name → profile
- `use_symlinks` (bool): Use symlinks vs copying (default: True)

**Outputs:**
- `<name>.wasm`: Composed component

**Providers:**
- `WacCompositionInfo`

**Example:**

```starlark
wac_compose(
    name = "full_system",
    components = {
        ":frontend": "app:frontend",
        ":backend": "app:backend",
    },
    profile = "release",
    component_profiles = {
        ":frontend": "debug",  # Debug frontend for development
    },
    composition = '''
        let frontend = new app:frontend { ... };
        let backend = new app:backend { ... };

        connect frontend.request -> backend.handler;

        export frontend as main;
    ''',
)
```

---

### wac_remote_compose

Extends `wac_compose` to support fetching remote components from registries using wkg.

**Location**: `@rules_wasm_component//wac:defs.bzl`

**Attributes:**

- `local_components` (label_keyed_string_dict): Local components
- `remote_components` (string_dict): Remote specs - "name": "package@version" or "registry/package@version"
- `composition` (string): Inline WAC code
- `composition_file` (label): External `.wac` file
- `profile` (string): Build profile (default: "release")
- `use_symlinks` (bool): Symlink vs copy (default: True)

**Example:**

```starlark
wac_remote_compose(
    name = "distributed_system",
    local_components = {
        ":frontend": "app:frontend",
    },
    remote_components = {
        "backend": "ghcr.io/org/backend@1.2.0",
        "auth": "wasi:auth@0.1.0",
    },
    composition = '''
        let frontend = new app:frontend { ... };
        let backend = new backend:component { ... };

        connect frontend.api_request -> backend.handler;

        export frontend as main;
    ''',
)
```

---

### wac_plug

Automatically connects plug components (exports) into socket components (imports) using WAC's plug command.

**Location**: `@rules_wasm_component//wac:defs.bzl`

**Attributes:**

- `socket` (label, **required**): Socket component that imports functions
- `plugs` (label_list, **required**): Plug components that export functions

**Example:**

```starlark
wac_plug(
    name = "plugged_system",
    socket = ":app_socket",
    plugs = [":data_processor", ":logger"],
)
```

---

### wac_bundle

Bundles multiple WASI components together without composition.

**Location**: `@rules_wasm_component//wac:defs.bzl`

**Attributes:**

- `components` (label_keyed_string_dict, **required**): Components to bundle

**Example:**

```starlark
wac_bundle(
    name = "service_bundle",
    components = {
        ":service_a": "service-a",
        ":service_b": "service-b",
    },
)
```

---

## WASM Utility Rules

### wasm_validate

Validates WebAssembly files and optionally verifies cryptographic signatures.

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**Attributes:**

- Either `wasm_file` or `component` **required**
- `wasm_file` (label): Direct WASM file
- `component` (label): WasmComponent target
- `verify_signature` (bool): Enable signature verification (default: False)
- `public_key` (label): Public key file
- `signature_file` (label): Detached signature
- `signing_keys` (label): Key pair provider
- `github_account` (string): GitHub account for public key retrieval

**Outputs:**
- `<name>_validation.log`: Validation report

**Example:**

```starlark
wasm_validate(
    name = "validate_component",
    component = ":my_component",
    verify_signature = True,
    public_key = ":public_key.pem",
)
```

---

### wasm_component_new

Creates new WebAssembly components from modules using wasm-tools component new.

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**Attributes:**

- `module` (label, **required**): WASM module to convert
- `adapt` (label_list): Adapter modules

**Example:**

```starlark
wasm_component_new(
    name = "my_component",
    module = ":my_module.wasm",
)
```

---

### wasm_component_wizer

Pre-initializes WebAssembly components with Wizer for 1.35-6x startup improvement.

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**Attributes:**

- `component` (label, **required**): Component to pre-initialize
- `init_function_name` (string): Initialization function (default: "wizer.initialize")
- `init_script` (label): Optional initialization data

**Outputs:**
- `<name>_wizer.wasm`: Pre-initialized component

**Example:**

```starlark
wasm_component_wizer(
    name = "my_service_wizer",
    component = ":my_service",
    init_function_name = "wizer.initialize",
)
```

---

### wizer_chain

Convenience rule that chains Wizer pre-initialization after component build.

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**Attributes:**

- `component` (label, **required**): Component to pre-initialize
- `init_function_name` (string): Initialization function (default: "wizer_initialize")

**Example:**

```starlark
wizer_chain(
    name = "initialized_component",
    component = ":my_component",
)
```

---

### wasm_precompile

AOT (Ahead-of-Time) compiles WASM to native machine code using Wasmtime for faster startup.

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**Attributes:**

- Either `wasm_file` or `component` **required**
- `wasm_file` (label): Direct WASM file
- `component` (label): WasmComponent target
- `optimization_level` (string): "0", "1", "2", "s"
- `debug_info` (bool): Include DWARF debug info (default: False)
- `target_triple` (string): Target architecture for cross-compilation

**Outputs:**
- `<name>.cwasm`: Precompiled component (native machine code)

**Providers:**
- `WasmPrecompiledInfo`

**Example:**

```starlark
wasm_precompile(
    name = "my_component_aot",
    component = ":my_component",
    optimization_level = "2",
)
```

---

### wasm_run

Executes WebAssembly components using Wasmtime runtime.

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**Attributes:**

- One of `component`, `wasm_file`, or `cwasm_file` **required**
- `component` (label): WasmComponent target
- `wasm_file` (label): Direct .wasm file
- `cwasm_file` (label): Precompiled .cwasm file
- `prefer_aot` (bool): Use AOT if available (default: True)
- `allow_wasi_filesystem` (bool): Allow WASI filesystem (default: True)
- `allow_wasi_net` (bool): Allow WASI network (default: False)
- `module_args` (string_list): Arguments to pass to module

**Outputs:**
- `<name>_output.log`: Execution output

**Example:**

```starlark
wasm_run(
    name = "run_component",
    component = ":my_component",
    module_args = ["--verbose"],
)
```

---

### wasm_test

Test rule for WASM components (similar to wasm_run but for testing).

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**Attributes:**

- `component` (label, **required**): Component to test

**Example:**

```starlark
wasm_test(
    name = "component_test",
    component = ":my_component",
)
```

---

### wasm_sign / wasm_verify / wasm_keygen

Cryptographic signing and verification of WASM components using wasmsign2.

**Location**: `@rules_wasm_component//wasm:defs.bzl`

**wasm_sign Attributes:**
- `component` (label, **required**): Component to sign
- `signing_keys` (label, **required**): Key pair provider

**wasm_verify Attributes:**
- `component` (label, **required**): Component to verify
- `public_key` (label, **required**): Public key

**wasm_keygen Attributes:**
- `key_type` (string, **required**): Key algorithm (e.g., "ed25519")

**Example:**

```starlark
wasm_keygen(
    name = "signing_keys",
    key_type = "ed25519",
)

wasm_sign(
    name = "signed_component",
    component = ":my_component",
    signing_keys = ":signing_keys",
)

wasm_verify(
    name = "verify_component",
    component = ":signed_component",
    public_key = ":signing_keys_public",
)
```

---

## Providers

### WitInfo

Information about a WIT library.

**Fields:**

- `wit_files` (depset): WIT source files
- `wit_deps` (depset): WIT dependencies
- `package_name` (string): WIT package name (e.g., "app:interfaces@1.0.0")
- `world_name` (string): Optional world name
- `interface_names` (list): List of interface names

**Provided by:** `wit_library`

**Consumed by:** `wit_bindgen`, component build rules, composition rules

---

### WasmComponentInfo

Information about a WebAssembly component.

**Fields:**

- `wasm_file` (File): The compiled WASM component file
- `wit_info` (WitInfo): WIT library information (optional)
- `component_type` (string): "module" or "component"
- `imports` (list): List of imported interfaces
- `exports` (list): List of exported interfaces
- `metadata` (dict): Component metadata
  - `name` (string): Component name
  - `language` (string): Source language ("rust", "go", "cpp", "javascript")
  - `target` (string): Target triple (e.g., "wasm32-wasip2")
  - Additional language-specific fields
- `profile` (string): Build profile ("debug", "release", "custom")
- `profile_variants` (dict): Profile name → wasm_file for multi-profile builds

**Provided by:** All component build rules

**Consumed by:** Composition rules, utility rules

---

### WacCompositionInfo

Information about a WAC composition.

**Fields:**

- `composed_wasm` (File): The composed WASM file (or None for bundles)
- `components` (dict): Component name → WasmComponentInfo
- `composition_wit` (File): WIT file describing composition
- `instantiations` (list): List of component instantiations
- `connections` (list): List of inter-component connections

**Provided by:** `wac_compose`, `wac_remote_compose`, `wac_bundle`

**Consumed by:** Deployment rules

---

### WasmPrecompiledInfo

Information about AOT-compiled components.

**Fields:**

- `cwasm_file` (File): Precompiled .cwasm file
- `source_wasm` (File): Original WASM source
- `wasmtime_version` (string): Wasmtime version used
- `target_arch` (string): Target architecture
- `optimization_level` (string): Optimization level
- `compilation_flags` (list): Compilation flags
- `compatibility_hash` (string): Cache validation hash

**Provided by:** `wasm_precompile`

**Consumed by:** `wasm_run`, deployment tools

---

### WasmValidationInfo

Information about validation results.

**Fields:**

- Validation results including errors and warnings

**Provided by:** `wasm_validate`

---

### WasmKeyInfo

Key pair information for signing.

**Fields:**

- Public and private key information

**Provided by:** `wasm_keygen`

**Consumed by:** `wasm_sign`, `wasm_verify`

---

## Version Information

**See [MODULE.bazel](../MODULE.bazel) for current toolchain versions** - the single source of truth.

Version numbers change with each release. Always check MODULE.bazel for the exact versions used in your build.

---

## See Also

- [Toolchain Configuration](toolchain_configuration.md)
- [Multi-Profile Builds](multi_profile.md)
- [Migration Guide](migration.md)
- [Examples](/examples/)
