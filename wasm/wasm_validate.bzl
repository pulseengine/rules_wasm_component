"""WASM validation rule implementation"""

load("//providers:providers.bzl", "WasmComponentInfo", "WasmValidationInfo")

def _wasm_validate_impl(ctx):
    """Implementation of wasm_validate rule"""

    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = toolchain.wasm_tools

    # Get input WASM file
    if ctx.file.wasm_file:
        wasm_file = ctx.file.wasm_file
    elif ctx.attr.component:
        wasm_file = ctx.attr.component[WasmComponentInfo].wasm_file
    else:
        fail("Either wasm_file or component must be specified")

    # Output validation log
    validation_log = ctx.actions.declare_file(ctx.label.name + "_validation.log")

    # Run validation
    ctx.actions.run_shell(
        inputs = [wasm_file],
        outputs = [validation_log],
        tools = [wasm_tools],
        command = """
            set +e  # Don't exit on validation errors
            
            echo "=== WASM Validation Report ===" > {log}
            echo "File: {wasm_file}" >> {log}
            echo "Size: $(wc -c < {wasm_file}) bytes" >> {log}
            echo "Date: $(date)" >> {log}
            echo "" >> {log}
            
            # Basic validation
            echo "=== Basic Validation ===" >> {log}
            if {wasm_tools} validate {wasm_file} 2>&1; then
                echo "✅ WASM file is valid" >> {log}
                VALID=true
            else
                echo "❌ WASM validation failed" >> {log}
                VALID=false
            fi
            echo "" >> {log}
            
            # Component inspection (if it's a component)
            echo "=== Component Inspection ===" >> {log}
            if {wasm_tools} component wit {wasm_file} >> {log} 2>&1; then
                echo "✅ Component WIT extracted successfully" >> {log}
            else
                echo "ℹ️  Not a component or WIT extraction failed" >> {log}
            fi
            echo "" >> {log}
            
            # Module info
            echo "=== Module Information ===" >> {log}
            {wasm_tools} print {wasm_file} --skeleton >> {log} 2>&1 || echo "Could not extract module info" >> {log}
            
            # Set exit code based on validation result
            if [ "$VALID" = "true" ]; then
                exit 0
            else
                exit 1
            fi
        """.format(
            wasm_tools = wasm_tools.path,
            wasm_file = wasm_file.path,
            log = validation_log.path,
        ),
        mnemonic = "WasmValidate",
        progress_message = "Validating WASM file %s" % ctx.label,
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
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
    Validates a WebAssembly file or component.
    
    This rule uses wasm-tools to validate WASM files and extract
    information about components, imports, exports, etc.
    
    Example:
        wasm_validate(
            name = "validate_my_component",
            component = ":my_component",
        )
        
        wasm_validate(
            name = "validate_wasm_file",
            wasm_file = "my_file.wasm",
        )
    """,
)
