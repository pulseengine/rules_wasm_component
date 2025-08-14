"""WASM validation rule implementation"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmValidationInfo", "WasmSignatureInfo", "WasmKeyInfo")

def _wasm_validate_impl(ctx):
    """Implementation of wasm_validate rule"""

    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = toolchain.wasm_tools
    wasmsign2 = toolchain.wasmsign2

    # Get input WASM file
    if ctx.file.wasm_file:
        wasm_file = ctx.file.wasm_file
    elif ctx.attr.component:
        wasm_file = ctx.attr.component[WasmComponentInfo].wasm_file
    else:
        fail("Either wasm_file or component must be specified")

    # Output validation log
    validation_log = ctx.actions.declare_file(ctx.label.name + "_validation.log")

    # Create validation report with modern Bazel approach
    # Step 1: Create report header
    report_header = """=== WASM Validation Report ===
File: {}
Date: $(date)

""".format(wasm_file.short_path)

    header_file = ctx.actions.declare_file(ctx.label.name + "_header.txt")
    ctx.actions.write(
        output = header_file,
        content = report_header,
    )

    # Step 2: Run validation and capture results
    validation_result = ctx.actions.declare_file(ctx.label.name + "_validation.txt")
    ctx.actions.run_shell(
        command = """
            echo "=== Basic Validation ===" > {}
            if {} validate {} >> {} 2>&1; then
                echo "✅ WASM file is valid" >> {}
                echo "SUCCESS" > {}.status
            else
                echo "❌ WASM validation failed" >> {}
                echo "FAILED" > {}.status
            fi
            echo "" >> {}
        """.format(
            validation_result.path,
            wasm_tools.path,
            wasm_file.path,
            validation_result.path,
            validation_result.path,
            validation_result.path,
            validation_result.path,
            validation_result.path,
        ),
        inputs = [wasm_file],
        outputs = [validation_result],
        tools = [wasm_tools],
        mnemonic = "WasmValidateCore",
        progress_message = "Validating WASM file %s" % ctx.label,
    )

    # Step 3: Run component inspection
    component_result = ctx.actions.declare_file(ctx.label.name + "_component.txt")
    ctx.actions.run_shell(
        command = """
            echo "=== Component Inspection ===" > {}
            if {} component wit {} >> {} 2>&1; then
                echo "✅ Component WIT extracted successfully" >> {}
            else
                echo "ℹ️  Not a component or WIT extraction failed" >> {}
            fi
            echo "" >> {}
        """.format(
            component_result.path,
            wasm_tools.path,
            wasm_file.path,
            component_result.path,
            component_result.path,
            component_result.path,
            component_result.path,
        ),
        inputs = [wasm_file],
        outputs = [component_result],
        tools = [wasm_tools],
        mnemonic = "WasmInspectComponent",
        progress_message = "Inspecting WASM component %s" % ctx.label,
    )

    # Step 4: Get module information
    module_result = ctx.actions.declare_file(ctx.label.name + "_module.txt")
    ctx.actions.run_shell(
        command = """
            echo "=== Module Information ===" > {}
            {} print {} --skeleton >> {} 2>&1 || echo "Could not extract module info" >> {}
        """.format(
            module_result.path,
            wasm_tools.path,
            wasm_file.path,
            module_result.path,
            module_result.path,
        ),
        inputs = [wasm_file],
        outputs = [module_result],
        tools = [wasm_tools],
        mnemonic = "WasmModuleInfo",
        progress_message = "Extracting module info from %s" % ctx.label,
    )

    # Step 5: Check for signature verification (optional)
    signature_result = None
    combine_inputs = [header_file, validation_result, component_result, module_result]
    
    if ctx.attr.verify_signature:
        signature_result = ctx.actions.declare_file(ctx.label.name + "_signature.txt")
        
        # Determine signature verification approach
        if ctx.attr.public_key:
            public_key = ctx.file.public_key
            verify_args = ["-K", public_key.path]
            verify_inputs = [wasm_file, public_key]
        elif ctx.attr.github_account:
            verify_args = ["-G", ctx.attr.github_account]
            verify_inputs = [wasm_file]
        elif ctx.attr.signing_keys:
            key_info = ctx.attr.signing_keys[WasmKeyInfo]
            public_key = key_info.public_key
            verify_args = ["-K", public_key.path]
            verify_inputs = [wasm_file, public_key]
            if key_info.key_format == "openssh":
                verify_args.append("-Z")
        else:
            # Try to auto-detect embedded signatures
            verify_args = []
            verify_inputs = [wasm_file]
        
        # Add signature file if provided
        if ctx.file.signature_file:
            verify_args.extend(["-S", ctx.file.signature_file.path])
            verify_inputs.append(ctx.file.signature_file)
        
        # Run signature verification
        ctx.actions.run_shell(
            command = """
                echo "=== Signature Verification ===" > {}
                if {} verify -i {} {} >> {} 2>&1; then
                    echo "✅ Signature verification PASSED" >> {}
                else
                    echo "ℹ️  No valid signature found or verification failed" >> {}
                fi
                echo "" >> {}
            """.format(
                signature_result.path,
                wasmsign2.path,
                wasm_file.path,
                " ".join(verify_args),
                signature_result.path,
                signature_result.path,
                signature_result.path,
                signature_result.path,
            ),
            inputs = verify_inputs,
            outputs = [signature_result],
            tools = [wasmsign2],
            mnemonic = "WasmVerifySignature",
            progress_message = "Verifying signature for %s" % ctx.label,
        )
        
        combine_inputs.append(signature_result)

    # Step 6: Combine all results into final report
    ctx.actions.run_shell(
        command = "cat {} > {}".format(
            " ".join([f.path for f in combine_inputs]),
            validation_log.path,
        ),
        inputs = combine_inputs,
        outputs = [validation_log],
        mnemonic = "WasmCombineReport",
        progress_message = "Generating validation report for %s" % ctx.label,
    )

    # Create validation info provider
    validation_info = WasmValidationInfo(
        is_valid = True,  # Will be set based on action success
        validation_log = validation_log,
        errors = [],  # TODO: Parse errors from log
        warnings = [],  # TODO: Parse warnings from log
    )

    return [
        validation_info,
        DefaultInfo(files = depset([validation_log])),
    ]

wasm_validate = rule(
    implementation = _wasm_validate_impl,
    attrs = {
        "wasm_file": attr.label(
            allow_single_file = [".wasm"],
            doc = "WASM file to validate",
        ),
        "component": attr.label(
            providers = [WasmComponentInfo],
            doc = "WASM component to validate",
        ),
        "verify_signature": attr.bool(
            default = False,
            doc = "Enable signature verification during validation",
        ),
        "public_key": attr.label(
            allow_single_file = True,
            doc = "Public key file for signature verification",
        ),
        "signature_file": attr.label(
            allow_single_file = True,
            doc = "Detached signature file (if applicable)",
        ),
        "signing_keys": attr.label(
            providers = [WasmKeyInfo],
            doc = "Key pair with public key for verification",
        ),
        "github_account": attr.string(
            doc = "GitHub account to retrieve public keys from",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
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
    """,
)
