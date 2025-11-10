---
title: WRPC Protocol API
description: Generate RPC bindings for WebAssembly components using wrpc
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Bazel rules for wrpc (WebAssembly Component RPC)

<a id="wrpc_bindgen"></a>

## wrpc_bindgen

<pre>
load("@rules_wasm_component//wrpc:defs.bzl", "wrpc_bindgen")

wrpc_bindgen(<a href="#wrpc_bindgen-name">name</a>, <a href="#wrpc_bindgen-language">language</a>, <a href="#wrpc_bindgen-wit">wit</a>, <a href="#wrpc_bindgen-world">world</a>)
</pre>

Generate language bindings for wrpc from WIT interfaces

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wrpc_bindgen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wrpc_bindgen-language"></a>language |  Target language for bindings (rust, go, etc.)   | String | optional |  `"rust"`  |
| <a id="wrpc_bindgen-wit"></a>wit |  WIT file defining the interface   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wrpc_bindgen-world"></a>world |  WIT world to generate bindings for   | String | required |  |


<a id="wrpc_invoke"></a>

## wrpc_invoke

<pre>
load("@rules_wasm_component//wrpc:defs.bzl", "wrpc_invoke")

wrpc_invoke(<a href="#wrpc_invoke-name">name</a>, <a href="#wrpc_invoke-address">address</a>, <a href="#wrpc_invoke-function">function</a>, <a href="#wrpc_invoke-transport">transport</a>)
</pre>

Invoke a function on a remote WebAssembly component via wrpc

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wrpc_invoke-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wrpc_invoke-address"></a>address |  Address of the remote component   | String | optional |  `"localhost:8080"`  |
| <a id="wrpc_invoke-function"></a>function |  Function to invoke on remote component   | String | required |  |
| <a id="wrpc_invoke-transport"></a>transport |  Transport protocol (tcp, nats, etc.)   | String | optional |  `"tcp"`  |


<a id="wrpc_serve"></a>

## wrpc_serve

<pre>
load("@rules_wasm_component//wrpc:defs.bzl", "wrpc_serve")

wrpc_serve(<a href="#wrpc_serve-name">name</a>, <a href="#wrpc_serve-address">address</a>, <a href="#wrpc_serve-component">component</a>, <a href="#wrpc_serve-transport">transport</a>)
</pre>

Serve a WebAssembly component via wrpc

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wrpc_serve-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wrpc_serve-address"></a>address |  Address to bind server to   | String | optional |  `"0.0.0.0:8080"`  |
| <a id="wrpc_serve-component"></a>component |  WebAssembly component to serve   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wrpc_serve-transport"></a>transport |  Transport protocol (tcp, nats, etc.)   | String | optional |  `"tcp"`  |


