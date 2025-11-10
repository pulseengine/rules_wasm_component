---
title: C++ Components API
description: Build WebAssembly components from C++ code using cpp_component and cc_component_library
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

C/C++ WebAssembly Component Model rules

Production-ready C/C++ support for WebAssembly Component Model using:
- WASI SDK v27+ with native Preview2 support
- Clang 20+ with advanced WebAssembly optimizations
- Bazel-native implementation with comprehensive cross-package header staging
- Cross-platform compatibility (Windows/macOS/Linux)
- Modern C++17/20/23 standard support with exception handling
- External library integration (nlohmann_json, abseil-cpp, spdlog, fmt)
- Advanced header dependency resolution and CcInfo provider integration
- Component libraries for modular development

Example usage:

    cpp_component(
        name = "calculator",
        srcs = ["calculator.cpp", "math_utils.cpp"],
        hdrs = ["calculator.h"],
        wit = "//wit:calculator-interface",
        world = "calculator",
        language = "cpp",
        cxx_std = "c++20",
        enable_exceptions = True,
        deps = [
            "@nlohmann_json//:json",
            "@abseil-cpp//absl/strings",
        ],
    )

    cc_component_library(
        name = "math_utils",
        srcs = ["math.cpp"],
        hdrs = ["math.h"],
        deps = ["@fmt//:fmt"],
    )

<a id="cc_component_library"></a>

## cc_component_library

<pre>
load("@rules_wasm_component//cpp:defs.bzl", "cc_component_library")

cc_component_library(<a href="#cc_component_library-name">name</a>, <a href="#cc_component_library-deps">deps</a>, <a href="#cc_component_library-srcs">srcs</a>, <a href="#cc_component_library-hdrs">hdrs</a>, <a href="#cc_component_library-copts">copts</a>, <a href="#cc_component_library-cxx_std">cxx_std</a>, <a href="#cc_component_library-defines">defines</a>, <a href="#cc_component_library-enable_exceptions">enable_exceptions</a>, <a href="#cc_component_library-includes">includes</a>,
                     <a href="#cc_component_library-language">language</a>, <a href="#cc_component_library-libs">libs</a>, <a href="#cc_component_library-nostdlib">nostdlib</a>, <a href="#cc_component_library-optimize">optimize</a>)
</pre>

Creates a static library for use in WebAssembly components.

This rule compiles C/C++ source files into a static library that can
be linked into WebAssembly components, providing modular development.

Example:
    cc_component_library(
        name = "math_utils",
        srcs = ["math.cpp", "algorithms.cpp"],
        hdrs = ["math.h", "algorithms.h"],
        language = "cpp",
        cxx_std = "c++20",
        optimize = True,
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cc_component_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cc_component_library-deps"></a>deps |  Dependencies (other cc_component_library targets)   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="cc_component_library-srcs"></a>srcs |  C/C++ source files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="cc_component_library-hdrs"></a>hdrs |  C/C++ header files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="cc_component_library-copts"></a>copts |  Additional compiler options   | List of strings | optional |  `[]`  |
| <a id="cc_component_library-cxx_std"></a>cxx_std |  C++ standard (e.g., c++17, c++20, c++23)   | String | optional |  `""`  |
| <a id="cc_component_library-defines"></a>defines |  Preprocessor definitions   | List of strings | optional |  `[]`  |
| <a id="cc_component_library-enable_exceptions"></a>enable_exceptions |  Enable C++ exceptions (increases binary size)   | Boolean | optional |  `False`  |
| <a id="cc_component_library-includes"></a>includes |  Additional include directories   | List of strings | optional |  `[]`  |
| <a id="cc_component_library-language"></a>language |  Language variant (c or cpp)   | String | optional |  `"cpp"`  |
| <a id="cc_component_library-libs"></a>libs |  Libraries to link. When nostdlib=True, only these libraries are linked. When nostdlib=False, these are added to standard libraries. Examples: ['m', 'dl'] or ['-lm', '-ldl']   | List of strings | optional |  `[]`  |
| <a id="cc_component_library-nostdlib"></a>nostdlib |  Disable standard library linking to create minimal components that match WIT specifications exactly   | Boolean | optional |  `False`  |
| <a id="cc_component_library-optimize"></a>optimize |  Enable optimizations   | Boolean | optional |  `True`  |


<a id="cpp_component"></a>

## cpp_component

<pre>
load("@rules_wasm_component//cpp:defs.bzl", "cpp_component")

cpp_component(<a href="#cpp_component-name">name</a>, <a href="#cpp_component-deps">deps</a>, <a href="#cpp_component-srcs">srcs</a>, <a href="#cpp_component-hdrs">hdrs</a>, <a href="#cpp_component-copts">copts</a>, <a href="#cpp_component-cxx_std">cxx_std</a>, <a href="#cpp_component-defines">defines</a>, <a href="#cpp_component-enable_exceptions">enable_exceptions</a>, <a href="#cpp_component-enable_rtti">enable_rtti</a>,
              <a href="#cpp_component-includes">includes</a>, <a href="#cpp_component-language">language</a>, <a href="#cpp_component-libs">libs</a>, <a href="#cpp_component-nostdlib">nostdlib</a>, <a href="#cpp_component-optimize">optimize</a>, <a href="#cpp_component-package_name">package_name</a>, <a href="#cpp_component-validate_wit">validate_wit</a>, <a href="#cpp_component-wit">wit</a>, <a href="#cpp_component-world">world</a>)
</pre>

Builds a WebAssembly component from C/C++ source code using Preview2.

This rule compiles C/C++ code directly to a Preview2 WebAssembly component
without requiring adapter modules, providing native component model support.

Example:
    cpp_component(
        name = "calculator_component",
        srcs = ["calculator.cpp", "math_utils.cpp"],
        hdrs = ["calculator.h"],
        wit = "calculator.wit",
        language = "cpp",
        world = "calculator",
        cxx_std = "c++20",
        optimize = True,
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cpp_component-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cpp_component-deps"></a>deps |  Dependencies (cc_component_library targets)   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="cpp_component-srcs"></a>srcs |  C/C++ source files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="cpp_component-hdrs"></a>hdrs |  C/C++ header files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="cpp_component-copts"></a>copts |  Additional compiler options   | List of strings | optional |  `[]`  |
| <a id="cpp_component-cxx_std"></a>cxx_std |  C++ standard (e.g., c++17, c++20, c++23)   | String | optional |  `""`  |
| <a id="cpp_component-defines"></a>defines |  Preprocessor definitions   | List of strings | optional |  `[]`  |
| <a id="cpp_component-enable_exceptions"></a>enable_exceptions |  Enable C++ exceptions (increases binary size)   | Boolean | optional |  `False`  |
| <a id="cpp_component-enable_rtti"></a>enable_rtti |  Enable C++ RTTI (not recommended for components)   | Boolean | optional |  `False`  |
| <a id="cpp_component-includes"></a>includes |  Additional include directories   | List of strings | optional |  `[]`  |
| <a id="cpp_component-language"></a>language |  Language variant (c or cpp)   | String | optional |  `"cpp"`  |
| <a id="cpp_component-libs"></a>libs |  Libraries to link. When nostdlib=True, only these libraries are linked. When nostdlib=False, these are added to standard libraries. Examples: ['m', 'dl'] or ['-lm', '-ldl']   | List of strings | optional |  `[]`  |
| <a id="cpp_component-nostdlib"></a>nostdlib |  Disable standard library linking to create minimal components that match WIT specifications exactly   | Boolean | optional |  `False`  |
| <a id="cpp_component-optimize"></a>optimize |  Enable optimizations   | Boolean | optional |  `True`  |
| <a id="cpp_component-package_name"></a>package_name |  WIT package name (auto-generated if not provided)   | String | optional |  `""`  |
| <a id="cpp_component-validate_wit"></a>validate_wit |  Validate that the component exports match the WIT specification   | Boolean | optional |  `False`  |
| <a id="cpp_component-wit"></a>wit |  WIT interface definition file   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="cpp_component-world"></a>world |  WIT world to target (optional)   | String | optional |  `""`  |


<a id="cpp_wit_bindgen"></a>

## cpp_wit_bindgen

<pre>
load("@rules_wasm_component//cpp:defs.bzl", "cpp_wit_bindgen")

cpp_wit_bindgen(<a href="#cpp_wit_bindgen-name">name</a>, <a href="#cpp_wit_bindgen-string_encoding">string_encoding</a>, <a href="#cpp_wit_bindgen-stubs_only">stubs_only</a>, <a href="#cpp_wit_bindgen-wit">wit</a>, <a href="#cpp_wit_bindgen-world">world</a>)
</pre>

Generates C/C++ bindings from WIT interface definitions.

This rule uses wit-bindgen to create C/C++ header and source files
that implement or consume WIT interfaces for component development.

Example:
    cpp_wit_bindgen(
        name = "calculator_bindings",
        wit = "calculator.wit",
        world = "calculator",
        string_encoding = "utf8",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="cpp_wit_bindgen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="cpp_wit_bindgen-string_encoding"></a>string_encoding |  String encoding to use in generated bindings   | String | optional |  `""`  |
| <a id="cpp_wit_bindgen-stubs_only"></a>stubs_only |  Generate only stub functions without implementation   | Boolean | optional |  `False`  |
| <a id="cpp_wit_bindgen-wit"></a>wit |  WIT interface definition file   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="cpp_wit_bindgen-world"></a>world |  WIT world to generate bindings for   | String | optional |  `""`  |


