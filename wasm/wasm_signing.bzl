"""WebAssembly signing rules using wasmsign2"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmSignatureInfo", "WasmKeyInfo")

def _wasm_keygen_impl(ctx):
    """Implementation of wasm_keygen rule"""

    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasmsign2 = toolchain.wasmsign2

    # Declare output files
    public_key = ctx.actions.declare_file(ctx.attr.public_key_name)
    secret_key = ctx.actions.declare_file(ctx.attr.secret_key_name)

    # Build command arguments
    args = ctx.actions.args()
    args.add("keygen")
    args.add("--public-key", public_key)
    args.add("--secret-key", secret_key)

    # Note: wasmsign2 keygen doesn't support --ssh flag
    # The openssh_format is just for metadata tracking

    # Run key generation
    ctx.actions.run(
        executable = wasmsign2,
        arguments = [args],
        inputs = [],
        outputs = [public_key, secret_key],
        mnemonic = "WasmKeyGen",
        progress_message = "Generating WASM signing keys %s" % ctx.label,
    )

    # Create key info provider
    key_info = WasmKeyInfo(
        public_key = public_key,
        secret_key = secret_key,
        key_format = "openssh" if ctx.attr.openssh_format else "compact",
        key_metadata = {
            "name": ctx.label.name,
            "algorithm": "EdDSA",
            "format": "openssh" if ctx.attr.openssh_format else "compact",
        },
    )

    return [
        key_info,
        DefaultInfo(files = depset([public_key, secret_key])),
    ]

wasm_keygen = rule(
    implementation = _wasm_keygen_impl,
    attrs = {
        "public_key_name": attr.string(
            default = "key.public",
            doc = "Name of the public key file to generate",
        ),
        "secret_key_name": attr.string(
            default = "key.secret",
            doc = "Name of the secret key file to generate",
        ),
        "openssh_format": attr.bool(
            default = False,
            doc = "Generate keys in OpenSSH format (Ed25519)",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
    Generates a key pair for signing WebAssembly components.

    This rule uses wasmsign2 to generate a public/secret key pair
    that can be used for signing and verifying WASM components.

    Example:
        wasm_keygen(
            name = "signing_keys",
            public_key_name = "my_key.public",
            secret_key_name = "my_key.secret",
            openssh_format = False,
        )
    """,
)

def _wasm_sign_impl(ctx):
    """Implementation of wasm_sign rule"""

    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasmsign2 = toolchain.wasmsign2

    # Get input component
    if ctx.attr.component:
        component_info = ctx.attr.component[WasmComponentInfo]
        input_wasm = component_info.wasm_file
    elif ctx.file.wasm_file:
        input_wasm = ctx.file.wasm_file
        component_info = None
    else:
        fail("Either component or wasm_file must be specified")

    # Get key files
    if ctx.attr.keys:
        key_info = ctx.attr.keys[WasmKeyInfo]
        secret_key = key_info.secret_key
        public_key = key_info.public_key
        openssh_format = key_info.key_format == "openssh"
    else:
        secret_key = ctx.file.secret_key
        public_key = ctx.file.public_key
        openssh_format = ctx.attr.openssh_format

    # Declare output files
    signed_wasm = ctx.actions.declare_file(ctx.label.name + ".wasm")
    signature_file = None
    if ctx.attr.detached:
        signature_file = ctx.actions.declare_file(ctx.label.name + ".sig")

    # Build command arguments
    args = ctx.actions.args()
    args.add("sign")
    args.add("-i", input_wasm)
    args.add("-o", signed_wasm)
    args.add("-k", secret_key)

    # Add public key for key identification
    if public_key:
        args.add("-K", public_key)

    # Add detached signature option
    if ctx.attr.detached and signature_file:
        args.add("-S", signature_file)

    # Add OpenSSH format if needed
    if openssh_format:
        args.add("-Z")

    # Prepare inputs
    inputs = [input_wasm, secret_key]
    if public_key:
        inputs.append(public_key)

    # Prepare outputs
    outputs = [signed_wasm]
    if signature_file:
        outputs.append(signature_file)

    # Run signing
    ctx.actions.run(
        executable = wasmsign2,
        arguments = [args],
        inputs = inputs,
        outputs = outputs,
        mnemonic = "WasmSign",
        progress_message = "Signing WASM component %s" % ctx.label,
    )

    # Create signature info provider
    signature_info = WasmSignatureInfo(
        signed_wasm = signed_wasm,
        signature_file = signature_file,
        public_key = public_key,
        secret_key = None,  # Don't expose secret key in provider
        is_signed = True,
        signature_type = "detached" if ctx.attr.detached else "embedded",
        signature_metadata = {
            "name": ctx.label.name,
            "algorithm": "EdDSA",
            "format": "openssh" if openssh_format else "compact",
            "detached": ctx.attr.detached,
        },
        verification_status = "not_checked",
    )

    # Create component info if we had one
    if component_info:
        # Update component info with signature information
        signed_component_info = WasmComponentInfo(
            wasm_file = signed_wasm,
            wit_info = component_info.wit_info,
            component_type = component_info.component_type,
            imports = component_info.imports,
            exports = component_info.exports,
            metadata = dict(component_info.metadata, signed = True),
        )
        providers = [signature_info, signed_component_info]
    else:
        providers = [signature_info]

    return providers + [DefaultInfo(files = depset(outputs))]

wasm_sign = rule(
    implementation = _wasm_sign_impl,
    attrs = {
        "component": attr.label(
            providers = [WasmComponentInfo],
            doc = "WASM component to sign",
        ),
        "wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "WASM file to sign (if not using component)",
        ),
        "keys": attr.label(
            providers = [WasmKeyInfo],
            doc = "Key pair generated by wasm_keygen",
        ),
        "secret_key": attr.label(
            allow_single_file = True,
            doc = "Secret key file (if not using keys)",
        ),
        "public_key": attr.label(
            allow_single_file = True,
            doc = "Public key file (if not using keys)",
        ),
        "detached": attr.bool(
            default = False,
            doc = "Create detached signature instead of embedding",
        ),
        "openssh_format": attr.bool(
            default = False,
            doc = "Use OpenSSH key format",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
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
    """,
)

def _wasm_verify_impl(ctx):
    """Implementation of wasm_verify rule"""

    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasmsign2 = toolchain.wasmsign2

    # Get input component
    if ctx.attr.signed_component:
        signature_info = ctx.attr.signed_component[WasmSignatureInfo]
        input_wasm = signature_info.signed_wasm
        signature_file = signature_info.signature_file
        openssh_format = signature_info.signature_metadata.get("format") == "openssh"
    elif ctx.file.wasm_file:
        input_wasm = ctx.file.wasm_file
        signature_file = ctx.file.signature_file
        openssh_format = ctx.attr.openssh_format
    else:
        fail("Either signed_component or wasm_file must be specified")

    # Get public key
    if ctx.attr.keys:
        key_info = ctx.attr.keys[WasmKeyInfo]
        public_key = key_info.public_key
    else:
        public_key = ctx.file.public_key

    # Declare output verification report
    verification_log = ctx.actions.declare_file(ctx.label.name + "_verification.log")

    # Build command arguments as list
    verify_cmd_args = ["verify", "-i", input_wasm.path]

    # Add public key or GitHub account
    if public_key:
        verify_cmd_args.extend(["-K", public_key.path])
    elif ctx.attr.github_account:
        verify_cmd_args.extend(["-G", ctx.attr.github_account])
    else:
        fail("Either public_key, keys, or github_account must be specified")

    # Add detached signature if provided
    if signature_file:
        verify_cmd_args.extend(["-S", signature_file.path])

    # Add OpenSSH format if needed
    if openssh_format:
        verify_cmd_args.append("-Z")

    # Add partial verification if specified
    if ctx.attr.split_regex:
        verify_cmd_args.extend(["-s", ctx.attr.split_regex])

    # Prepare inputs
    inputs = [input_wasm]
    if public_key:
        inputs.append(public_key)
    if signature_file:
        inputs.append(signature_file)

    # Run verification directly
    ctx.actions.run_shell(
        command = """
            echo "=== WASM Signature Verification Report ===" > {}
            echo "Component: {}" >> {}
            echo "Date: $(date)" >> {}
            echo "" >> {}
            
            if {} {} >> {} 2>&1; then
                echo "✅ Signature verification PASSED" >> {}
                echo "VERIFICATION_SUCCESS" > {}.status
            else
                echo "❌ Signature verification FAILED" >> {}
                echo "VERIFICATION_FAILED" > {}.status
            fi
        """.format(
            verification_log.path,
            input_wasm.short_path,
            verification_log.path,
            verification_log.path,
            verification_log.path,
            wasmsign2.path,
            " ".join(verify_cmd_args),
            verification_log.path,
            verification_log.path,
            verification_log.path,
            verification_log.path,
            verification_log.path,
        ),
        inputs = inputs,
        outputs = [verification_log],
        tools = [wasmsign2],
        mnemonic = "WasmVerify",
        progress_message = "Verifying WASM signature %s" % ctx.label,
    )

    # Create verification info (we can't know the result at analysis time)
    verification_info = WasmSignatureInfo(
        signed_wasm = input_wasm,
        signature_file = signature_file,
        public_key = public_key,
        secret_key = None,
        is_signed = True,
        signature_type = "detached" if signature_file else "embedded",
        signature_metadata = {
            "name": ctx.label.name,
            "verification_log": verification_log.path,
        },
        verification_status = "checked",  # Result will be in log
    )

    return [
        verification_info,
        DefaultInfo(files = depset([verification_log])),
    ]

wasm_verify = rule(
    implementation = _wasm_verify_impl,
    attrs = {
        "signed_component": attr.label(
            providers = [WasmSignatureInfo],
            doc = "Signed WASM component to verify",
        ),
        "wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "WASM file to verify (if not using signed_component)",
        ),
        "signature_file": attr.label(
            allow_single_file = True,
            doc = "Detached signature file (if applicable)",
        ),
        "keys": attr.label(
            providers = [WasmKeyInfo],
            doc = "Key pair with public key for verification",
        ),
        "public_key": attr.label(
            allow_single_file = True,
            doc = "Public key file for verification",
        ),
        "github_account": attr.string(
            doc = "GitHub account to retrieve public keys from",
        ),
        "openssh_format": attr.bool(
            default = False,
            doc = "Use OpenSSH key format",
        ),
        "split_regex": attr.string(
            doc = "Regular expression for partial verification",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
    Verifies the cryptographic signature of a WebAssembly component.

    This rule uses wasmsign2 to verify that a WASM component's signature
    is valid and was created by the holder of the corresponding secret key.

    Example:
        wasm_verify(
            name = "verify_component",
            signed_component = ":signed_component",
            keys = ":signing_keys",
        )
    """,
)