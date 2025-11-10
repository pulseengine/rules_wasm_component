---
title: WIT Interface API
description: Define and document WebAssembly Component Model interfaces using WIT
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for WIT rules

<a id="symmetric_wit_bindgen"></a>

## symmetric_wit_bindgen

<pre>
load("@rules_wasm_component//wit:defs.bzl", "symmetric_wit_bindgen")

symmetric_wit_bindgen(<a href="#symmetric_wit_bindgen-name">name</a>, <a href="#symmetric_wit_bindgen-invert_direction">invert_direction</a>, <a href="#symmetric_wit_bindgen-language">language</a>, <a href="#symmetric_wit_bindgen-options">options</a>, <a href="#symmetric_wit_bindgen-wit">wit</a>)
</pre>

Generates symmetric language bindings from WIT files using cpetig's fork.

This rule uses the symmetric wit-bindgen fork to generate language-specific bindings
that can work for both native and WASM execution from the same source code.

Example:
    symmetric_wit_bindgen(
        name = "my_symmetric_bindings",
        wit = ":my_interfaces",
        language = "rust",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="symmetric_wit_bindgen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="symmetric_wit_bindgen-invert_direction"></a>invert_direction |  Invert direction for symmetric interfaces   | Boolean | optional |  `False`  |
| <a id="symmetric_wit_bindgen-language"></a>language |  Target language for bindings   | String | optional |  `"rust"`  |
| <a id="symmetric_wit_bindgen-options"></a>options |  Additional options to pass to wit-bindgen   | List of strings | optional |  `[]`  |
| <a id="symmetric_wit_bindgen-wit"></a>wit |  WIT library to generate bindings for   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="wit_bindgen"></a>

## wit_bindgen

<pre>
load("@rules_wasm_component//wit:defs.bzl", "wit_bindgen")

wit_bindgen(<a href="#wit_bindgen-name">name</a>, <a href="#wit_bindgen-additional_derives">additional_derives</a>, <a href="#wit_bindgen-async_interfaces">async_interfaces</a>, <a href="#wit_bindgen-format_code">format_code</a>, <a href="#wit_bindgen-generate_all">generate_all</a>, <a href="#wit_bindgen-generation_mode">generation_mode</a>,
            <a href="#wit_bindgen-language">language</a>, <a href="#wit_bindgen-options">options</a>, <a href="#wit_bindgen-ownership">ownership</a>, <a href="#wit_bindgen-wit">wit</a>, <a href="#wit_bindgen-with_mappings">with_mappings</a>)
</pre>

Generates language bindings from WIT files.

This rule uses wit-bindgen to generate language-specific bindings
from WIT interface definitions.

Example:
    wit_bindgen(
        name = "my_bindings",
        wit = ":my_interfaces",
        language = "rust",
        with_mappings = {
            "wasi:io/poll": "wasi::io::poll",
            "my:custom/interface": "generate",
            "my:resource/type": "crate::MyCustomType",
        },
        ownership = "borrowing",
        additional_derives = ["Clone", "Debug"],
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wit_bindgen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wit_bindgen-additional_derives"></a>additional_derives |  Additional derive attributes to add to generated types (e.g., ['Clone', 'Debug', 'Serialize'])   | List of strings | optional |  `[]`  |
| <a id="wit_bindgen-async_interfaces"></a>async_interfaces |  Interfaces or functions to generate as async (e.g., ['my:pkg/interface#method', 'all'])   | List of strings | optional |  `[]`  |
| <a id="wit_bindgen-format_code"></a>format_code |  Whether to run formatter on generated code   | Boolean | optional |  `True`  |
| <a id="wit_bindgen-generate_all"></a>generate_all |  Whether to generate all interfaces not specified in with_mappings   | Boolean | optional |  `False`  |
| <a id="wit_bindgen-generation_mode"></a>generation_mode |  Generation mode: 'guest' for WASM component implementation, 'native-guest' for native application bindings   | String | optional |  `"guest"`  |
| <a id="wit_bindgen-language"></a>language |  Target language for bindings   | String | optional |  `"rust"`  |
| <a id="wit_bindgen-options"></a>options |  Additional options to pass to wit-bindgen   | List of strings | optional |  `[]`  |
| <a id="wit_bindgen-ownership"></a>ownership |  Type ownership model for generated bindings   | String | optional |  `"owning"`  |
| <a id="wit_bindgen-wit"></a>wit |  WIT library to generate bindings for   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wit_bindgen-with_mappings"></a>with_mappings |  Interface and type remappings (key=value pairs). Maps WIT interfaces/types to existing Rust modules or 'generate'.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |


<a id="wit_docs_collection"></a>

## wit_docs_collection

<pre>
load("@rules_wasm_component//wit:defs.bzl", "wit_docs_collection")

wit_docs_collection(<a href="#wit_docs_collection-name">name</a>, <a href="#wit_docs_collection-docs">docs</a>)
</pre>

Collects multiple WIT markdown documentation files into a single directory.

This rule creates a documentation directory containing all generated WIT
documentation files along with an index.md file linking to each document.

Example:
    wit_docs_collection(
        name = "all_docs",
        docs = [
            "//examples/go_component:calculator_docs",
            "//examples/js_component:hello_docs",
        ],
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wit_docs_collection-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wit_docs_collection-docs"></a>docs |  List of wit_markdown targets to collect   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="wit_library"></a>

## wit_library

<pre>
load("@rules_wasm_component//wit:defs.bzl", "wit_library")

wit_library(<a href="#wit_library-name">name</a>, <a href="#wit_library-deps">deps</a>, <a href="#wit_library-srcs">srcs</a>, <a href="#wit_library-interfaces">interfaces</a>, <a href="#wit_library-package_name">package_name</a>, <a href="#wit_library-world">world</a>)
</pre>

Defines a WIT (WebAssembly Interface Types) library.

This rule processes WIT files and makes them available for use
in WASM component builds and binding generation.

Example:
    wit_library(
        name = "my_interfaces",
        srcs = ["my-interface.wit"],
        package_name = "my:interfaces",
        interfaces = ["api", "types"],
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wit_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wit_library-deps"></a>deps |  WIT dependencies   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="wit_library-srcs"></a>srcs |  WIT source files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="wit_library-interfaces"></a>interfaces |  List of interface names defined in this library   | List of strings | optional |  `[]`  |
| <a id="wit_library-package_name"></a>package_name |  WIT package name (defaults to target name)   | String | optional |  `""`  |
| <a id="wit_library-world"></a>world |  World name defined in the WIT file (required for predictable binding generation)   | String | required |  |


<a id="wit_markdown"></a>

## wit_markdown

<pre>
load("@rules_wasm_component//wit:defs.bzl", "wit_markdown")

wit_markdown(<a href="#wit_markdown-name">name</a>, <a href="#wit_markdown-wit">wit</a>)
</pre>

Generates markdown documentation from WIT files using wit-bindgen.

This rule uses wit-bindgen's markdown output to generate comprehensive
documentation for WIT interfaces, including types, functions, and worlds.

Example:
    wit_markdown(
        name = "calculator_docs",
        wit = ":calculator_wit",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wit_markdown-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wit_markdown-wit"></a>wit |  WIT library target to generate documentation for   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


