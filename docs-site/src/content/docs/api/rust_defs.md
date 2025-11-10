---
title: Rust Components API
description: Build WebAssembly components from Rust code using rust_wasm_component
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rust WebAssembly Component Model rules

State-of-the-art Rust support for WebAssembly Component Model using:
- Rust 1.88.0+ with native WASI Preview 2 support
- Bazel-native implementation following modern patterns
- Cross-platform compatibility (Windows/macOS/Linux)
- Advanced optimization with Wizer pre-initialization
- Clippy integration for code quality
- Comprehensive test framework support
- Component composition and macro system

Example usage:

    rust_wasm_component(
        name = "my_service",
        srcs = ["lib.rs", "service.rs"],
        wit = "//wit:service-interface",
        world = "service",
        optimization = "release",
        enable_wizer = True,
    )

    rust_wasm_component_test(
        name = "my_service_test",
        component = ":my_service",
        test_data = ["test_input.json"],
    )

<a id="rust_wasm_component_test"></a>

## rust_wasm_component_test

<pre>
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_test")

rust_wasm_component_test(<a href="#rust_wasm_component_test-name">name</a>, <a href="#rust_wasm_component_test-component">component</a>)
</pre>

Test rule for Rust WASM components.

This rule validates WASM components and can run basic tests.

Example:
    rust_wasm_component_test(
        name = "my_component_test",
        component = ":my_component",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_wasm_component_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="rust_wasm_component_test-component"></a>component |  WASM component to test   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="rust_clippy_all"></a>

## rust_clippy_all

<pre>
load("@rules_wasm_component//rust:defs.bzl", "rust_clippy_all")

rust_clippy_all(<a href="#rust_clippy_all-name">name</a>, <a href="#rust_clippy_all-targets">targets</a>, <a href="#rust_clippy_all-kwargs">**kwargs</a>)
</pre>

Run clippy on multiple Rust targets.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_clippy_all-name"></a>name |  Name of the test suite   |  none |
| <a id="rust_clippy_all-targets"></a>targets |  List of Rust targets to run clippy on   |  none |
| <a id="rust_clippy_all-kwargs"></a>kwargs |  Additional arguments passed to test_suite   |  none |


<a id="rust_wasm_binary"></a>

## rust_wasm_binary

<pre>
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_binary")

rust_wasm_binary(<a href="#rust_wasm_binary-name">name</a>, <a href="#rust_wasm_binary-srcs">srcs</a>, <a href="#rust_wasm_binary-deps">deps</a>, <a href="#rust_wasm_binary-crate_features">crate_features</a>, <a href="#rust_wasm_binary-rustc_flags">rustc_flags</a>, <a href="#rust_wasm_binary-visibility">visibility</a>, <a href="#rust_wasm_binary-edition">edition</a>, <a href="#rust_wasm_binary-kwargs">**kwargs</a>)
</pre>

Builds a Rust WebAssembly CLI binary component.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_wasm_binary-name"></a>name |  Target name   |  none |
| <a id="rust_wasm_binary-srcs"></a>srcs |  Rust source files (must include main.rs)   |  none |
| <a id="rust_wasm_binary-deps"></a>deps |  Rust dependencies   |  `[]` |
| <a id="rust_wasm_binary-crate_features"></a>crate_features |  Rust crate features to enable   |  `[]` |
| <a id="rust_wasm_binary-rustc_flags"></a>rustc_flags |  Additional rustc flags   |  `[]` |
| <a id="rust_wasm_binary-visibility"></a>visibility |  Target visibility   |  `None` |
| <a id="rust_wasm_binary-edition"></a>edition |  Rust edition (default: "2021")   |  `"2021"` |
| <a id="rust_wasm_binary-kwargs"></a>kwargs |  Additional arguments passed to rust_binary   |  none |


<a id="rust_wasm_component"></a>

## rust_wasm_component

<pre>
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component")

rust_wasm_component(<a href="#rust_wasm_component-name">name</a>, <a href="#rust_wasm_component-srcs">srcs</a>, <a href="#rust_wasm_component-deps">deps</a>, <a href="#rust_wasm_component-wit">wit</a>, <a href="#rust_wasm_component-adapter">adapter</a>, <a href="#rust_wasm_component-crate_features">crate_features</a>, <a href="#rust_wasm_component-rustc_flags">rustc_flags</a>, <a href="#rust_wasm_component-profiles">profiles</a>,
                    <a href="#rust_wasm_component-validate_wit">validate_wit</a>, <a href="#rust_wasm_component-visibility">visibility</a>, <a href="#rust_wasm_component-crate_root">crate_root</a>, <a href="#rust_wasm_component-edition">edition</a>, <a href="#rust_wasm_component-kwargs">**kwargs</a>)
</pre>

Builds a Rust WebAssembly component with multi-profile support.

This macro is the primary entry point for creating Rust-based WASM components.
It handles the complete build pipeline including Rust compilation, WASM transition,
component conversion, and optional WIT validation. Supports building multiple
profiles (debug, release, custom) in a single invocation.

Generated targets: <name> (main), <name>_<profile> (profile-specific),
<name>_all_profiles (filegroup), and intermediate libraries.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_wasm_component-name"></a>name |  Target name for the component (default profile will use this name).   |  none |
| <a id="rust_wasm_component-srcs"></a>srcs |  Rust source files (.rs) to compile.   |  none |
| <a id="rust_wasm_component-deps"></a>deps |  Rust dependencies including crate dependencies and wit_bindgen outputs.   |  `[]` |
| <a id="rust_wasm_component-wit"></a>wit |  WIT library target for interface definitions (optional).   |  `None` |
| <a id="rust_wasm_component-adapter"></a>adapter |  Optional WASI adapter module (typically not needed for wasip2).   |  `None` |
| <a id="rust_wasm_component-crate_features"></a>crate_features |  Rust crate features to enable (e.g., ["serde", "std"]).   |  `[]` |
| <a id="rust_wasm_component-rustc_flags"></a>rustc_flags |  Additional rustc compiler flags.   |  `[]` |
| <a id="rust_wasm_component-profiles"></a>profiles |  List of build profiles: "debug", "release", or "custom".   |  `["release"]` |
| <a id="rust_wasm_component-validate_wit"></a>validate_wit |  Whether to validate component against WIT specification.   |  `False` |
| <a id="rust_wasm_component-visibility"></a>visibility |  Target visibility (standard Bazel visibility).   |  `None` |
| <a id="rust_wasm_component-crate_root"></a>crate_root |  Optional custom crate root file (defaults to src/lib.rs).   |  `None` |
| <a id="rust_wasm_component-edition"></a>edition |  Rust edition to use (default: "2021").   |  `"2021"` |
| <a id="rust_wasm_component-kwargs"></a>kwargs |  Additional arguments forwarded to rust_shared_library.   |  none |


<a id="rust_wasm_component_bindgen"></a>

## rust_wasm_component_bindgen

<pre>
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_bindgen")

rust_wasm_component_bindgen(<a href="#rust_wasm_component_bindgen-name">name</a>, <a href="#rust_wasm_component_bindgen-srcs">srcs</a>, <a href="#rust_wasm_component_bindgen-wit">wit</a>, <a href="#rust_wasm_component_bindgen-deps">deps</a>, <a href="#rust_wasm_component_bindgen-crate_features">crate_features</a>, <a href="#rust_wasm_component_bindgen-rustc_flags">rustc_flags</a>, <a href="#rust_wasm_component_bindgen-profiles">profiles</a>,
                            <a href="#rust_wasm_component_bindgen-validate_wit">validate_wit</a>, <a href="#rust_wasm_component_bindgen-visibility">visibility</a>, <a href="#rust_wasm_component_bindgen-symmetric">symmetric</a>, <a href="#rust_wasm_component_bindgen-invert_direction">invert_direction</a>, <a href="#rust_wasm_component_bindgen-kwargs">**kwargs</a>)
</pre>

Builds a Rust WebAssembly component with automatic WIT binding generation.

Generates WIT bindings as a separate library and builds a WASM component that depends on
them, providing clean separation between generated bindings and user implementation code.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_wasm_component_bindgen-name"></a>name |  Target name   |  none |
| <a id="rust_wasm_component_bindgen-srcs"></a>srcs |  Rust source files   |  none |
| <a id="rust_wasm_component_bindgen-wit"></a>wit |  WIT library target for binding generation   |  none |
| <a id="rust_wasm_component_bindgen-deps"></a>deps |  Additional Rust dependencies   |  `[]` |
| <a id="rust_wasm_component_bindgen-crate_features"></a>crate_features |  Rust crate features to enable   |  `[]` |
| <a id="rust_wasm_component_bindgen-rustc_flags"></a>rustc_flags |  Additional rustc flags   |  `[]` |
| <a id="rust_wasm_component_bindgen-profiles"></a>profiles |  List of build profiles (e.g. ["debug", "release"])   |  `["release"]` |
| <a id="rust_wasm_component_bindgen-validate_wit"></a>validate_wit |  <p align="center"> - </p>   |  `False` |
| <a id="rust_wasm_component_bindgen-visibility"></a>visibility |  Target visibility   |  `None` |
| <a id="rust_wasm_component_bindgen-symmetric"></a>symmetric |  Enable symmetric mode for same source code to run natively and as WASM (requires cpetig's fork)   |  `False` |
| <a id="rust_wasm_component_bindgen-invert_direction"></a>invert_direction |  Invert direction for symmetric interfaces (only used with symmetric=True)   |  `False` |
| <a id="rust_wasm_component_bindgen-kwargs"></a>kwargs |  Additional arguments passed to rust_wasm_component   |  none |


<a id="rust_wasm_component_clippy"></a>

## rust_wasm_component_clippy

<pre>
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_clippy")

rust_wasm_component_clippy(<a href="#rust_wasm_component_clippy-name">name</a>, <a href="#rust_wasm_component_clippy-target">target</a>, <a href="#rust_wasm_component_clippy-profile">profile</a>, <a href="#rust_wasm_component_clippy-kwargs">**kwargs</a>)
</pre>

Run clippy on a rust_wasm_component target.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_wasm_component_clippy-name"></a>name |  Name of the clippy test target   |  none |
| <a id="rust_wasm_component_clippy-target"></a>target |  The rust_wasm_component target to run clippy on   |  none |
| <a id="rust_wasm_component_clippy-profile"></a>profile |  The profile to run clippy on (default: "release")   |  `"release"` |
| <a id="rust_wasm_component_clippy-kwargs"></a>kwargs |  Additional arguments passed to rust_clippy   |  none |


<a id="rust_wasm_component_wizer"></a>

## rust_wasm_component_wizer

<pre>
load("@rules_wasm_component//rust:defs.bzl", "rust_wasm_component_wizer")

rust_wasm_component_wizer(<a href="#rust_wasm_component_wizer-name">name</a>, <a href="#rust_wasm_component_wizer-srcs">srcs</a>, <a href="#rust_wasm_component_wizer-deps">deps</a>, <a href="#rust_wasm_component_wizer-wit">wit</a>, <a href="#rust_wasm_component_wizer-adapter">adapter</a>, <a href="#rust_wasm_component_wizer-crate_features">crate_features</a>, <a href="#rust_wasm_component_wizer-rustc_flags">rustc_flags</a>, <a href="#rust_wasm_component_wizer-profiles">profiles</a>,
                          <a href="#rust_wasm_component_wizer-visibility">visibility</a>, <a href="#rust_wasm_component_wizer-crate_root">crate_root</a>, <a href="#rust_wasm_component_wizer-edition">edition</a>, <a href="#rust_wasm_component_wizer-init_function_name">init_function_name</a>, <a href="#rust_wasm_component_wizer-kwargs">**kwargs</a>)
</pre>

Builds a Rust WebAssembly component with Wizer pre-initialization.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="rust_wasm_component_wizer-name"></a>name |  Target name   |  none |
| <a id="rust_wasm_component_wizer-srcs"></a>srcs |  Rust source files   |  none |
| <a id="rust_wasm_component_wizer-deps"></a>deps |  Rust dependencies   |  `[]` |
| <a id="rust_wasm_component_wizer-wit"></a>wit |  WIT library for binding generation   |  `None` |
| <a id="rust_wasm_component_wizer-adapter"></a>adapter |  Optional WASI adapter   |  `None` |
| <a id="rust_wasm_component_wizer-crate_features"></a>crate_features |  Rust crate features to enable   |  `[]` |
| <a id="rust_wasm_component_wizer-rustc_flags"></a>rustc_flags |  Additional rustc flags   |  `[]` |
| <a id="rust_wasm_component_wizer-profiles"></a>profiles |  List of build profiles to create ["debug", "release", "custom"]   |  `["release"]` |
| <a id="rust_wasm_component_wizer-visibility"></a>visibility |  Target visibility   |  `None` |
| <a id="rust_wasm_component_wizer-crate_root"></a>crate_root |  Rust crate root file   |  `None` |
| <a id="rust_wasm_component_wizer-edition"></a>edition |  Rust edition (default: "2021")   |  `"2021"` |
| <a id="rust_wasm_component_wizer-init_function_name"></a>init_function_name |  Wizer initialization function name (default: "wizer.initialize")   |  `"wizer.initialize"` |
| <a id="rust_wasm_component_wizer-kwargs"></a>kwargs |  Additional arguments passed to rust_library   |  none |


