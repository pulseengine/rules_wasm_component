"""WebAssembly signing rules using wasmsign2"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmKeyInfo", "WasmSignatureInfo")

def _wasm_keygen_impl(ctx):
    """Implementation of wasm_keygen rule"""

    # Get wasmsign2 wrapper
    wasmsign2_wrapper = ctx.executable._wasmsign2_wrapper

    # Declare output files
    public_key = ctx.actions.declare_file(ctx.attr.public_key_name)
    secret_key = ctx.actions.declare_file(ctx.attr.secret_key_name)

    # Build command arguments
    args = ctx.actions.args()
    args.add("keygen")
    args.add("--public-key", public_key)
    args.add("--secret-key", secret_key)

    # Run key generation via Go wrapper
    # The wrapper handles symlink resolution and WASI directory mapping
    ctx.actions.run(
        executable = wasmsign2_wrapper,
        arguments = [args],
        outputs = [public_key, secret_key],
        mnemonic = "WasmKeyGen",
        progress_message = "Generating WASM signing keys %s" % ctx.label,
        execution_requirements = {
            "no-cache": "1",  # Key generation uses crypto randomness
        },
    )

    # Create key info provider
    # wasmsign2 keygen always generates compact format keys
    key_info = WasmKeyInfo(
        public_key = public_key,
        secret_key = secret_key,
        key_format = "compact",
        key_metadata = {
            "name": ctx.label.name,
            "algorithm": "EdDSA",
            "format": "compact",
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
        "_wasmsign2_wrapper": attr.label(
            default = "//tools/wasmsign2_wrapper",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """
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
    """,
)

def _wasm_sign_impl(ctx):
    """Implementation of wasm_sign rule"""

    # Get wasmsign2 wrapper
    wasmsign2_wrapper = ctx.executable._wasmsign2_wrapper

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

        # Determine if we should use OpenSSH format based on key format
        # ssh_keygen produces "openssh" format, wasm_keygen produces "compact" format
        openssh_format = key_info.key_format == "openssh"
    else:
        secret_key = ctx.file.secret_key
        public_key = ctx.file.public_key
        # When using raw key files, user must specify the format explicitly
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

    # Run signing via Go wrapper (maintains sandbox and cross-platform!)
    ctx.actions.run(
        executable = wasmsign2_wrapper,
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
            profile = component_info.profile,
            profile_variants = component_info.profile_variants,
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
        "_wasmsign2_wrapper": attr.label(
            default = "//tools/wasmsign2_wrapper",
            executable = True,
            cfg = "exec",
        ),
    },
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

    # Get wasmsign2 wrapper
    wasmsign2_wrapper = ctx.executable._wasmsign2_wrapper

    # Get input component
    if ctx.attr.signed_component:
        signature_info = ctx.attr.signed_component[WasmSignatureInfo]
        input_wasm = signature_info.signed_wasm
        signature_file = signature_info.signature_file
        # Infer OpenSSH format from signature metadata
        openssh_format = signature_info.signature_metadata.get("format") == "openssh"
    elif ctx.file.wasm_file:
        input_wasm = ctx.file.wasm_file
        signature_file = ctx.file.signature_file
        openssh_format = False  # Will be overridden if keys provider is used
    else:
        fail("Either signed_component or wasm_file must be specified")

    # Get public key and determine format
    if ctx.attr.keys:
        key_info = ctx.attr.keys[WasmKeyInfo]
        public_key = key_info.public_key
        # Override openssh_format if we have key info
        openssh_format = key_info.key_format == "openssh"
    else:
        public_key = ctx.file.public_key
        # When using raw public key file, user must specify format explicitly
        openssh_format = ctx.attr.openssh_format

    # Declare output verification marker
    verification_marker = ctx.actions.declare_file(ctx.label.name + "_verified.txt")

    # Build command arguments
    args = ctx.actions.args()
    args.add("verify")
    args.add("-i", input_wasm)

    # Add public key or GitHub account
    if public_key:
        args.add("-K", public_key)
    elif ctx.attr.github_account:
        args.add("-G", ctx.attr.github_account)
    else:
        fail("Either public_key, keys, or github_account must be specified")

    # Add detached signature if provided
    if signature_file:
        args.add("-S", signature_file)

    # Add OpenSSH format if needed
    if openssh_format:
        args.add("-Z")

    # Add partial verification if specified
    if ctx.attr.split_regex:
        args.add("-s", ctx.attr.split_regex)

    # Prepare inputs
    inputs = [input_wasm]
    if public_key:
        inputs.append(public_key)
    if signature_file:
        inputs.append(signature_file)

    # Run verification via Go wrapper (no shell scripts!)
    # The wrapper will create the marker file on success
    args.add("--bazel-marker-file=" + verification_marker.path)

    ctx.actions.run(
        executable = wasmsign2_wrapper,
        arguments = [args],
        inputs = inputs,
        outputs = [verification_marker],
        mnemonic = "WasmVerify",
        progress_message = "Verifying WASM signature %s" % ctx.label,
    )

    # Create verification info
    verification_info = WasmSignatureInfo(
        signed_wasm = input_wasm,
        signature_file = signature_file,
        public_key = public_key,
        secret_key = None,
        is_signed = True,
        signature_type = "detached" if signature_file else "embedded",
        signature_metadata = {
            "name": ctx.label.name,
        },
        verification_status = "checked",
    )

    return [
        verification_info,
        DefaultInfo(files = depset([verification_marker])),
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
        "_wasmsign2_wrapper": attr.label(
            default = "//tools/wasmsign2_wrapper",
            executable = True,
            cfg = "exec",
        ),
    },
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
