---
title: WASM Utilities API
description: Validate, inspect, and manipulate WebAssembly components and modules
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for WASM utility rules

<a id="wasm_aot_config"></a>

## wasm_aot_config

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_aot_config")

wasm_aot_config(<a href="#wasm_aot_config-name">name</a>, <a href="#wasm_aot_config-debug_info">debug_info</a>, <a href="#wasm_aot_config-optimization_level">optimization_level</a>, <a href="#wasm_aot_config-strip_symbols">strip_symbols</a>, <a href="#wasm_aot_config-target_triple">target_triple</a>)
</pre>

Configuration for AOT compilation defaults.

Example:
    wasm_aot_config(
        name = "aot_config_prod",
        optimization_level = "s",
        debug_info = False,
        strip_symbols = True,
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_aot_config-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_aot_config-debug_info"></a>debug_info |  Include debug info in AOT compilation by default   | Boolean | optional |  `False`  |
| <a id="wasm_aot_config-optimization_level"></a>optimization_level |  Default optimization level for AOT compilation   | Integer | optional |  `2`  |
| <a id="wasm_aot_config-strip_symbols"></a>strip_symbols |  Strip symbols in AOT compilation by default   | Boolean | optional |  `True`  |
| <a id="wasm_aot_config-target_triple"></a>target_triple |  Default target triple for cross-compilation   | String | optional |  `""`  |


<a id="wasm_component_new"></a>

## wasm_component_new

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_component_new")

wasm_component_new(<a href="#wasm_component_new-name">name</a>, <a href="#wasm_component_new-adapter">adapter</a>, <a href="#wasm_component_new-options">options</a>, <a href="#wasm_component_new-wasm_module">wasm_module</a>)
</pre>

Converts a WebAssembly module to a component.

This rule uses wasm-tools to convert a core WASM module into
a WebAssembly component, optionally with a WASI adapter.

Example:
    wasm_component_new(
        name = "my_component",
        wasm_module = "my_module.wasm",
        adapter = "@wasi_preview1_adapter//file",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_new-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_new-adapter"></a>adapter |  WASI adapter module for Preview1 compatibility   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_new-options"></a>options |  Additional options to pass to wasm-tools component new   | List of strings | optional |  `[]`  |
| <a id="wasm_component_new-wasm_module"></a>wasm_module |  WASM module to convert to component   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="wasm_component_wizer"></a>

## wasm_component_wizer

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_component_wizer")

wasm_component_wizer(<a href="#wasm_component_wizer-name">name</a>, <a href="#wasm_component_wizer-component">component</a>, <a href="#wasm_component_wizer-init_function_name">init_function_name</a>, <a href="#wasm_component_wizer-init_script">init_script</a>)
</pre>

Pre-initialize a WebAssembly component with Wizer.

This rule takes a WebAssembly component and runs Wizer pre-initialization on it,
which can provide 1.35-6x startup performance improvements by running initialization
code at build time rather than runtime.

The input component must export a function named 'wizer.initialize' (or the name
specified in init_function_name) that performs the initialization work.

Example:
    wasm_component_wizer(
        name = "optimized_component",
        component = ":my_component",
        init_function_name = "wizer.initialize",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_wizer-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_wizer-component"></a>component |  Input WebAssembly component to pre-initialize   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_component_wizer-init_function_name"></a>init_function_name |  Name of the initialization function to call (default: wizer.initialize)   | String | optional |  `"wizer.initialize"`  |
| <a id="wasm_component_wizer-init_script"></a>init_script |  Optional initialization script or data file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wasm_embed_aot"></a>

## wasm_embed_aot

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_embed_aot")

wasm_embed_aot(<a href="#wasm_embed_aot-name">name</a>, <a href="#wasm_embed_aot-aot_artifacts">aot_artifacts</a>, <a href="#wasm_embed_aot-component">component</a>)
</pre>

Embed AOT-compiled WebAssembly artifacts as custom sections in a component.

This rule takes a WebAssembly component and embeds multiple AOT-compiled
versions (.cwasm files) as custom sections. The resulting component can
be signed normally with wasmsign2, and runtime code can extract the
appropriate AOT artifact for the current architecture.

Example:
    wasm_embed_aot(
        name = "component_with_aot",
        component = ":my_component",
        aot_artifacts = {
            "linux-x64": ":my_component_x64",
            "linux-arm64": ":my_component_arm64",
            "portable": ":my_component_pulley",
        },
    )

The embedded custom sections will be named:
    - "aot-linux-x64"
    - "aot-linux-arm64"
    - "aot-portable"

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_embed_aot-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_embed_aot-aot_artifacts"></a>aot_artifacts |  Dictionary mapping target names to precompiled AOT artifacts   | Dictionary: String -> Label | required |  |
| <a id="wasm_embed_aot-component"></a>component |  Base WebAssembly component to embed AOT artifacts into   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="wasm_extract_aot"></a>

## wasm_extract_aot

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_extract_aot")

wasm_extract_aot(<a href="#wasm_extract_aot-name">name</a>, <a href="#wasm_extract_aot-component">component</a>, <a href="#wasm_extract_aot-target_name">target_name</a>)
</pre>

Extract an AOT-compiled artifact from a WebAssembly component.

This rule extracts a specific AOT artifact that was previously embedded
as a custom section, allowing runtime code to access the appropriate
compiled version for the current architecture.

Example:
    wasm_extract_aot(
        name = "extracted_aot",
        component = ":component_with_aot.wasm",
        target_name = "linux-x64",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_extract_aot-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_extract_aot-component"></a>component |  WebAssembly component with embedded AOT artifacts   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_extract_aot-target_name"></a>target_name |  Target architecture name to extract (e.g., 'linux-x64')   | String | required |  |


<a id="wasm_keygen"></a>

## wasm_keygen

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_keygen")

wasm_keygen(<a href="#wasm_keygen-name">name</a>, <a href="#wasm_keygen-openssh_format">openssh_format</a>, <a href="#wasm_keygen-public_key_name">public_key_name</a>, <a href="#wasm_keygen-secret_key_name">secret_key_name</a>)
</pre>

Generates a key pair for signing WebAssembly components in compact format.

This rule uses wasmsign2 keygen to generate a public/secret key pair
in the compact WebAssembly signature format. The keys can be used for
signing and verifying WASM components.

Note: wasmsign2 keygen always generates compact format keys. If you need
OpenSSH format keys (for use with the -Z/--ssh flag), use ssh_keygen instead.

Example:
    wasm_keygen(
        name = "signing_keys",
        public_key_name = "my_key.public",
        secret_key_name = "my_key.secret",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_keygen-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_keygen-openssh_format"></a>openssh_format |  Deprecated: Ignored. wasmsign2 keygen always generates compact format keys.   | Boolean | optional |  `False`  |
| <a id="wasm_keygen-public_key_name"></a>public_key_name |  Name of the public key file to generate   | String | optional |  `"key.public"`  |
| <a id="wasm_keygen-secret_key_name"></a>secret_key_name |  Name of the secret key file to generate   | String | optional |  `"key.secret"`  |


<a id="wasm_precompile"></a>

## wasm_precompile

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_precompile")

wasm_precompile(<a href="#wasm_precompile-name">name</a>, <a href="#wasm_precompile-component">component</a>, <a href="#wasm_precompile-debug_info">debug_info</a>, <a href="#wasm_precompile-optimization_level">optimization_level</a>, <a href="#wasm_precompile-strip_symbols">strip_symbols</a>, <a href="#wasm_precompile-target_triple">target_triple</a>,
                <a href="#wasm_precompile-wasm_file">wasm_file</a>)
</pre>

Ahead-of-Time (AOT) compile WebAssembly modules using Wasmtime.

This rule precompiles WASM modules into native machine code (.cwasm files)
for faster startup times. The output is cached by Bazel based on:
- Source WASM content
- Wasmtime version
- Compilation settings
- Target architecture

Debug information: By default, debug info is excluded for production
builds (87% size reduction). Set debug_info=True for debugging.

Examples:
    # Production build (small, no debug info) - Default
    wasm_precompile(
        name = "my_component_aot",
        component = ":my_component",
        optimization_level = "2",
    )

    # Debug build (large, with debug info and symbols)
    wasm_precompile(
        name = "my_component_debug",
        component = ":my_component",
        debug_info = True,
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_precompile-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_precompile-component"></a>component |  Alternative: WasmComponent target to precompile   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_precompile-debug_info"></a>debug_info |  Include DWARF debug information (increases .cwasm size ~8x)   | Boolean | optional |  `False`  |
| <a id="wasm_precompile-optimization_level"></a>optimization_level |  Optimization level (0=none, 1=speed, 2=speed+size, s=size)   | String | optional |  `"2"`  |
| <a id="wasm_precompile-strip_symbols"></a>strip_symbols |  Strip symbol tables to reduce size (note: currently ignored, kept for compatibility)   | Boolean | optional |  `False`  |
| <a id="wasm_precompile-target_triple"></a>target_triple |  Target triple for cross-compilation (e.g., x86_64-unknown-linux-gnu)   | String | optional |  `""`  |
| <a id="wasm_precompile-wasm_file"></a>wasm_file |  Input WebAssembly module/component to precompile   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wasm_precompile_multi"></a>

## wasm_precompile_multi

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_precompile_multi")

wasm_precompile_multi(<a href="#wasm_precompile_multi-name">name</a>, <a href="#wasm_precompile_multi-component">component</a>, <a href="#wasm_precompile_multi-debug_info">debug_info</a>, <a href="#wasm_precompile_multi-optimization_level">optimization_level</a>, <a href="#wasm_precompile_multi-strip_symbols">strip_symbols</a>, <a href="#wasm_precompile_multi-targets">targets</a>)
</pre>

Ahead-of-Time (AOT) compile WebAssembly modules for multiple target architectures using Wasmtime.

This rule precompiles WASM modules into native machine code (.cwasm files) for multiple
architectures in parallel, enabling efficient multi-platform deployment.

Example:
    wasm_precompile_multi(
        name = "my_component_multi_arch",
        component = ":my_component",
        targets = {
            "linux_x64": "x86_64-unknown-linux-gnu",
            "linux_arm64": "aarch64-unknown-linux-gnu",
            "pulley64": "pulley64",  # Portable
        },
        optimization_level = "2",
    )

Output files:
    - my_component_multi_arch.linux_x64.cwasm
    - my_component_multi_arch.linux_arm64.cwasm
    - my_component_multi_arch.pulley64.cwasm

Access individual targets:
    bazel build :my_component_multi_arch:linux_x64
    bazel build :my_component_multi_arch:all

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_precompile_multi-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_precompile_multi-component"></a>component |  WasmComponent target to precompile for multiple architectures   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_precompile_multi-debug_info"></a>debug_info |  Include debug information (increases .cwasm size significantly)   | Boolean | optional |  `False`  |
| <a id="wasm_precompile_multi-optimization_level"></a>optimization_level |  Optimization level (0=none, 1=speed, 2=speed+size, s=size)   | String | optional |  `"2"`  |
| <a id="wasm_precompile_multi-strip_symbols"></a>strip_symbols |  Strip symbol tables to reduce size (saves ~25%)   | Boolean | optional |  `True`  |
| <a id="wasm_precompile_multi-targets"></a>targets |  Dictionary mapping target names to target triples (e.g., {'linux_x64': 'x86_64-unknown-linux-gnu'})   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | required |  |


<a id="wasm_run"></a>

## wasm_run

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_run")

wasm_run(<a href="#wasm_run-name">name</a>, <a href="#wasm_run-allow_wasi_filesystem">allow_wasi_filesystem</a>, <a href="#wasm_run-allow_wasi_net">allow_wasi_net</a>, <a href="#wasm_run-component">component</a>, <a href="#wasm_run-cwasm_file">cwasm_file</a>, <a href="#wasm_run-module_args">module_args</a>,
         <a href="#wasm_run-prefer_aot">prefer_aot</a>, <a href="#wasm_run-wasm_file">wasm_file</a>)
</pre>

Execute WebAssembly components using Wasmtime runtime.

This rule can run either:
- Regular .wasm files (JIT compiled at runtime)
- Precompiled .cwasm files (AOT compiled, faster startup)

If a target has both regular and precompiled versions,
it will prefer the precompiled version by default.

Example:
    wasm_run(
        name = "run_component",
        component = ":my_component_aot",  # Uses AOT if available
        allow_wasi_filesystem = True,
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_run-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_run-allow_wasi_filesystem"></a>allow_wasi_filesystem |  Allow WASI filesystem access   | Boolean | optional |  `True`  |
| <a id="wasm_run-allow_wasi_net"></a>allow_wasi_net |  Allow WASI network access   | Boolean | optional |  `False`  |
| <a id="wasm_run-component"></a>component |  WebAssembly component to run (can be regular or precompiled)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_run-cwasm_file"></a>cwasm_file |  Direct precompiled WebAssembly file to run   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_run-module_args"></a>module_args |  Additional arguments to pass to the WASM module   | List of strings | optional |  `[]`  |
| <a id="wasm_run-prefer_aot"></a>prefer_aot |  Use AOT compiled version if available   | Boolean | optional |  `True`  |
| <a id="wasm_run-wasm_file"></a>wasm_file |  Direct WebAssembly module file to run   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wasm_sign"></a>

## wasm_sign

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_sign")

wasm_sign(<a href="#wasm_sign-name">name</a>, <a href="#wasm_sign-component">component</a>, <a href="#wasm_sign-detached">detached</a>, <a href="#wasm_sign-keys">keys</a>, <a href="#wasm_sign-openssh_format">openssh_format</a>, <a href="#wasm_sign-public_key">public_key</a>, <a href="#wasm_sign-secret_key">secret_key</a>, <a href="#wasm_sign-wasm_file">wasm_file</a>)
</pre>

Signs a WebAssembly component with a cryptographic signature.

This rule uses wasmsign2 to add a digital signature to a WASM component,
either embedded in the component or as a detached signature file.

Example:
    wasm_sign(
        name = "signed_component",
        component = ":my_component",
        keys = ":signing_keys",
        detached = False,
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_sign-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_sign-component"></a>component |  WASM component to sign   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_sign-detached"></a>detached |  Create detached signature instead of embedding   | Boolean | optional |  `False`  |
| <a id="wasm_sign-keys"></a>keys |  Key pair generated by wasm_keygen   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_sign-openssh_format"></a>openssh_format |  Use OpenSSH key format   | Boolean | optional |  `False`  |
| <a id="wasm_sign-public_key"></a>public_key |  Public key file (if not using keys)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_sign-secret_key"></a>secret_key |  Secret key file (if not using keys)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_sign-wasm_file"></a>wasm_file |  WASM file to sign (if not using component)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wasm_test"></a>

## wasm_test

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_test")

wasm_test(<a href="#wasm_test-name">name</a>, <a href="#wasm_test-allow_wasi_filesystem">allow_wasi_filesystem</a>, <a href="#wasm_test-allow_wasi_net">allow_wasi_net</a>, <a href="#wasm_test-component">component</a>, <a href="#wasm_test-cwasm_file">cwasm_file</a>, <a href="#wasm_test-module_args">module_args</a>,
          <a href="#wasm_test-prefer_aot">prefer_aot</a>, <a href="#wasm_test-wasm_file">wasm_file</a>)
</pre>

Test WebAssembly components using Wasmtime runtime.

Similar to wasm_run but designed for testing scenarios.
Supports both JIT and AOT execution modes.

Example:
    wasm_test(
        name = "component_test",
        component = ":my_component",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_test-allow_wasi_filesystem"></a>allow_wasi_filesystem |  Allow WASI filesystem access   | Boolean | optional |  `True`  |
| <a id="wasm_test-allow_wasi_net"></a>allow_wasi_net |  Allow WASI network access   | Boolean | optional |  `False`  |
| <a id="wasm_test-component"></a>component |  WebAssembly component to test   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_test-cwasm_file"></a>cwasm_file |  Direct precompiled WebAssembly file to test   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_test-module_args"></a>module_args |  Additional arguments to pass to the WASM module   | List of strings | optional |  `[]`  |
| <a id="wasm_test-prefer_aot"></a>prefer_aot |  Use AOT compiled version if available   | Boolean | optional |  `True`  |
| <a id="wasm_test-wasm_file"></a>wasm_file |  Direct WebAssembly module file to test   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wasm_validate"></a>

## wasm_validate

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_validate")

wasm_validate(<a href="#wasm_validate-name">name</a>, <a href="#wasm_validate-component">component</a>, <a href="#wasm_validate-github_account">github_account</a>, <a href="#wasm_validate-public_key">public_key</a>, <a href="#wasm_validate-signature_file">signature_file</a>, <a href="#wasm_validate-signing_keys">signing_keys</a>,
              <a href="#wasm_validate-verify_signature">verify_signature</a>, <a href="#wasm_validate-wasm_file">wasm_file</a>)
</pre>

Validates a WebAssembly file or component with optional signature verification.

This rule uses wasm-tools to validate WASM files and extract
information about components, imports, exports, etc. It can also
verify cryptographic signatures using wasmsign2.

Example:
    wasm_validate(
        name = "validate_my_component",
        component = ":my_component",
    )

    wasm_validate(
        name = "validate_and_verify_signed_component",
        component = ":my_component",
        verify_signature = True,
        signing_keys = ":my_keys",
    )

    wasm_validate(
        name = "validate_with_github_verification",
        wasm_file = "my_file.wasm",
        verify_signature = True,
        github_account = "myuser",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_validate-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_validate-component"></a>component |  WASM component to validate   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_validate-github_account"></a>github_account |  GitHub account to retrieve public keys from   | String | optional |  `""`  |
| <a id="wasm_validate-public_key"></a>public_key |  Public key file for signature verification   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_validate-signature_file"></a>signature_file |  Detached signature file (if applicable)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_validate-signing_keys"></a>signing_keys |  Key pair with public key for verification   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_validate-verify_signature"></a>verify_signature |  Enable signature verification during validation   | Boolean | optional |  `False`  |
| <a id="wasm_validate-wasm_file"></a>wasm_file |  WASM file to validate   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wasm_verify"></a>

## wasm_verify

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_verify")

wasm_verify(<a href="#wasm_verify-name">name</a>, <a href="#wasm_verify-github_account">github_account</a>, <a href="#wasm_verify-keys">keys</a>, <a href="#wasm_verify-openssh_format">openssh_format</a>, <a href="#wasm_verify-public_key">public_key</a>, <a href="#wasm_verify-signature_file">signature_file</a>,
            <a href="#wasm_verify-signed_component">signed_component</a>, <a href="#wasm_verify-split_regex">split_regex</a>, <a href="#wasm_verify-wasm_file">wasm_file</a>)
</pre>

Verifies the cryptographic signature of a WebAssembly component.

This rule uses wasmsign2 to verify that a WASM component's signature
is valid and was created by the holder of the corresponding secret key.

Example:
    wasm_verify(
        name = "verify_component",
        signed_component = ":signed_component",
        keys = ":signing_keys",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_verify-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_verify-github_account"></a>github_account |  GitHub account to retrieve public keys from   | String | optional |  `""`  |
| <a id="wasm_verify-keys"></a>keys |  Key pair with public key for verification   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_verify-openssh_format"></a>openssh_format |  Use OpenSSH key format   | Boolean | optional |  `False`  |
| <a id="wasm_verify-public_key"></a>public_key |  Public key file for verification   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_verify-signature_file"></a>signature_file |  Detached signature file (if applicable)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_verify-signed_component"></a>signed_component |  Signed WASM component to verify   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_verify-split_regex"></a>split_regex |  Regular expression for partial verification   | String | optional |  `""`  |
| <a id="wasm_verify-wasm_file"></a>wasm_file |  WASM file to verify (if not using signed_component)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wizer_chain"></a>

## wizer_chain

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wizer_chain")

wizer_chain(<a href="#wizer_chain-name">name</a>, <a href="#wizer_chain-component">component</a>, <a href="#wizer_chain-init_function_name">init_function_name</a>)
</pre>

Chain Wizer pre-initialization after an existing component rule.

This is a convenience rule that takes the output of another component-building
rule and applies Wizer pre-initialization to it.

Example:
    go_wasm_component(
        name = "my_component",
        srcs = ["main.go"],
        # ... other attrs
    )

    wizer_chain(
        name = "optimized_component",
        component = ":my_component",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wizer_chain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wizer_chain-component"></a>component |  WebAssembly component target to pre-initialize   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wizer_chain-init_function_name"></a>init_function_name |  Name of the initialization function   | String | optional |  `"wizer_initialize"`  |


<a id="wasm_aot_aspect"></a>

## wasm_aot_aspect

<pre>
load("@rules_wasm_component//wasm:defs.bzl", "wasm_aot_aspect")

wasm_aot_aspect()
</pre>

Aspect that automatically creates AOT compiled versions of WASM components.

This aspect can be applied to any target that provides WasmComponentInfo
to automatically generate a precompiled .cwasm version alongside the
original .wasm file.

Usage:
    bazel build --aspects=//wasm:wasm_aot_aspect.bzl%wasm_aot_aspect :my_component

**ASPECT ATTRIBUTES**



**ATTRIBUTES**



