---
title: WKG Package API
description: Fetch and use WebAssembly packages from wkg registries
---

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Bazel rules for WebAssembly Package Tools (wkg) with OCI support

<a id="wac_compose_with_oci"></a>

## wac_compose_with_oci

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wac_compose_with_oci")

wac_compose_with_oci(<a href="#wac_compose_with_oci-name">name</a>, <a href="#wac_compose_with_oci-composition">composition</a>, <a href="#wac_compose_with_oci-composition_file">composition_file</a>, <a href="#wac_compose_with_oci-local_components">local_components</a>, <a href="#wac_compose_with_oci-oci_components">oci_components</a>, <a href="#wac_compose_with_oci-profile">profile</a>,
                     <a href="#wac_compose_with_oci-public_key">public_key</a>, <a href="#wac_compose_with_oci-registry_config">registry_config</a>, <a href="#wac_compose_with_oci-verify_signatures">verify_signatures</a>)
</pre>

Compose WebAssembly components using WAC with support for OCI registry components.

This rule extends WAC composition to support pulling components from OCI registries
alongside local components, enabling distributed component architectures.

Example:
    wac_compose_with_oci(
        name = "distributed_app",
        local_components = {
            "frontend": ":frontend_component",
        },
        oci_components = {
            "auth_service": "ghcr.io/my-org/auth:v1.0.0",
            "data_service": "docker.io/company/data-api:latest",
        },
        registry_config = ":production_registries",
        verify_signatures = True,
        public_key = ":verification_key",
        composition = '''
            let frontend = new frontend:component { ... };
            let auth = new auth_service:component { ... };
            let data = new data_service:component { ... };

            connect frontend.auth -> auth.validate;
            connect frontend.data -> data.query;

            export frontend as main;
        ''',
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wac_compose_with_oci-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wac_compose_with_oci-composition"></a>composition |  Inline WAC composition code   | String | optional |  `""`  |
| <a id="wac_compose_with_oci-composition_file"></a>composition_file |  External WAC composition file   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wac_compose_with_oci-local_components"></a>local_components |  Local components to compose (name -> target)   | Dictionary: String -> Label | optional |  `{}`  |
| <a id="wac_compose_with_oci-oci_components"></a>oci_components |  OCI components to pull and compose (name -> image_ref)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="wac_compose_with_oci-profile"></a>profile |  Build profile to use for composition   | String | optional |  `"release"`  |
| <a id="wac_compose_with_oci-public_key"></a>public_key |  Public key for signature verification   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wac_compose_with_oci-registry_config"></a>registry_config |  Registry configuration for OCI authentication   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wac_compose_with_oci-verify_signatures"></a>verify_signatures |  Verify component signatures during pull   | Boolean | optional |  `False`  |


<a id="wasm_component_from_oci"></a>

## wasm_component_from_oci

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_from_oci")

wasm_component_from_oci(<a href="#wasm_component_from_oci-name">name</a>, <a href="#wasm_component_from_oci-component_name">component_name</a>, <a href="#wasm_component_from_oci-image_ref">image_ref</a>, <a href="#wasm_component_from_oci-namespace">namespace</a>, <a href="#wasm_component_from_oci-public_key">public_key</a>, <a href="#wasm_component_from_oci-registry">registry</a>,
                        <a href="#wasm_component_from_oci-registry_config">registry_config</a>, <a href="#wasm_component_from_oci-tag">tag</a>, <a href="#wasm_component_from_oci-verify_signature">verify_signature</a>)
</pre>

Pull a WebAssembly component from an OCI registry and make it available for use.

This rule downloads a WebAssembly component from an OCI-compatible registry
and provides it as a WasmComponentInfo that can be used in compositions or other rules.

Example:
    wasm_component_from_oci(
        name = "auth_service",
        registry = "ghcr.io",
        namespace = "my-org",
        component_name = "auth-service",
        tag = "v1.2.0",
        registry_config = ":my_registry_config",
        verify_signature = True,
        public_key = ":signing_public_key",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_from_oci-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_from_oci-component_name"></a>component_name |  Component name (defaults to rule name)   | String | optional |  `""`  |
| <a id="wasm_component_from_oci-image_ref"></a>image_ref |  Full OCI image reference (registry/namespace/name:tag). If provided, overrides individual components.   | String | optional |  `""`  |
| <a id="wasm_component_from_oci-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `""`  |
| <a id="wasm_component_from_oci-public_key"></a>public_key |  Public key for signature verification   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_from_oci-registry"></a>registry |  Registry URL (e.g., ghcr.io, docker.io)   | String | optional |  `""`  |
| <a id="wasm_component_from_oci-registry_config"></a>registry_config |  Registry configuration for authentication   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_from_oci-tag"></a>tag |  Image tag   | String | optional |  `"latest"`  |
| <a id="wasm_component_from_oci-verify_signature"></a>verify_signature |  Verify component signature during pull   | Boolean | optional |  `False`  |


<a id="wasm_component_metadata_extract"></a>

## wasm_component_metadata_extract

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_metadata_extract")

wasm_component_metadata_extract(<a href="#wasm_component_metadata_extract-name">name</a>, <a href="#wasm_component_metadata_extract-component">component</a>)
</pre>

Extract comprehensive metadata from WebAssembly components.

This rule uses wasm-tools and other analysis techniques to extract
detailed information about WebAssembly components for OCI annotation mapping.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_metadata_extract-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_metadata_extract-component"></a>component |  WebAssembly component file to extract metadata from   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="wasm_component_multi_arch"></a>

## wasm_component_multi_arch

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_multi_arch")

wasm_component_multi_arch(<a href="#wasm_component_multi_arch-name">name</a>, <a href="#wasm_component_multi_arch-annotations">annotations</a>, <a href="#wasm_component_multi_arch-arch_wasm32_unknown">arch_wasm32_unknown</a>, <a href="#wasm_component_multi_arch-arch_wasm32_unknown_unknown">arch_wasm32_unknown_unknown</a>,
                          <a href="#wasm_component_multi_arch-arch_wasm32_wasi">arch_wasm32_wasi</a>, <a href="#wasm_component_multi_arch-arch_wasm32_wasi_preview1">arch_wasm32_wasi_preview1</a>, <a href="#wasm_component_multi_arch-architectures">architectures</a>,
                          <a href="#wasm_component_multi_arch-default_architecture">default_architecture</a>, <a href="#wasm_component_multi_arch-namespace">namespace</a>, <a href="#wasm_component_multi_arch-package_name">package_name</a>, <a href="#wasm_component_multi_arch-version">version</a>)
</pre>

Create a multi-architecture WebAssembly component package.

This rule enables building and packaging WebAssembly components for
multiple target architectures and platforms (e.g., wasm32-wasi, wasm32-unknown-unknown).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_multi_arch-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_multi_arch-annotations"></a>annotations |  Additional OCI annotations in 'key=value' format   | List of strings | optional |  `[]`  |
| <a id="wasm_component_multi_arch-arch_wasm32_unknown"></a>arch_wasm32_unknown |  Component for wasm32-unknown architecture   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_multi_arch-arch_wasm32_unknown_unknown"></a>arch_wasm32_unknown_unknown |  Component for wasm32-unknown-unknown architecture   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_multi_arch-arch_wasm32_wasi"></a>arch_wasm32_wasi |  Component for wasm32-wasi architecture   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_multi_arch-arch_wasm32_wasi_preview1"></a>arch_wasm32_wasi_preview1 |  Component for wasm32-wasi-preview1 architecture   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_multi_arch-architectures"></a>architectures |  List of architectures in 'arch\|target_label\|platform' format   | List of strings | required |  |
| <a id="wasm_component_multi_arch-default_architecture"></a>default_architecture |  Default architecture for single-arch scenarios   | String | required |  |
| <a id="wasm_component_multi_arch-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `"library"`  |
| <a id="wasm_component_multi_arch-package_name"></a>package_name |  Package name for the multi-arch component   | String | required |  |
| <a id="wasm_component_multi_arch-version"></a>version |  Package version   | String | optional |  `"latest"`  |


<a id="wasm_component_multi_arch_publish"></a>

## wasm_component_multi_arch_publish

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_multi_arch_publish")

wasm_component_multi_arch_publish(<a href="#wasm_component_multi_arch_publish-name">name</a>, <a href="#wasm_component_multi_arch_publish-dry_run">dry_run</a>, <a href="#wasm_component_multi_arch_publish-multi_arch_image">multi_arch_image</a>, <a href="#wasm_component_multi_arch_publish-namespace">namespace</a>, <a href="#wasm_component_multi_arch_publish-registry">registry</a>,
                                  <a href="#wasm_component_multi_arch_publish-registry_config">registry_config</a>, <a href="#wasm_component_multi_arch_publish-tag">tag</a>)
</pre>

Publish a multi-architecture WebAssembly component to OCI registries.

This rule publishes each architecture as a separate image with architecture-specific tags,
enabling runtime selection of the appropriate architecture.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_multi_arch_publish-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_multi_arch_publish-dry_run"></a>dry_run |  Perform dry run without actual publish   | Boolean | optional |  `False`  |
| <a id="wasm_component_multi_arch_publish-multi_arch_image"></a>multi_arch_image |  Multi-architecture image created with wasm_component_multi_arch   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_component_multi_arch_publish-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `"library"`  |
| <a id="wasm_component_multi_arch_publish-registry"></a>registry |  Registry URL   | String | optional |  `"localhost:5000"`  |
| <a id="wasm_component_multi_arch_publish-registry_config"></a>registry_config |  Registry configuration   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_multi_arch_publish-tag"></a>tag |  Base image tag (architectures will be appended)   | String | optional |  `"latest"`  |


<a id="wasm_component_oci_image"></a>

## wasm_component_oci_image

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_oci_image")

wasm_component_oci_image(<a href="#wasm_component_oci_image-name">name</a>, <a href="#wasm_component_oci_image-annotations">annotations</a>, <a href="#wasm_component_oci_image-authors">authors</a>, <a href="#wasm_component_oci_image-component">component</a>, <a href="#wasm_component_oci_image-description">description</a>, <a href="#wasm_component_oci_image-license">license</a>, <a href="#wasm_component_oci_image-name_override">name_override</a>,
                         <a href="#wasm_component_oci_image-namespace">namespace</a>, <a href="#wasm_component_oci_image-package_name">package_name</a>, <a href="#wasm_component_oci_image-registry">registry</a>, <a href="#wasm_component_oci_image-sign_component">sign_component</a>, <a href="#wasm_component_oci_image-signature_type">signature_type</a>,
                         <a href="#wasm_component_oci_image-signing_keys">signing_keys</a>, <a href="#wasm_component_oci_image-tag">tag</a>, <a href="#wasm_component_oci_image-version">version</a>)
</pre>

Prepare a WebAssembly component for OCI image creation with optional signing.

This rule takes a WebAssembly component and prepares it for publishing to
an OCI registry. It can optionally sign the component using wasmsign2
before creating the OCI metadata.

Example:
    wasm_component_oci_image(
        name = "my_component_image",
        component = ":my_component",
        package_name = "my-company/my-component",
        registry = "ghcr.io",
        namespace = "my-org",
        tag = "v1.0.0",
        sign_component = True,
        signing_keys = ":component_keys",
        annotations = [
            "org.opencontainers.image.description=My WebAssembly component",
            "org.opencontainers.image.source=https://github.com/my-org/my-component",
        ],
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_oci_image-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_oci_image-annotations"></a>annotations |  List of OCI annotations in 'key=value' format   | List of strings | optional |  `[]`  |
| <a id="wasm_component_oci_image-authors"></a>authors |  List of component authors   | List of strings | optional |  `[]`  |
| <a id="wasm_component_oci_image-component"></a>component |  WebAssembly component to prepare for OCI   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_component_oci_image-description"></a>description |  Component description   | String | optional |  `""`  |
| <a id="wasm_component_oci_image-license"></a>license |  Component license   | String | optional |  `""`  |
| <a id="wasm_component_oci_image-name_override"></a>name_override |  Override the component name in the image reference   | String | optional |  `""`  |
| <a id="wasm_component_oci_image-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `"library"`  |
| <a id="wasm_component_oci_image-package_name"></a>package_name |  Package name for the component   | String | required |  |
| <a id="wasm_component_oci_image-registry"></a>registry |  Registry URL (e.g., ghcr.io, docker.io)   | String | optional |  `"localhost:5000"`  |
| <a id="wasm_component_oci_image-sign_component"></a>sign_component |  Whether to sign the component before creating OCI image   | Boolean | optional |  `False`  |
| <a id="wasm_component_oci_image-signature_type"></a>signature_type |  Type of signature (embedded or detached)   | String | optional |  `"embedded"`  |
| <a id="wasm_component_oci_image-signing_keys"></a>signing_keys |  Key pair for signing (required if sign_component=True)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_oci_image-tag"></a>tag |  Image tag   | String | optional |  `"latest"`  |
| <a id="wasm_component_oci_image-version"></a>version |  Package version (defaults to tag)   | String | optional |  `""`  |


<a id="wasm_component_oci_metadata_mapper"></a>

## wasm_component_oci_metadata_mapper

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_oci_metadata_mapper")

wasm_component_oci_metadata_mapper(<a href="#wasm_component_oci_metadata_mapper-name">name</a>, <a href="#wasm_component_oci_metadata_mapper-compliance_tags">compliance_tags</a>, <a href="#wasm_component_oci_metadata_mapper-component">component</a>, <a href="#wasm_component_oci_metadata_mapper-component_type">component_type</a>,
                                   <a href="#wasm_component_oci_metadata_mapper-custom_annotations">custom_annotations</a>, <a href="#wasm_component_oci_metadata_mapper-description">description</a>, <a href="#wasm_component_oci_metadata_mapper-framework">framework</a>, <a href="#wasm_component_oci_metadata_mapper-is_signed">is_signed</a>, <a href="#wasm_component_oci_metadata_mapper-language">language</a>,
                                   <a href="#wasm_component_oci_metadata_mapper-license">license</a>, <a href="#wasm_component_oci_metadata_mapper-metadata_extract">metadata_extract</a>, <a href="#wasm_component_oci_metadata_mapper-optimization_level">optimization_level</a>, <a href="#wasm_component_oci_metadata_mapper-performance_tier">performance_tier</a>,
                                   <a href="#wasm_component_oci_metadata_mapper-security_level">security_level</a>, <a href="#wasm_component_oci_metadata_mapper-signature_type">signature_type</a>, <a href="#wasm_component_oci_metadata_mapper-source_url">source_url</a>, <a href="#wasm_component_oci_metadata_mapper-title">title</a>, <a href="#wasm_component_oci_metadata_mapper-version">version</a>,
                                   <a href="#wasm_component_oci_metadata_mapper-wasi_version">wasi_version</a>)
</pre>

Create comprehensive OCI metadata mapping from WebAssembly component information.

This rule combines component metadata, extracted information, and user-provided
data to create a comprehensive set of OCI annotations.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_oci_metadata_mapper-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_oci_metadata_mapper-compliance_tags"></a>compliance_tags |  Compliance standards   | List of strings | optional |  `[]`  |
| <a id="wasm_component_oci_metadata_mapper-component"></a>component |  WebAssembly component to map metadata for   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_component_oci_metadata_mapper-component_type"></a>component_type |  Component type (service, library, tool, etc.)   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-custom_annotations"></a>custom_annotations |  Custom annotations in key=value format   | List of strings | optional |  `[]`  |
| <a id="wasm_component_oci_metadata_mapper-description"></a>description |  Component description   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-framework"></a>framework |  Runtime framework   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-is_signed"></a>is_signed |  Whether component is signed   | Boolean | optional |  `False`  |
| <a id="wasm_component_oci_metadata_mapper-language"></a>language |  Source language   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-license"></a>license |  Component license   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-metadata_extract"></a>metadata_extract |  Optional extracted metadata from wasm_component_metadata_extract   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_oci_metadata_mapper-optimization_level"></a>optimization_level |  Optimization level   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-performance_tier"></a>performance_tier |  Performance tier   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-security_level"></a>security_level |  Security level   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-signature_type"></a>signature_type |  Signature type   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-source_url"></a>source_url |  Source repository URL   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-title"></a>title |  Component title   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-version"></a>version |  Component version   | String | optional |  `""`  |
| <a id="wasm_component_oci_metadata_mapper-wasi_version"></a>wasi_version |  WASI version   | String | optional |  `""`  |


<a id="wasm_component_publish"></a>

## wasm_component_publish

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_publish")

wasm_component_publish(<a href="#wasm_component_publish-name">name</a>, <a href="#wasm_component_publish-authors">authors</a>, <a href="#wasm_component_publish-description">description</a>, <a href="#wasm_component_publish-dry_run">dry_run</a>, <a href="#wasm_component_publish-license">license</a>, <a href="#wasm_component_publish-namespace_override">namespace_override</a>, <a href="#wasm_component_publish-oci_image">oci_image</a>,
                       <a href="#wasm_component_publish-registry_config">registry_config</a>, <a href="#wasm_component_publish-registry_override">registry_override</a>, <a href="#wasm_component_publish-tag_override">tag_override</a>)
</pre>

Publish a prepared WebAssembly component OCI image to a registry.

This rule takes an OCI image prepared with wasm_component_oci_image and
publishes it to an OCI registry using wkg. It supports registry
authentication, dry-run mode, and comprehensive metadata handling.

Example:
    # First prepare the OCI image
    wasm_component_oci_image(
        name = "my_component_image",
        component = ":my_component",
        package_name = "my-company/my-component",
        sign_component = True,
        signing_keys = ":component_keys",
    )

    # Then publish it
    wasm_component_publish(
        name = "publish_component",
        oci_image = ":my_component_image",
        registry_config = ":registry_config",
        description = "My WebAssembly component",
        authors = ["developer@company.com"],
        license = "MIT",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_publish-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_publish-authors"></a>authors |  List of component authors   | List of strings | optional |  `[]`  |
| <a id="wasm_component_publish-description"></a>description |  Component description for package metadata   | String | optional |  `""`  |
| <a id="wasm_component_publish-dry_run"></a>dry_run |  Perform dry run without actual publish   | Boolean | optional |  `False`  |
| <a id="wasm_component_publish-license"></a>license |  Component license   | String | optional |  `""`  |
| <a id="wasm_component_publish-namespace_override"></a>namespace_override |  Override namespace from OCI image   | String | optional |  `""`  |
| <a id="wasm_component_publish-oci_image"></a>oci_image |  OCI image created with wasm_component_oci_image   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_component_publish-registry_config"></a>registry_config |  Registry configuration with authentication   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_publish-registry_override"></a>registry_override |  Override registry from OCI image   | String | optional |  `""`  |
| <a id="wasm_component_publish-tag_override"></a>tag_override |  Override tag from OCI image   | String | optional |  `""`  |


<a id="wasm_component_secure_publish"></a>

## wasm_component_secure_publish

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_secure_publish")

wasm_component_secure_publish(<a href="#wasm_component_secure_publish-name">name</a>, <a href="#wasm_component_secure_publish-annotations">annotations</a>, <a href="#wasm_component_secure_publish-authors">authors</a>, <a href="#wasm_component_secure_publish-component">component</a>, <a href="#wasm_component_secure_publish-description">description</a>, <a href="#wasm_component_secure_publish-dry_run">dry_run</a>,
                              <a href="#wasm_component_secure_publish-force_signing">force_signing</a>, <a href="#wasm_component_secure_publish-license">license</a>, <a href="#wasm_component_secure_publish-namespace">namespace</a>, <a href="#wasm_component_secure_publish-openssh_format">openssh_format</a>, <a href="#wasm_component_secure_publish-package_name">package_name</a>,
                              <a href="#wasm_component_secure_publish-registry_config">registry_config</a>, <a href="#wasm_component_secure_publish-security_policy">security_policy</a>, <a href="#wasm_component_secure_publish-signature_type">signature_type</a>, <a href="#wasm_component_secure_publish-signing_keys">signing_keys</a>, <a href="#wasm_component_secure_publish-tag">tag</a>,
                              <a href="#wasm_component_secure_publish-target_registries">target_registries</a>)
</pre>

Publish WebAssembly components with automatic security policy enforcement.

This rule automatically applies security policies, validates components,
and ensures signing requirements are met before publishing to registries.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_component_secure_publish-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_component_secure_publish-annotations"></a>annotations |  Additional OCI annotations in 'key=value' format   | List of strings | optional |  `[]`  |
| <a id="wasm_component_secure_publish-authors"></a>authors |  List of component authors   | List of strings | optional |  `[]`  |
| <a id="wasm_component_secure_publish-component"></a>component |  WebAssembly component file to publish   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wasm_component_secure_publish-description"></a>description |  Component description   | String | optional |  `""`  |
| <a id="wasm_component_secure_publish-dry_run"></a>dry_run |  Perform dry run without actual publish   | Boolean | optional |  `False`  |
| <a id="wasm_component_secure_publish-force_signing"></a>force_signing |  Force signing regardless of policy   | Boolean | optional |  `False`  |
| <a id="wasm_component_secure_publish-license"></a>license |  Component license   | String | optional |  `""`  |
| <a id="wasm_component_secure_publish-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `"library"`  |
| <a id="wasm_component_secure_publish-openssh_format"></a>openssh_format |  OpenSSH format override   | Boolean | optional |  `False`  |
| <a id="wasm_component_secure_publish-package_name"></a>package_name |  Package name for the component   | String | required |  |
| <a id="wasm_component_secure_publish-registry_config"></a>registry_config |  Registry configuration   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_secure_publish-security_policy"></a>security_policy |  Security policy to enforce   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_secure_publish-signature_type"></a>signature_type |  Signature type override (embedded, detached)   | String | optional |  `"embedded"`  |
| <a id="wasm_component_secure_publish-signing_keys"></a>signing_keys |  Signing keys (if required by policy)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wasm_component_secure_publish-tag"></a>tag |  Image tag   | String | optional |  `"latest"`  |
| <a id="wasm_component_secure_publish-target_registries"></a>target_registries |  List of target registry names   | List of strings | required |  |


<a id="wasm_security_policy"></a>

## wasm_security_policy

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_security_policy")

wasm_security_policy(<a href="#wasm_security_policy-name">name</a>, <a href="#wasm_security_policy-component_policies">component_policies</a>, <a href="#wasm_security_policy-default_signing_required">default_signing_required</a>, <a href="#wasm_security_policy-key_source">key_source</a>, <a href="#wasm_security_policy-openssh_format">openssh_format</a>,
                     <a href="#wasm_security_policy-registry_policies">registry_policies</a>, <a href="#wasm_security_policy-signature_type">signature_type</a>)
</pre>

Define security policies for WebAssembly component publishing.

Security policies control signing requirements for different registries
and component types, providing enterprise-grade security controls.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wasm_security_policy-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wasm_security_policy-component_policies"></a>component_policies |  Component-specific policies in 'pattern\|required\|allowed_keys' format   | List of strings | optional |  `[]`  |
| <a id="wasm_security_policy-default_signing_required"></a>default_signing_required |  Whether signing is required by default   | Boolean | optional |  `False`  |
| <a id="wasm_security_policy-key_source"></a>key_source |  Default key source (file, env, keychain)   | String | optional |  `"file"`  |
| <a id="wasm_security_policy-openssh_format"></a>openssh_format |  Whether to use OpenSSH key format by default   | Boolean | optional |  `False`  |
| <a id="wasm_security_policy-registry_policies"></a>registry_policies |  Registry-specific policies in 'registry\|required\|allowed_keys' format   | List of strings | optional |  `[]`  |
| <a id="wasm_security_policy-signature_type"></a>signature_type |  Default signature type (embedded, detached)   | String | optional |  `"embedded"`  |


<a id="wkg_fetch"></a>

## wkg_fetch

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_fetch")

wkg_fetch(<a href="#wkg_fetch-name">name</a>, <a href="#wkg_fetch-package">package</a>, <a href="#wkg_fetch-registry">registry</a>, <a href="#wkg_fetch-version">version</a>)
</pre>

Fetch a WebAssembly component package from a registry

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_fetch-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_fetch-package"></a>package |  Package name to fetch (e.g., 'wasi:http')   | String | required |  |
| <a id="wkg_fetch-registry"></a>registry |  Registry URL to fetch from (optional)   | String | optional |  `""`  |
| <a id="wkg_fetch-version"></a>version |  Package version to fetch (defaults to latest)   | String | optional |  `""`  |


<a id="wkg_inspect"></a>

## wkg_inspect

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_inspect")

wkg_inspect(<a href="#wkg_inspect-name">name</a>, <a href="#wkg_inspect-namespace">namespace</a>, <a href="#wkg_inspect-package_name">package_name</a>, <a href="#wkg_inspect-registry">registry</a>, <a href="#wkg_inspect-registry_config">registry_config</a>, <a href="#wkg_inspect-tag">tag</a>)
</pre>

Inspect a WebAssembly component OCI image metadata

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_inspect-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_inspect-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `"library"`  |
| <a id="wkg_inspect-package_name"></a>package_name |  Package name to inspect   | String | required |  |
| <a id="wkg_inspect-registry"></a>registry |  Registry URL (overrides registry_config default)   | String | optional |  `""`  |
| <a id="wkg_inspect-registry_config"></a>registry_config |  Registry configuration with authentication   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wkg_inspect-tag"></a>tag |  Image tag to inspect   | String | optional |  `"latest"`  |


<a id="wkg_lock"></a>

## wkg_lock

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_lock")

wkg_lock(<a href="#wkg_lock-name">name</a>, <a href="#wkg_lock-dependencies">dependencies</a>, <a href="#wkg_lock-package_name">package_name</a>, <a href="#wkg_lock-registry">registry</a>, <a href="#wkg_lock-world_name">world_name</a>)
</pre>

Generate WIT dependencies and lock file using wkg wit fetch

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_lock-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_lock-dependencies"></a>dependencies |  List of dependencies in 'namespace:package:version' format   | List of strings | optional |  `[]`  |
| <a id="wkg_lock-package_name"></a>package_name |  Name of the package for WIT world definition   | String | required |  |
| <a id="wkg_lock-registry"></a>registry |  Registry URL to resolve dependencies from (optional)   | String | optional |  `""`  |
| <a id="wkg_lock-world_name"></a>world_name |  Name of the WIT world to create   | String | optional |  `"main"`  |


<a id="wkg_multi_registry_publish"></a>

## wkg_multi_registry_publish

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_multi_registry_publish")

wkg_multi_registry_publish(<a href="#wkg_multi_registry_publish-name">name</a>, <a href="#wkg_multi_registry_publish-authors">authors</a>, <a href="#wkg_multi_registry_publish-description">description</a>, <a href="#wkg_multi_registry_publish-dry_run">dry_run</a>, <a href="#wkg_multi_registry_publish-fail_fast">fail_fast</a>, <a href="#wkg_multi_registry_publish-license">license</a>,
                           <a href="#wkg_multi_registry_publish-namespace_override">namespace_override</a>, <a href="#wkg_multi_registry_publish-oci_image">oci_image</a>, <a href="#wkg_multi_registry_publish-registry_config">registry_config</a>, <a href="#wkg_multi_registry_publish-tag_override">tag_override</a>,
                           <a href="#wkg_multi_registry_publish-target_registries">target_registries</a>)
</pre>

Publish a WebAssembly component OCI image to multiple registries.

This rule enables publishing the same component to multiple registries
with a single command, supporting different authentication methods and
registry-specific configurations.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_multi_registry_publish-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_multi_registry_publish-authors"></a>authors |  List of component authors   | List of strings | optional |  `[]`  |
| <a id="wkg_multi_registry_publish-description"></a>description |  Component description for package metadata   | String | optional |  `""`  |
| <a id="wkg_multi_registry_publish-dry_run"></a>dry_run |  Perform dry run without actual publish   | Boolean | optional |  `False`  |
| <a id="wkg_multi_registry_publish-fail_fast"></a>fail_fast |  Stop on first registry failure   | Boolean | optional |  `True`  |
| <a id="wkg_multi_registry_publish-license"></a>license |  Component license   | String | optional |  `""`  |
| <a id="wkg_multi_registry_publish-namespace_override"></a>namespace_override |  Override namespace for all registries   | String | optional |  `""`  |
| <a id="wkg_multi_registry_publish-oci_image"></a>oci_image |  OCI image created with wasm_component_oci_image   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wkg_multi_registry_publish-registry_config"></a>registry_config |  Registry configuration with multiple registries   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="wkg_multi_registry_publish-tag_override"></a>tag_override |  Override tag for all registries   | String | optional |  `""`  |
| <a id="wkg_multi_registry_publish-target_registries"></a>target_registries |  List of registry names to publish to (defaults to all configured registries)   | List of strings | optional |  `[]`  |


<a id="wkg_publish"></a>

## wkg_publish

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_publish")

wkg_publish(<a href="#wkg_publish-name">name</a>, <a href="#wkg_publish-authors">authors</a>, <a href="#wkg_publish-component">component</a>, <a href="#wkg_publish-description">description</a>, <a href="#wkg_publish-license">license</a>, <a href="#wkg_publish-package_name">package_name</a>, <a href="#wkg_publish-registry">registry</a>, <a href="#wkg_publish-version">version</a>,
            <a href="#wkg_publish-wasm_file">wasm_file</a>)
</pre>

Publish a WebAssembly component to a registry

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_publish-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_publish-authors"></a>authors |  List of package authors (optional)   | List of strings | optional |  `[]`  |
| <a id="wkg_publish-component"></a>component |  WebAssembly component to publish   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wkg_publish-description"></a>description |  Package description (optional)   | String | optional |  `""`  |
| <a id="wkg_publish-license"></a>license |  Package license (optional)   | String | optional |  `""`  |
| <a id="wkg_publish-package_name"></a>package_name |  Package name for publishing   | String | required |  |
| <a id="wkg_publish-registry"></a>registry |  Registry URL to publish to (optional)   | String | optional |  `""`  |
| <a id="wkg_publish-version"></a>version |  Package version for publishing   | String | required |  |
| <a id="wkg_publish-wasm_file"></a>wasm_file |  WebAssembly component file to publish (alternative to component)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wkg_pull"></a>

## wkg_pull

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_pull")

wkg_pull(<a href="#wkg_pull-name">name</a>, <a href="#wkg_pull-namespace">namespace</a>, <a href="#wkg_pull-package_name">package_name</a>, <a href="#wkg_pull-registry">registry</a>, <a href="#wkg_pull-registry_config">registry_config</a>, <a href="#wkg_pull-tag">tag</a>)
</pre>

Pull a WebAssembly component from an OCI registry

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_pull-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_pull-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `"library"`  |
| <a id="wkg_pull-package_name"></a>package_name |  Package name to pull   | String | required |  |
| <a id="wkg_pull-registry"></a>registry |  Registry URL (overrides registry_config default)   | String | optional |  `""`  |
| <a id="wkg_pull-registry_config"></a>registry_config |  Registry configuration with authentication   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wkg_pull-tag"></a>tag |  Image tag to pull   | String | optional |  `"latest"`  |


<a id="wkg_push"></a>

## wkg_push

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_push")

wkg_push(<a href="#wkg_push-name">name</a>, <a href="#wkg_push-annotations">annotations</a>, <a href="#wkg_push-authors">authors</a>, <a href="#wkg_push-component">component</a>, <a href="#wkg_push-description">description</a>, <a href="#wkg_push-license">license</a>, <a href="#wkg_push-name_override">name_override</a>, <a href="#wkg_push-namespace">namespace</a>,
         <a href="#wkg_push-package_name">package_name</a>, <a href="#wkg_push-registry">registry</a>, <a href="#wkg_push-registry_config">registry_config</a>, <a href="#wkg_push-tag">tag</a>, <a href="#wkg_push-version">version</a>, <a href="#wkg_push-wasm_file">wasm_file</a>)
</pre>

Push a WebAssembly component to an OCI registry

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_push-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_push-annotations"></a>annotations |  List of OCI annotations in 'key=value' format   | List of strings | optional |  `[]`  |
| <a id="wkg_push-authors"></a>authors |  List of component authors   | List of strings | optional |  `[]`  |
| <a id="wkg_push-component"></a>component |  WebAssembly component to push   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wkg_push-description"></a>description |  Component description   | String | optional |  `""`  |
| <a id="wkg_push-license"></a>license |  Component license   | String | optional |  `""`  |
| <a id="wkg_push-name_override"></a>name_override |  Override the component name in the image reference   | String | optional |  `""`  |
| <a id="wkg_push-namespace"></a>namespace |  Registry namespace/organization   | String | optional |  `"library"`  |
| <a id="wkg_push-package_name"></a>package_name |  Package name for the component   | String | required |  |
| <a id="wkg_push-registry"></a>registry |  Registry URL (overrides registry_config default)   | String | optional |  `""`  |
| <a id="wkg_push-registry_config"></a>registry_config |  Registry configuration with authentication   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="wkg_push-tag"></a>tag |  Image tag   | String | optional |  `"latest"`  |
| <a id="wkg_push-version"></a>version |  Package version (defaults to tag)   | String | optional |  `""`  |
| <a id="wkg_push-wasm_file"></a>wasm_file |  WASM file to push (if not using component)   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="wkg_registry_config"></a>

## wkg_registry_config

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wkg_registry_config")

wkg_registry_config(<a href="#wkg_registry_config-name">name</a>, <a href="#wkg_registry_config-cache_dir">cache_dir</a>, <a href="#wkg_registry_config-credential_files">credential_files</a>, <a href="#wkg_registry_config-default_registry">default_registry</a>, <a href="#wkg_registry_config-enable_mirror_fallback">enable_mirror_fallback</a>,
                    <a href="#wkg_registry_config-registries">registries</a>, <a href="#wkg_registry_config-timeout_seconds">timeout_seconds</a>)
</pre>

Configure WebAssembly component registries with advanced authentication and features.

This rule supports multiple authentication methods:
- Token-based: GitHub PAT, Docker Hub tokens
- Basic auth: Username/password combinations
- OAuth: Client credentials flow
- Environment variables: Secure token injection

Advanced features:
- Registry mirrors and fallback
- Custom caching configuration
- Network timeout configuration
- Docker/Kubernetes credential file generation

Example:
    wkg_registry_config(
        name = "production_registries",
        registries = [
            "local|localhost:5000|oci",
            "github|ghcr.io|oci|env|GITHUB_TOKEN",
            "aws|123456789.dkr.ecr.us-west-2.amazonaws.com|oci|oauth|client_id|client_secret",
            "docker|docker.io|oci|token|dckr_pat_xxx",
        ],
        default_registry = "github",
        enable_mirror_fallback = True,
        timeout_seconds = 60,
        credential_files = [
            "docker:docker_config",
            "k8s:kubernetes",
        ],
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="wkg_registry_config-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="wkg_registry_config-cache_dir"></a>cache_dir |  Custom cache directory for registry operations   | String | optional |  `""`  |
| <a id="wkg_registry_config-credential_files"></a>credential_files |  List of credential file configurations in format 'registry:type'. Examples: - 'docker:docker_config' - Generate Docker-style config.json - 'k8s:kubernetes' - Generate Kubernetes secret manifest   | List of strings | optional |  `[]`  |
| <a id="wkg_registry_config-default_registry"></a>default_registry |  Default registry name for operations   | String | optional |  `""`  |
| <a id="wkg_registry_config-enable_mirror_fallback"></a>enable_mirror_fallback |  Enable registry mirror fallback for improved reliability   | Boolean | optional |  `False`  |
| <a id="wkg_registry_config-registries"></a>registries |  List of registry configurations in format 'name\|url\|type\|auth_type\|auth_data'. Examples: - 'docker\|docker.io\|oci' - 'github\|ghcr.io\|oci\|token\|ghp_xxx' - 'private\|registry.company.com\|oci\|basic\|user\|pass' - 'aws\|123456789.dkr.ecr.us-west-2.amazonaws.com\|oci\|oauth\|client_id\|client_secret' - 'secure\|secure-registry.com\|oci\|env\|SECURE_TOKEN'   | List of strings | optional |  `[]`  |
| <a id="wkg_registry_config-timeout_seconds"></a>timeout_seconds |  Network timeout for registry operations (seconds)   | Integer | optional |  `30`  |


<a id="enhanced_oci_annotations"></a>

## enhanced_oci_annotations

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "enhanced_oci_annotations")

enhanced_oci_annotations(<a href="#enhanced_oci_annotations-component_type">component_type</a>, <a href="#enhanced_oci_annotations-language">language</a>, <a href="#enhanced_oci_annotations-framework">framework</a>, <a href="#enhanced_oci_annotations-wasi_version">wasi_version</a>, <a href="#enhanced_oci_annotations-security_level">security_level</a>,
                         <a href="#enhanced_oci_annotations-compliance_tags">compliance_tags</a>, <a href="#enhanced_oci_annotations-custom_annotations">custom_annotations</a>)
</pre>

Generate enhanced OCI annotations for WebAssembly components.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="enhanced_oci_annotations-component_type"></a>component_type |  Type of component (service, library, tool, etc.)   |  `None` |
| <a id="enhanced_oci_annotations-language"></a>language |  Source language (rust, go, c, etc.)   |  `None` |
| <a id="enhanced_oci_annotations-framework"></a>framework |  Framework used (spin, wasmtime, etc.)   |  `None` |
| <a id="enhanced_oci_annotations-wasi_version"></a>wasi_version |  WASI version (preview1, preview2, etc.)   |  `None` |
| <a id="enhanced_oci_annotations-security_level"></a>security_level |  Security level (basic, enhanced, enterprise)   |  `None` |
| <a id="enhanced_oci_annotations-compliance_tags"></a>compliance_tags |  List of compliance standards (SOC2, FIPS, etc.)   |  `[]` |
| <a id="enhanced_oci_annotations-custom_annotations"></a>custom_annotations |  Additional custom annotations   |  `[]` |

**RETURNS**

List of OCI annotations in key=value format


<a id="wac_distributed_system"></a>

## wac_distributed_system

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wac_distributed_system")

wac_distributed_system(<a href="#wac_distributed_system-name">name</a>, <a href="#wac_distributed_system-components">components</a>, <a href="#wac_distributed_system-composition">composition</a>, <a href="#wac_distributed_system-registry_config">registry_config</a>, <a href="#wac_distributed_system-kwargs">**kwargs</a>)
</pre>

Convenience macro for creating distributed systems with mixed local/OCI components.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="wac_distributed_system-name"></a>name |  Name of the composed system   |  none |
| <a id="wac_distributed_system-components"></a>components |  Dict with 'local' and 'oci' keys containing component mappings   |  none |
| <a id="wac_distributed_system-composition"></a>composition |  WAC composition code   |  none |
| <a id="wac_distributed_system-registry_config"></a>registry_config |  Registry configuration for authentication   |  `None` |
| <a id="wac_distributed_system-kwargs"></a>kwargs |  Additional arguments passed to wac_compose_with_oci   |  none |


<a id="wac_microservices_app"></a>

## wac_microservices_app

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wac_microservices_app")

wac_microservices_app(<a href="#wac_microservices_app-name">name</a>, <a href="#wac_microservices_app-frontend_component">frontend_component</a>, <a href="#wac_microservices_app-services">services</a>, <a href="#wac_microservices_app-registry_config">registry_config</a>, <a href="#wac_microservices_app-kwargs">**kwargs</a>)
</pre>

Convenience macro for creating microservices applications with OCI service dependencies.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="wac_microservices_app-name"></a>name |  Name of the composed application   |  none |
| <a id="wac_microservices_app-frontend_component"></a>frontend_component |  Local frontend component target   |  none |
| <a id="wac_microservices_app-services"></a>services |  Dict of service_name -> OCI image reference   |  none |
| <a id="wac_microservices_app-registry_config"></a>registry_config |  Registry configuration for authentication   |  `None` |
| <a id="wac_microservices_app-kwargs"></a>kwargs |  Additional arguments passed to wac_compose_with_oci   |  none |


<a id="wasm_component_multi_arch_package"></a>

## wasm_component_multi_arch_package

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_multi_arch_package")

wasm_component_multi_arch_package(<a href="#wasm_component_multi_arch_package-name">name</a>, <a href="#wasm_component_multi_arch_package-package_name">package_name</a>, <a href="#wasm_component_multi_arch_package-components">components</a>, <a href="#wasm_component_multi_arch_package-default_architecture">default_architecture</a>, <a href="#wasm_component_multi_arch_package-version">version</a>,
                                  <a href="#wasm_component_multi_arch_package-namespace">namespace</a>, <a href="#wasm_component_multi_arch_package-annotations">annotations</a>, <a href="#wasm_component_multi_arch_package-kwargs">**kwargs</a>)
</pre>

Convenience macro for creating multi-architecture WebAssembly component packages.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="wasm_component_multi_arch_package-name"></a>name |  Name of the package   |  none |
| <a id="wasm_component_multi_arch_package-package_name"></a>package_name |  Package name for the component   |  none |
| <a id="wasm_component_multi_arch_package-components"></a>components |  Dict of architecture -> component label (e.g., {"wasm32-wasi": "//path:component"})   |  none |
| <a id="wasm_component_multi_arch_package-default_architecture"></a>default_architecture |  Default architecture   |  none |
| <a id="wasm_component_multi_arch_package-version"></a>version |  Package version   |  `"latest"` |
| <a id="wasm_component_multi_arch_package-namespace"></a>namespace |  Registry namespace   |  `"library"` |
| <a id="wasm_component_multi_arch_package-annotations"></a>annotations |  Additional OCI annotations   |  `[]` |
| <a id="wasm_component_multi_arch_package-kwargs"></a>kwargs |  Additional arguments   |  none |


<a id="wasm_component_oci_publish"></a>

## wasm_component_oci_publish

<pre>
load("@rules_wasm_component//wkg:defs.bzl", "wasm_component_oci_publish")

wasm_component_oci_publish(<a href="#wasm_component_oci_publish-name">name</a>, <a href="#wasm_component_oci_publish-component">component</a>, <a href="#wasm_component_oci_publish-package_name">package_name</a>, <a href="#wasm_component_oci_publish-registry">registry</a>, <a href="#wasm_component_oci_publish-namespace">namespace</a>, <a href="#wasm_component_oci_publish-tag">tag</a>, <a href="#wasm_component_oci_publish-sign_component">sign_component</a>,
                           <a href="#wasm_component_oci_publish-signing_keys">signing_keys</a>, <a href="#wasm_component_oci_publish-signature_type">signature_type</a>, <a href="#wasm_component_oci_publish-registry_config">registry_config</a>, <a href="#wasm_component_oci_publish-description">description</a>, <a href="#wasm_component_oci_publish-authors">authors</a>,
                           <a href="#wasm_component_oci_publish-license">license</a>, <a href="#wasm_component_oci_publish-annotations">annotations</a>, <a href="#wasm_component_oci_publish-dry_run">dry_run</a>, <a href="#wasm_component_oci_publish-kwargs">**kwargs</a>)
</pre>

Combines wasm_component_oci_image and wasm_component_publish for convenient publishing.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="wasm_component_oci_publish-name"></a>name |  Name of the publish target   |  none |
| <a id="wasm_component_oci_publish-component"></a>component |  WebAssembly component to publish   |  none |
| <a id="wasm_component_oci_publish-package_name"></a>package_name |  Package name for the component   |  none |
| <a id="wasm_component_oci_publish-registry"></a>registry |  Registry URL (default: localhost:5000)   |  `"localhost:5000"` |
| <a id="wasm_component_oci_publish-namespace"></a>namespace |  Registry namespace/organization (default: library)   |  `"library"` |
| <a id="wasm_component_oci_publish-tag"></a>tag |  Image tag (default: latest)   |  `"latest"` |
| <a id="wasm_component_oci_publish-sign_component"></a>sign_component |  Whether to sign component before publishing (default: False)   |  `False` |
| <a id="wasm_component_oci_publish-signing_keys"></a>signing_keys |  Key pair for signing (required if sign_component=True)   |  `None` |
| <a id="wasm_component_oci_publish-signature_type"></a>signature_type |  Type of signature - embedded or detached (default: embedded)   |  `"embedded"` |
| <a id="wasm_component_oci_publish-registry_config"></a>registry_config |  Registry configuration with authentication   |  `None` |
| <a id="wasm_component_oci_publish-description"></a>description |  Component description   |  `None` |
| <a id="wasm_component_oci_publish-authors"></a>authors |  List of component authors   |  `[]` |
| <a id="wasm_component_oci_publish-license"></a>license |  Component license   |  `None` |
| <a id="wasm_component_oci_publish-annotations"></a>annotations |  List of OCI annotations in 'key=value' format   |  `[]` |
| <a id="wasm_component_oci_publish-dry_run"></a>dry_run |  Perform dry run without actual publish (default: False)   |  `False` |
| <a id="wasm_component_oci_publish-kwargs"></a>kwargs |  Additional arguments passed to rules   |  none |


