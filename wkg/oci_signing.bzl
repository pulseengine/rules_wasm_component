"""Enhanced OCI image signing for WebAssembly components.

This module provides integration between wkg's OCI publishing capabilities
and rules_oci's OCI image signing features, enabling a two-layer security model:

1. Component-level signing with wasmsign2 (WASM component integrity)
2. OCI manifest signing with cosign/notation (container image integrity)
"""

load("@rules_oci//cosign:defs.bzl", "cosign_sign")
load(":defs.bzl", "wasm_component_oci_image", "wasm_component_publish")

def wasm_component_signed_oci_image(
        name,
        component,
        registry = None,
        namespace = "library",
        package_name = None,
        tag = "latest",
        # Component signing (wasmsign2)
        sign_component = False,
        component_signing_keys = None,
        signature_type = "embedded",
        # OCI image signing (cosign/notation)
        sign_oci_image = False,
        oci_signing_key = None,
        oci_signing_method = "cosign",
        # Registry and metadata
        registry_config = None,
        description = None,
        authors = [],
        license = None,
        annotations = [],
        visibility = None,
        **kwargs):
    """
    Creates and optionally signs a WebAssembly component OCI image with dual-layer security.
    
    This rule combines WASM component signing (wasmsign2) with OCI image signing (cosign/notation)
    to provide defense-in-depth security for WebAssembly components published to OCI registries.
    
    Security Layers:
    1. Component Layer: Signs the WASM component binary with wasmsign2
    2. OCI Layer: Signs the OCI manifest/layers with cosign or notation
    
    Args:
        name: Target name for the signed OCI image
        component: WebAssembly component target to package
        registry: OCI registry URL (default: localhost:5000)
        namespace: Registry namespace/organization (default: library)  
        package_name: Component package name (default: component name)
        tag: Image tag (default: latest)
        
        # Component-level signing
        sign_component: Whether to sign the WASM component with wasmsign2
        component_signing_keys: Key pair for component signing (wasmsign2)
        signature_type: Component signature type - embedded or detached
        
        # OCI image-level signing  
        sign_oci_image: Whether to sign the OCI manifest/layers
        oci_signing_key: Key for OCI image signing (cosign/notation)
        oci_signing_method: Signing method - cosign or notation (default: cosign)
        
        # Registry and metadata
        registry_config: Registry configuration with authentication
        description: Component description for OCI annotations
        authors: List of component authors
        license: Component license
        annotations: Additional OCI annotations
        visibility: Target visibility
        **kwargs: Additional arguments passed to underlying rules
        
    Example:
        ```starlark
        wasm_component_signed_oci_image(
            name = "secure_component_image", 
            component = ":my_component",
            registry = "ghcr.io",
            namespace = "my-org",
            package_name = "secure-component",
            tag = "v1.0.0",
            
            # Enable both security layers
            sign_component = True,
            component_signing_keys = ":wasm_keys",
            sign_oci_image = True, 
            oci_signing_key = ":cosign_key",
            
            description = "Production WebAssembly component with dual-layer security",
            authors = ["security@my-org.com"],
            license = "Apache-2.0",
        )
        ```
        
    Generated Targets:
        - {name}_oci_image: The prepared OCI image (possibly with signed component)
        - {name}_signed: The final OCI image with manifest signature (if sign_oci_image=True)
        - {name}: Alias pointing to the appropriate final target
    """
    
    # Validate signing configuration
    if sign_component and not component_signing_keys:
        fail("sign_component=True requires component_signing_keys to be specified")
        
    if sign_oci_image and not oci_signing_key:
        fail("sign_oci_image=True requires oci_signing_key to be specified") 
        
    if oci_signing_method not in ["cosign", "notation"]:
        fail("oci_signing_method must be 'cosign' or 'notation', got: " + oci_signing_method)
    
    # Step 1: Create the base OCI image (with optional component signing)
    oci_image_name = name + "_oci_image"
    wasm_component_oci_image(
        name = oci_image_name,
        component = component,
        registry = registry,
        namespace = namespace, 
        package_name = package_name,
        tag = tag,
        sign_component = sign_component,
        signing_keys = component_signing_keys,
        signature_type = signature_type,
        description = description,
        authors = authors,
        license = license,
        annotations = annotations,
        visibility = ["//visibility:private"],
        **kwargs
    )
    
    # Step 2: Optionally add OCI image signing
    if sign_oci_image:
        # Currently only cosign is supported by rules_oci
        if oci_signing_method == "cosign":
            cosign_sign(
                name = name + "_signed",
                image = ":" + oci_image_name,
                key = oci_signing_key,
                visibility = visibility,
            )
            
            # Final target points to signed image
            native.alias(
                name = name,
                actual = ":" + name + "_signed", 
                visibility = visibility,
            )
        else:
            # notation support would go here when available in rules_oci
            fail("notation signing not yet supported by rules_oci, use cosign")
    else:
        # Final target points to base OCI image
        native.alias(
            name = name,
            actual = ":" + oci_image_name,
            visibility = visibility,
        )

def wasm_component_secure_publish(
        name,
        signed_oci_image,
        registry_config = None,
        dry_run = False, 
        visibility = None,
        **kwargs):
    """
    Publishes a signed WebAssembly component OCI image to a registry.
    
    This rule publishes OCI images created with wasm_component_signed_oci_image,
    ensuring both component and OCI signatures are preserved during publication.
    
    Args:
        name: Target name for the publish operation
        signed_oci_image: Signed OCI image target (from wasm_component_signed_oci_image)
        registry_config: Registry configuration with authentication
        dry_run: Whether to perform a dry-run (default: False)
        visibility: Target visibility
        **kwargs: Additional arguments passed to wasm_component_publish
        
    Example:
        ```starlark
        wasm_component_secure_publish(
            name = "publish_secure_component",
            signed_oci_image = ":secure_component_image",
            registry_config = ":production_registry_config",
        )
        ```
    """
    
    wasm_component_publish(
        name = name,
        oci_image = signed_oci_image,
        dry_run = dry_run,
        visibility = visibility,
        **kwargs
    )

def wasm_component_verify_signatures(
        name,
        oci_image_ref,
        component_public_key = None,
        oci_public_key = None,
        cosign_verify = True,
        component_verify = True,
        visibility = None):
    """
    Verifies both component and OCI signatures for a published WebAssembly component.
    
    This rule creates verification tests that validate both layers of security:
    1. WASM component signature verification with wasmsign2
    2. OCI manifest signature verification with cosign
    
    Args:
        name: Target name for the verification test
        oci_image_ref: OCI image reference to verify
        component_public_key: Public key for component signature verification
        oci_public_key: Public key for OCI signature verification  
        cosign_verify: Whether to verify cosign signatures (default: True)
        component_verify: Whether to verify component signatures (default: True)
        visibility: Target visibility
        
    Example:
        ```starlark
        wasm_component_verify_signatures(
            name = "verify_secure_component",
            oci_image_ref = "ghcr.io/my-org/secure-component:v1.0.0",
            component_public_key = ":wasm_public_key",
            oci_public_key = ":cosign_public_key",
        )
        ```
    """
    
    # TODO: Implement verification logic
    # This would create test targets that:
    # 1. Pull the OCI image
    # 2. Verify cosign signature on manifest
    # 3. Extract WASM component
    # 4. Verify wasmsign2 signature on component
    # 5. Report verification results
    
    native.genrule(
        name = name,
        outs = [name + "_verification_result.txt"],
        cmd = """
        echo "Signature verification not yet implemented" > $@
        echo "TODO: Add cosign verify + wasmsign2 verify logic" >> $@
        """,
        visibility = visibility,
    )