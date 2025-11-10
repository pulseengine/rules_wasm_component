---
title: Go Components API
description: Build WebAssembly components from Go code using TinyGo and wit-bindgen-go
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

TinyGo WASI Preview 2 WebAssembly component rules

State-of-the-art Go support for WebAssembly Component Model using:
- TinyGo v0.38.0+ with native WASI Preview 2 support
- Bazel-native implementation (zero shell scripts) ✅ ACHIEVED
- Cross-platform compatibility (Windows/macOS/Linux)
- Proper toolchain integration with hermetic builds
- Direct executable invocation with environment variables
- Universal File Operations Component for workspace preparation

Example usage:

    go_wasm_component(
        name = "my_component",
        srcs = ["main.go"],
        go_mod = "go.mod",
        wit = "//wit:interfaces",
        world = "my-world",
    )

<a id="go_wasm_component"></a>

## go_wasm_component

<pre>
load("@rules_wasm_component//go:defs.bzl", "go_wasm_component")

go_wasm_component(<a href="#go_wasm_component-name">name</a>, <a href="#go_wasm_component-srcs">srcs</a>, <a href="#go_wasm_component-adapter">adapter</a>, <a href="#go_wasm_component-go_mod">go_mod</a>, <a href="#go_wasm_component-go_sum">go_sum</a>, <a href="#go_wasm_component-optimization">optimization</a>, <a href="#go_wasm_component-validate_wit">validate_wit</a>, <a href="#go_wasm_component-wit">wit</a>, <a href="#go_wasm_component-world">world</a>)
</pre>

Builds a WebAssembly component from Go source using TinyGo + WASI Preview 2.

This rule provides state-of-the-art Go support for WebAssembly Component Model:
- Uses TinyGo v0.38.0+ with native WASI Preview 2 support
- Cross-platform Bazel implementation (Windows/macOS/Linux)
- Hermetic builds with proper toolchain integration
- WIT binding generation support
- Zero shell script dependencies

Example:
    go_wasm_component(
        name = "http_downloader",
        srcs = ["main.go", "client.go"],
        go_mod = "go.mod",
        wit = "//wit:http_interfaces",
        world = "http-client",
        optimization = "release",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="go_wasm_component-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="go_wasm_component-srcs"></a>srcs |  Go source files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="go_wasm_component-adapter"></a>adapter |  WASI adapter for component transformation   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="go_wasm_component-go_mod"></a>go_mod |  Go module file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="go_wasm_component-go_sum"></a>go_sum |  Go module checksum file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="go_wasm_component-optimization"></a>optimization |  Optimization level: 'debug', 'release', or 'size'   | String | optional |  `"release"`  |
| <a id="go_wasm_component-validate_wit"></a>validate_wit |  Validate that the component exports match the WIT specification   | Boolean | optional |  `False`  |
| <a id="go_wasm_component-wit"></a>wit |  WIT library for binding generation   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="go_wasm_component-world"></a>world |  WIT world name to implement   | String | optional |  `""`  |


<a id="go_wit_bindgen"></a>

## go_wit_bindgen

<pre>
load("@rules_wasm_component//go:defs.bzl", "go_wit_bindgen")

go_wit_bindgen(<a href="#go_wit_bindgen-kwargs">**kwargs</a>)
</pre>

Generate Go bindings from WIT files - integrated with go_wasm_component.

This function exists for backward compatibility with existing examples.
WIT binding generation is now handled automatically by go_wasm_component rule.

For new code, use go_wasm_component directly with wit and world attributes.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="go_wit_bindgen-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


