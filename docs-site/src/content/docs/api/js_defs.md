---
title: JavaScript Components API
description: Build WebAssembly components from JavaScript/TypeScript using componentize-js
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

JavaScript/TypeScript WebAssembly Component Model rules

Modern JavaScript/TypeScript support for WebAssembly Component Model using:
- Node.js 18.20.8+ with hermetic toolchain management
- jco v1.4.0+ for component compilation and optimization
- Bazel-native implementation with zero shell scripts
- Cross-platform compatibility (Windows/macOS/Linux)
- TypeScript support with automatic transpilation
- NPM dependency management integration
- Component composition and binding generation

Example usage:

    js_component(
        name = "web_service",
        srcs = ["index.js", "service.js"],
        package_json = "package.json",
        wit = "//wit:web-interface",
        world = "web-service",
        entry_point = "index.js",
        npm_dependencies = {
            "express": "^4.18.0",
            "@types/node": "^18.0.0",
        },
    )

<a id="jco_transpile"></a>

## jco_transpile

<pre>
load("@rules_wasm_component//js:defs.bzl", "jco_transpile")

jco_transpile(<a href="#jco_transpile-name">name</a>, <a href="#jco_transpile-component">component</a>, <a href="#jco_transpile-instantiation">instantiation</a>, <a href="#jco_transpile-map">map</a>, <a href="#jco_transpile-name_override">name_override</a>, <a href="#jco_transpile-no_typescript">no_typescript</a>, <a href="#jco_transpile-world_name">world_name</a>)
</pre>

Transpiles a WebAssembly component to JavaScript using jco.

This rule takes a compiled WebAssembly component and generates JavaScript
bindings that can be used in Node.js or browser environments.

Example:
    jco_transpile(
        name = "my_component_js",
        component = ":my_component.wasm",
        instantiation = "async",
        map = [
            "wasi:http/types@0.2.0=@wasi/http#types",
        ],
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="jco_transpile-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="jco_transpile-component"></a>component |  WebAssembly component file to transpile   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="jco_transpile-instantiation"></a>instantiation |  Component instantiation mode   | String | optional |  `""`  |
| <a id="jco_transpile-map"></a>map |  Interface mappings in the form 'from=to'   | List of strings | optional |  `[]`  |
| <a id="jco_transpile-name_override"></a>name_override |  Override the component name in generated JavaScript   | String | optional |  `""`  |
| <a id="jco_transpile-no_typescript"></a>no_typescript |  Disable TypeScript definition generation   | Boolean | optional |  `False`  |
| <a id="jco_transpile-world_name"></a>world_name |  Name for the generated world interface   | String | optional |  `""`  |


<a id="js_component"></a>

## js_component

<pre>
load("@rules_wasm_component//js:defs.bzl", "js_component")

js_component(<a href="#js_component-name">name</a>, <a href="#js_component-deps">deps</a>, <a href="#js_component-srcs">srcs</a>, <a href="#js_component-compat">compat</a>, <a href="#js_component-disable_feature_detection">disable_feature_detection</a>, <a href="#js_component-entry_point">entry_point</a>, <a href="#js_component-minify">minify</a>,
             <a href="#js_component-npm_dependencies">npm_dependencies</a>, <a href="#js_component-optimize">optimize</a>, <a href="#js_component-package_json">package_json</a>, <a href="#js_component-package_name">package_name</a>, <a href="#js_component-wit">wit</a>, <a href="#js_component-world">world</a>)
</pre>

Builds a WebAssembly component from JavaScript/TypeScript sources using jco.

This rule compiles JavaScript or TypeScript code into a WebAssembly component
that implements the specified WIT interface.

Example:
    js_component(
        name = "my_js_component",
        srcs = [
            "src/index.js",
            "src/utils.js",
        ],
        wit = "component.wit",
        entry_point = "index.js",
        npm_dependencies = {
            "lodash": "^4.17.21",
        },
        optimize = True,
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="js_component-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="js_component-deps"></a>deps |  Dependencies (other JavaScript libraries or components)   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="js_component-srcs"></a>srcs |  JavaScript/TypeScript source files   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="js_component-compat"></a>compat |  Enable compatibility mode for older JavaScript engines   | Boolean | optional |  `False`  |
| <a id="js_component-disable_feature_detection"></a>disable_feature_detection |  Disable WebAssembly feature detection   | Boolean | optional |  `False`  |
| <a id="js_component-entry_point"></a>entry_point |  Main entry point file   | String | optional |  `"index.js"`  |
| <a id="js_component-minify"></a>minify |  Minify generated code   | Boolean | optional |  `False`  |
| <a id="js_component-npm_dependencies"></a>npm_dependencies |  NPM dependencies to include in generated package.json   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="js_component-optimize"></a>optimize |  Enable optimizations   | Boolean | optional |  `True`  |
| <a id="js_component-package_json"></a>package_json |  package.json file (auto-generated if not provided)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="js_component-package_name"></a>package_name |  WIT package name (auto-generated if not provided)   | String | optional |  `""`  |
| <a id="js_component-wit"></a>wit |  WIT interface definition file   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="js_component-world"></a>world |  WIT world to target (optional)   | String | optional |  `""`  |


<a id="npm_install"></a>

## npm_install

<pre>
load("@rules_wasm_component//js:defs.bzl", "npm_install")

npm_install(<a href="#npm_install-name">name</a>, <a href="#npm_install-package_json">package_json</a>)
</pre>

Installs NPM dependencies for JavaScript components.

This rule runs npm install to fetch dependencies specified in package.json,
making them available for JavaScript component builds.

Example:
    npm_install(
        name = "npm_deps",
        package_json = "package.json",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="npm_install-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="npm_install-package_json"></a>package_json |  package.json file with dependencies   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


