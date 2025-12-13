"""Wizer pre-initialization rule for WebAssembly components.

As of Wasmtime v39.0.0 (November 2025), the standalone Wizer tool has been
merged upstream into Wasmtime. This rule now uses `wasmtime wizer` subcommand
instead of the standalone wizer binary for better maintenance and component
model support.

See: https://github.com/bytecodealliance/wasmtime/releases/tag/v39.0.0
"""

def _wasm_component_wizer_impl(ctx):
    """Implementation of wasm_component_wizer rule using wasmtime wizer subcommand"""

    # Get Wasmtime toolchain (wizer is now part of wasmtime)
    wasmtime_toolchain = ctx.toolchains["//toolchains:wasmtime_toolchain_type"]
    wasmtime = wasmtime_toolchain.wasmtime

    # Input and output files
    input_wasm = ctx.file.component
    output_wasm = ctx.outputs.wizer_component

    # Build wasmtime wizer command arguments
    # Format: wasmtime wizer [OPTIONS] <INPUT> -o <OUTPUT>
    args = ctx.actions.args()
    args.add("wizer")  # wasmtime subcommand
    args.add("--allow-wasi")  # Allow WASI imports during initialization

    # Add custom initialization function name if specified
    # Note: As of wasmtime v39.0.0, the default function name changed from
    # "wizer.initialize" to "wizer-initialize" for better component compatibility
    if ctx.attr.init_function_name:
        args.add("--init-func", ctx.attr.init_function_name)
    else:
        args.add("--init-func", "wizer-initialize")  # New default function name

    # Add output file
    args.add("-o", output_wasm.path)

    # Add input file
    args.add(input_wasm.path)

    # Create action inputs list
    inputs = [input_wasm]

    # Run wasmtime wizer pre-initialization
    ctx.actions.run(
        executable = wasmtime,
        arguments = [args],
        inputs = inputs,
        outputs = [output_wasm],
        mnemonic = "WasmtimeWizer",
        progress_message = "Pre-initializing WebAssembly component with wasmtime wizer: {}".format(
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
            default = "wizer-initialize",
            doc = "Name of the initialization function to call (default: wizer-initialize). " +
                  "Note: Prior to wasmtime v39.0.0, the default was 'wizer.initialize'.",
        ),
    },
    outputs = {
        "wizer_component": "%{name}_wizer.wasm",
    },
    toolchains = ["//toolchains:wasmtime_toolchain_type"],
    doc = """Pre-initialize a WebAssembly component with wasmtime wizer.

    This rule takes a WebAssembly component and runs Wizer pre-initialization on it,
    which can provide 1.35-6x startup performance improvements by running initialization
    code at build time rather than runtime.

    As of Wasmtime v39.0.0 (November 2025), the standalone Wizer tool has been merged
    upstream into Wasmtime. This rule uses the `wasmtime wizer` subcommand.

    The input component must export a function named 'wizer-initialize' (or the name
    specified in init_function_name) that performs the initialization work.

    Note: The default init function name changed from 'wizer.initialize' to
    'wizer-initialize' in wasmtime v39.0.0 for better component model compatibility.

    Example:
        wasm_component_wizer(
            name = "optimized_component",
            component = ":my_component",
            init_function_name = "wizer-initialize",
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

    # Get Wasmtime toolchain (wizer is now part of wasmtime as of v39.0.0)
    wasmtime_toolchain = ctx.toolchains["//toolchains:wasmtime_toolchain_type"]
    wasmtime = wasmtime_toolchain.wasmtime

    # Output file
    output_wasm = ctx.outputs.wizer_component

    # Build wasmtime wizer arguments
    args = ctx.actions.args()
    args.add("wizer")  # wasmtime subcommand
    args.add("--allow-wasi")

    if ctx.attr.init_function_name:
        args.add("--init-func", ctx.attr.init_function_name)
    else:
        args.add("--init-func", "wizer-initialize")

    # Add output and input
    args.add("-o", output_wasm.path)
    args.add(component_file.path)

    # Run wasmtime wizer
    ctx.actions.run(
        executable = wasmtime,
        arguments = [args],
        inputs = [component_file],
        outputs = [output_wasm],
        mnemonic = "WasmtimeWizerChain",
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
            default = "wizer-initialize",
            doc = "Name of the initialization function (default: wizer-initialize)",
        ),
    },
    outputs = {
        "wizer_component": "%{name}_wizer.wasm",
    },
    toolchains = ["//toolchains:wasmtime_toolchain_type"],
    doc = """Chain Wizer pre-initialization after an existing component rule.

    This is a convenience rule that takes the output of another component-building
    rule and applies Wizer pre-initialization to it using wasmtime wizer.

    As of Wasmtime v39.0.0 (November 2025), the standalone Wizer tool has been merged
    upstream into Wasmtime. This rule uses the `wasmtime wizer` subcommand.

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
