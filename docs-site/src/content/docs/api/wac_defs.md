---
title: WAC Composition API
description: Compose multiple WebAssembly components using wac
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for WAC composition rules

<a id="wac_bundle"></a>

## wac_bundle

<pre>
load("@rules_wasm_component//wac:defs.bzl", "wac_bundle")

wac_bundle(<a href="#wac_bundle-name">name</a>, <a href="#wac_bundle-components">components</a>)
</pre>

Bundle WASM components without composition, suitable for WASI components

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wac_bundle-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wac_bundle-components"></a>components |  Map of component targets to their names in the bundle   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | required |  |


<a id="wac_compose"></a>

## wac_compose

<pre>
load("@rules_wasm_component//wac:defs.bzl", "wac_compose")

wac_compose(<a href="#wac_compose-name">name</a>, <a href="#wac_compose-component_profiles">component_profiles</a>, <a href="#wac_compose-components">components</a>, <a href="#wac_compose-composition">composition</a>, <a href="#wac_compose-composition_file">composition_file</a>, <a href="#wac_compose-profile">profile</a>,
            <a href="#wac_compose-use_symlinks">use_symlinks</a>)
</pre>

Composes multiple WebAssembly components using WAC with profile support.

This rule uses the WebAssembly Composition (WAC) tool to combine
multiple WASM components into a single composed component, with support
for different build profiles and memory-efficient symlinks.

Example:
    wac_compose(
        name = "my_system",
        components = {
            "frontend": ":frontend_component",
            "backend": ":backend_component",
        },
        profile = "release",                    # Default profile
        component_profiles = {                  # Per-component overrides
            "frontend": "debug",                # Use debug build for frontend
        },
        composition = '''
            let frontend = new frontend:component { ... };
            let backend = new backend:component { ... };

            connect frontend.request -> backend.handler;

            export frontend as main;
        ''',
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wac_compose-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wac_compose-component_profiles"></a>component_profiles |  Per-component profile overrides (component_name -> profile)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="wac_compose-components"></a>components |  Components to compose (name -> target)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | required |  |
| <a id="wac_compose-composition"></a>composition |  Inline WAC composition code   | String | optional |  `""`  |
| <a id="wac_compose-composition_file"></a>composition_file |  External WAC composition file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wac_compose-profile"></a>profile |  Build profile to use for composition (debug, release, custom)   | String | optional |  `"release"`  |
| <a id="wac_compose-use_symlinks"></a>use_symlinks |  Use symlinks instead of copying files to save space   | Boolean | optional |  `True`  |


<a id="wac_plug"></a>

## wac_plug

<pre>
load("@rules_wasm_component//wac:defs.bzl", "wac_plug")

wac_plug(<a href="#wac_plug-name">name</a>, <a href="#wac_plug-plugs">plugs</a>, <a href="#wac_plug-socket">socket</a>)
</pre>

Plug component exports into component imports using WAC

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wac_plug-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wac_plug-plugs"></a>plugs |  The plug components that export functions   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="wac_plug-socket"></a>socket |  The socket component that imports functions   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="wac_remote_compose"></a>

## wac_remote_compose

<pre>
load("@rules_wasm_component//wac:defs.bzl", "wac_remote_compose")

wac_remote_compose(<a href="#wac_remote_compose-name">name</a>, <a href="#wac_remote_compose-composition">composition</a>, <a href="#wac_remote_compose-composition_file">composition_file</a>, <a href="#wac_remote_compose-local_components">local_components</a>, <a href="#wac_remote_compose-profile">profile</a>,
                   <a href="#wac_remote_compose-remote_components">remote_components</a>, <a href="#wac_remote_compose-use_symlinks">use_symlinks</a>)
</pre>

Composes WebAssembly components using WAC with support for remote components via wkg.

This rule extends wac_compose to support fetching remote components from registries
using wkg before composing them with local components.

Example:
    wac_remote_compose(
        name = "my_distributed_system",
        local_components = {
            "frontend": ":frontend_component",
        },
        remote_components = {
            "backend": "my-registry/backend@1.2.0",
            "auth": "wasi:auth@0.1.0",
        },
        composition = '''
            let frontend = new frontend:component { ... };
            let backend = new backend:component { ... };
            let auth = new auth:component { ... };

            connect frontend.auth_request -> auth.validate;
            connect frontend.api_request -> backend.handler;

            export frontend as main;
        ''',
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wac_remote_compose-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wac_remote_compose-composition"></a>composition |  Inline WAC composition code   | String | optional |  `""`  |
| <a id="wac_remote_compose-composition_file"></a>composition_file |  External WAC composition file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wac_remote_compose-local_components"></a>local_components |  Local components to compose (name -> target)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: Label -> String</a> | optional |  `{}`  |
| <a id="wac_remote_compose-profile"></a>profile |  Build profile to use for composition (debug, release, custom)   | String | optional |  `"release"`  |
| <a id="wac_remote_compose-remote_components"></a>remote_components |  Remote components to fetch and compose (name -> 'package@version' or 'registry/package@version')   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="wac_remote_compose-use_symlinks"></a>use_symlinks |  Use symlinks instead of copying files to save space   | Boolean | optional |  `True`  |


