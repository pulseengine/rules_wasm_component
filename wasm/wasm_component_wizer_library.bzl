"""Wizer pre-initialization rule for WebAssembly components.

As of Wasmtime v39.0.0 (November 2025), the standalone Wizer tool has been
merged upstream into Wasmtime. This rule uses `wasmtime wizer` subcommand
for proper component model support.

See: https://github.com/bytecodealliance/wasmtime/releases/tag/v39.0.0
"""

def _wasm_component_wizer_library_impl(ctx):
    """Implementation using wasmtime wizer for proper component model support"""

    # Input and output files
    input_wasm = ctx.file.component
    output_wasm = ctx.outputs.wizer_component

    # Get Wasmtime toolchain (wizer is now part of wasmtime as of v39.0.0)
    wasmtime_toolchain = ctx.toolchains["//toolchains:wasmtime_toolchain_type"]
    wasmtime = wasmtime_toolchain.wasmtime

    # Build wasmtime wizer command arguments
    args = ctx.actions.args()
    args.add("wizer")  # wasmtime subcommand
    args.add("--init-func", ctx.attr.init_function_name)

    if ctx.attr.allow_wasi:
        args.add("--allow-wasi")

    # Add output and input
    args.add("-o", output_wasm.path)
    args.add(input_wasm.path)

    # Run wasmtime wizer
    ctx.actions.run(
        executable = wasmtime,
        arguments = [args],
        inputs = [input_wasm],
        outputs = [output_wasm],
        mnemonic = "WasmtimeWizerLib",
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

wasm_component_wizer_library = rule(
    implementation = _wasm_component_wizer_library_impl,
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
        "allow_wasi": attr.bool(
            default = True,
            doc = "Allow WASI calls during initialization",
        ),
        "verbose": attr.bool(
            default = False,
            doc = "Enable verbose output (currently unused, kept for API compatibility)",
        ),
    },
    outputs = {
        "wizer_component": "%{name}_wizer.wasm",
    },
    toolchains = ["//toolchains:wasmtime_toolchain_type"],
    doc = """Pre-initialize a WebAssembly component using wasmtime wizer.

    This rule uses wasmtime's built-in wizer subcommand to properly handle
    WebAssembly components with full component model support.

    As of Wasmtime v39.0.0 (November 2025), the standalone Wizer tool has been
    merged upstream into Wasmtime, providing better maintenance and integration.

    This approach provides proper component model support and integrates well
    with Wasmtime runtime for initialization.

    Note: The default init function name changed from 'wizer.initialize' to
    'wizer-initialize' in wasmtime v39.0.0 for better component model compatibility.

    Example:
        wasm_component_wizer_library(
            name = "optimized_component",
            component = ":my_component",
            init_function_name = "wizer-initialize",
            allow_wasi = True,
        )
    """,
)
