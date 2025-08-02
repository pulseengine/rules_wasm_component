"""Wizer library-based pre-initialization rule for WebAssembly components"""

def _wasm_component_wizer_library_impl(ctx):
    """Implementation using Wizer library for proper component model support"""

    # Input and output files
    input_wasm = ctx.file.component
    output_wasm = ctx.outputs.wizer_component

    # Get the wizer_initializer tool
    wizer_initializer = ctx.executable._wizer_initializer

    # Build command arguments
    args = ctx.actions.args()
    args.add("--input", input_wasm)
    args.add("--output", output_wasm)
    args.add("--init-func", ctx.attr.init_function_name)

    if ctx.attr.allow_wasi:
        args.add("--allow-wasi")

    if ctx.attr.verbose:
        args.add("--verbose")

    # Run the wizer library initializer
    ctx.actions.run(
        executable = wizer_initializer,
        arguments = [args],
        inputs = [input_wasm],
        outputs = [output_wasm],
        mnemonic = "WizerLibraryInit",
        progress_message = "Pre-initializing WebAssembly component with Wizer library: {}".format(
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

wasm_component_wizer_library = rule(
    implementation = _wasm_component_wizer_library_impl,
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
        "allow_wasi": attr.bool(
            default = True,
            doc = "Allow WASI calls during initialization",
        ),
        "verbose": attr.bool(
            default = False,
            doc = "Enable verbose output",
        ),
        "_wizer_initializer": attr.label(
            default = "//tools/wizer_initializer:wizer_initializer",
            executable = True,
            cfg = "exec",
        ),
    },
    outputs = {
        "wizer_component": "%{name}_wizer.wasm",
    },
    doc = """Pre-initialize a WebAssembly component using Wizer library.

    This rule uses Wizer as a library (rather than CLI tool) to properly handle
    WebAssembly components. The workflow is:

    1. Parse component to extract core module
    2. Apply Wizer pre-initialization to the core module
    3. Wrap the initialized module back as a component

    This approach provides proper component model support and integrates well
    with Wasmtime runtime for initialization.

    Example:
        wasm_component_wizer_library(
            name = "optimized_component",
            component = ":my_component",
            init_function_name = "wizer.initialize",
            allow_wasi = True,
        )
    """,
)
