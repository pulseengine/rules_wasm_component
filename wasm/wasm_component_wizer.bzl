"""Wizer pre-initialization rule for WebAssembly components"""

def _wasm_component_wizer_impl(ctx):
    """Implementation of wasm_component_wizer rule"""

    # Get Wizer toolchain
    wizer_toolchain = ctx.toolchains["//toolchains:wizer_toolchain_type"]
    wizer = wizer_toolchain.wizer

    # Input and output files
    input_wasm = ctx.file.component
    output_wasm = ctx.outputs.wizer_component

    # Create initialization script if provided
    init_script = None
    if ctx.attr.init_script:
        init_script = ctx.file.init_script

    # Build Wizer command arguments
    args = ctx.actions.args()
    args.add("--allow-wasi")  # Allow WASI imports during initialization
    args.add("--inherit-stdio", "true")  # Inherit stdio for debugging if needed

    # Add custom initialization function name if specified
    if ctx.attr.init_function_name:
        args.add("--init-func", ctx.attr.init_function_name)
    else:
        args.add("--init-func", "wizer.initialize")  # Default function name

    # Add input and output files
    args.add("-o", output_wasm.path)
    args.add(input_wasm.path)

    # Create action inputs list
    inputs = [input_wasm]
    if init_script:
        inputs.append(init_script)

    # Run Wizer pre-initialization
    ctx.actions.run(
        executable = wizer,
        arguments = [args],
        inputs = inputs,
        outputs = [output_wasm],
        mnemonic = "WizerPreInit",
        progress_message = "Pre-initializing WebAssembly component with Wizer: {}".format(
            input_wasm.short_path,
        ),
        use_default_shell_env = False,
        env = {
            "RUST_BACKTRACE": "1",  # Enable Rust backtraces for debugging
        },
    )

    # Return providers
    return [
        DefaultInfo(
            files = depset([output_wasm]),
            runfiles = ctx.runfiles(files = [output_wasm]),
        ),
        OutputGroupInfo(
            wizer_component = depset([output_wasm]),
        ),
    ]

wasm_component_wizer = rule(
    implementation = _wasm_component_wizer_impl,
    attrs = {
        "component": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "Input WebAssembly component to pre-initialize",
        ),
        "init_function_name": attr.string(
            default = "wizer.initialize",
            doc = "Name of the initialization function to call (default: wizer.initialize)",
        ),
        "init_script": attr.label(
            allow_single_file = True,
            doc = "Optional initialization script or data file",
        ),
    },
    outputs = {
        "wizer_component": "%{name}_wizer.wasm",
    },
    toolchains = ["//toolchains:wizer_toolchain_type"],
    doc = """Pre-initialize a WebAssembly component with Wizer.

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
    """,
)

def _wizer_chain_impl(ctx):
    """Implementation of wizer_chain rule for chaining with existing component rules"""

    # Get the original component target
    original_target = ctx.attr.component
    original_files = original_target[DefaultInfo].files.to_list()

    if len(original_files) != 1:
        fail("wizer_chain component must produce exactly one .wasm file, got: {}".format(
            [f.path for f in original_files],
        ))

    component_file = original_files[0]

    # Get Wizer toolchain
    wizer_toolchain = ctx.toolchains["//toolchains:wizer_toolchain_type"]
    wizer = wizer_toolchain.wizer

    # Output file
    output_wasm = ctx.outputs.wizer_component

    # Build Wizer arguments
    args = ctx.actions.args()
    args.add("--allow-wasi")
    args.add("--inherit-stdio", "true")

    if ctx.attr.init_function_name:
        args.add("--init-func", ctx.attr.init_function_name)
    else:
        args.add("--init-func", "wizer.initialize")

    args.add("-o", output_wasm.path)
    args.add(component_file.path)

    # Run Wizer
    ctx.actions.run(
        executable = wizer,
        arguments = [args],
        inputs = [component_file],
        outputs = [output_wasm],
        mnemonic = "WizerChain",
        progress_message = "Wizer pre-initializing component: {}".format(ctx.label.name),
        use_default_shell_env = False,
        env = {"RUST_BACKTRACE": "1"},
    )

    return [
        DefaultInfo(
            files = depset([output_wasm]),
            runfiles = ctx.runfiles(files = [output_wasm]),
        ),
    ]

wizer_chain = rule(
    implementation = _wizer_chain_impl,
    attrs = {
        "component": attr.label(
            mandatory = True,
            doc = "WebAssembly component target to pre-initialize",
        ),
        "init_function_name": attr.string(
            default = "wizer.initialize",
            doc = "Name of the initialization function",
        ),
    },
    outputs = {
        "wizer_component": "%{name}_wizer.wasm",
    },
    toolchains = ["//toolchains:wizer_toolchain_type"],
    doc = """Chain Wizer pre-initialization after an existing component rule.

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
    """,
)
