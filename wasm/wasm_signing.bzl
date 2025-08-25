"""WebAssembly signing rules using wasmsign2"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmKeyInfo", "WasmSignatureInfo")

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
            doc = "Metadata flag for OpenSSH format preference. Note: wasmsign2 keygen always generates keys in its own compact format, not OpenSSH format. This flag is kept for metadata tracking only.",
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

        # Use the actual key format from the key info
        # ssh_keygen produces "openssh" format, wasm_keygen produces "compact" format
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

    # Create verification script for better error handling and cross-platform compatibility
    verify_script = ctx.actions.declare_file(ctx.label.name + "_verify.py")
    script_content = '''#!/usr/bin/env python3
import subprocess
import sys
import datetime

def main():
    wasmsign2_path = sys.argv[1]
    log_path = sys.argv[2]
    component_path = sys.argv[3]
    verify_args = sys.argv[4:]

    # Create verification report header
    report_lines = [
        "=== WASM Signature Verification Report ===",
        f"Component: {component_path}",
        f"Date: {datetime.datetime.now().isoformat()}",
        f"Verification Command: {wasmsign2_path} {' '.join(verify_args)}",
        ""
    ]

    try:
        # Run verification command
        result = subprocess.run(
            [wasmsign2_path] + verify_args,
            capture_output=True,
            text=True,
            timeout=60
        )

        # Add verification output to report
        if result.stdout:
            report_lines.extend([
                "=== Verification Output ===",
                result.stdout,
                ""
            ])

        if result.stderr:
            report_lines.extend([
                "=== Error Output ===",
                result.stderr,
                ""
            ])

        # Add result
        if result.returncode == 0:
            report_lines.append("✅ Signature verification PASSED")
            status = "VERIFICATION_SUCCESS"
        else:
            report_lines.append("❌ Signature verification FAILED")
            status = "VERIFICATION_FAILED"

    except subprocess.TimeoutExpired:
        report_lines.extend([
            "❌ Signature verification TIMED OUT",
            "Verification process exceeded 60 second timeout"
        ])
        status = "VERIFICATION_TIMEOUT"
    except Exception as e:
        report_lines.extend([
            "❌ Signature verification ERROR",
            f"Error: {str(e)}"
        ])
        status = "VERIFICATION_ERROR"

    # Write verification log
    with open(log_path, 'w') as f:
        f.write('\\n'.join(report_lines))

    # Write status file for programmatic access
    with open(log_path + '.status', 'w') as f:
        f.write(status)

    print(f"Verification complete: {status}")

if __name__ == "__main__":
    main()
'''

    ctx.actions.write(
        output = verify_script,
        content = script_content,
        is_executable = True,
    )

    # Run verification using the structured script
    ctx.actions.run(
        executable = verify_script,
        arguments = [wasmsign2.path, verification_log.path, input_wasm.short_path] + verify_cmd_args,
        inputs = inputs + [verify_script],
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
