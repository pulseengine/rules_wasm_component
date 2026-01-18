"""MoonBit WebAssembly CLI binary rule implementation.

Builds MoonBit code as WebAssembly CLI binaries that export wasi:cli/command,
suitable for execution with wasmtime. This is the MoonBit equivalent of
cpp_wasm_binary, rust_wasm_binary, and python_wasm_binary.

Example usage:

    moonbit_wasm(
        name = "hello_core",
        srcs = ["hello.mbt"],
        is_main = True,
    )

    moonbit_wasm_binary(
        name = "hello",
        lib = ":hello_core",
    )

    # Run with: wasmtime run bazel-bin/examples/hello.wasm
"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _moonbit_wasm_binary_impl(ctx):
    """Implementation of moonbit_wasm_binary rule.

    Takes compiled MoonBit WASM and creates a CLI command component by
    wrapping it with wasi:cli/command world metadata.

    Args:
        ctx: The rule context containing:
            - ctx.attr.lib: MoonBit WASM library target (moonbit_wasm output)

    Returns:
        List of providers:
        - WasmComponentInfo: Binary metadata
        - DefaultInfo: WASM binary file
    """

    # Get wasm-tools toolchain
    wasm_tools_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = wasm_tools_toolchain.wasm_tools

    # Get the core WASM from the moonbit_wasm target
    lib_info = ctx.attr.lib[DefaultInfo]
    core_wasm_files = lib_info.files.to_list()

    if not core_wasm_files:
        fail("No WASM file found in lib target. Ensure lib points to a moonbit_wasm target.")

    core_wasm = None
    for f in core_wasm_files:
        if f.extension == "wasm":
            core_wasm = f
            break

    if not core_wasm:
        fail("No .wasm file found in lib target outputs: {}".format([f.basename for f in core_wasm_files]))

    # Output component file
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Create a build script that embeds minimal WASI CLI WIT and creates component
    build_script = ctx.actions.declare_file(ctx.attr.name + "_build.sh")

    script_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "WASM_TOOLS=\"$1\"",
        "CORE_WASM=\"$2\"",
        "OUTPUT_WASM=\"$3\"",
        "",
        "# Create temporary workspace",
        "WORK_DIR=$(mktemp -d)",
        "trap 'rm -rf \"$WORK_DIR\"' EXIT",
        "",
        "# Create minimal WASI CLI WIT for command world",
        "mkdir -p \"$WORK_DIR/wit/deps/cli\"",
        "mkdir -p \"$WORK_DIR/wit/deps/io\"",
        "",
        "# Root world that includes wasi:cli/command",
        "cat > \"$WORK_DIR/wit/world.wit\" << 'WITEOF'",
        "package local:app@0.1.0;",
        "",
        "world app {",
        "  include wasi:cli/command@0.2.0;",
        "}",
        "WITEOF",
        "",
        "# WASI CLI package",
        "cat > \"$WORK_DIR/wit/deps/cli/command.wit\" << 'WITEOF'",
        "package wasi:cli@0.2.0;",
        "",
        "world command {",
        "  include imports;",
        "  export run;",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/cli/run.wit\" << 'WITEOF'",
        "interface run {",
        "  run: func() -> result;",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/cli/imports.wit\" << 'WITEOF'",
        "world imports {",
        "  import wasi:io/error@0.2.0;",
        "  import wasi:io/poll@0.2.0;",
        "  import wasi:io/streams@0.2.0;",
        "  import environment;",
        "  import exit;",
        "  import stdin;",
        "  import stdout;",
        "  import stderr;",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/cli/environment.wit\" << 'WITEOF'",
        "interface environment {",
        "  get-environment: func() -> list<tuple<string, string>>;",
        "  get-arguments: func() -> list<string>;",
        "  initial-cwd: func() -> option<string>;",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/cli/exit.wit\" << 'WITEOF'",
        "interface exit {",
        "  exit: func(status: result);",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/cli/stdio.wit\" << 'WITEOF'",
        "interface stdin {",
        "  use wasi:io/streams@0.2.0.{input-stream};",
        "  get-stdin: func() -> input-stream;",
        "}",
        "interface stdout {",
        "  use wasi:io/streams@0.2.0.{output-stream};",
        "  get-stdout: func() -> output-stream;",
        "}",
        "interface stderr {",
        "  use wasi:io/streams@0.2.0.{output-stream};",
        "  get-stderr: func() -> output-stream;",
        "}",
        "WITEOF",
        "",
        "# WASI IO package",
        "cat > \"$WORK_DIR/wit/deps/io/world.wit\" << 'WITEOF'",
        "package wasi:io@0.2.0;",
        "",
        "world imports {",
        "  import error;",
        "  import poll;",
        "  import streams;",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/io/error.wit\" << 'WITEOF'",
        "interface error {",
        "  resource error {",
        "    to-debug-string: func() -> string;",
        "  }",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/io/poll.wit\" << 'WITEOF'",
        "interface poll {",
        "  resource pollable {",
        "    ready: func() -> bool;",
        "    block: func();",
        "  }",
        "  poll: func(in: list<borrow<pollable>>) -> list<u32>;",
        "}",
        "WITEOF",
        "",
        "cat > \"$WORK_DIR/wit/deps/io/streams.wit\" << 'WITEOF'",
        "interface streams {",
        "  use error.{error};",
        "  use poll.{pollable};",
        "",
        "  variant stream-error {",
        "    last-operation-failed(error),",
        "    closed,",
        "  }",
        "",
        "  resource input-stream {",
        "    read: func(len: u64) -> result<list<u8>, stream-error>;",
        "    blocking-read: func(len: u64) -> result<list<u8>, stream-error>;",
        "    skip: func(len: u64) -> result<u64, stream-error>;",
        "    blocking-skip: func(len: u64) -> result<u64, stream-error>;",
        "    subscribe: func() -> pollable;",
        "  }",
        "",
        "  resource output-stream {",
        "    check-write: func() -> result<u64, stream-error>;",
        "    write: func(contents: list<u8>) -> result<_, stream-error>;",
        "    blocking-write-and-flush: func(contents: list<u8>) -> result<_, stream-error>;",
        "    flush: func() -> result<_, stream-error>;",
        "    blocking-flush: func() -> result<_, stream-error>;",
        "    subscribe: func() -> pollable;",
        "    write-zeroes: func(len: u64) -> result<_, stream-error>;",
        "    blocking-write-zeroes-and-flush: func(len: u64) -> result<_, stream-error>;",
        "    splice: func(src: borrow<input-stream>, len: u64) -> result<u64, stream-error>;",
        "    blocking-splice: func(src: borrow<input-stream>, len: u64) -> result<u64, stream-error>;",
        "  }",
        "}",
        "WITEOF",
        "",
        "# Embed WIT and create component",
        "EMBEDDED=\"$WORK_DIR/embedded.wasm\"",
        "\"$WASM_TOOLS\" component embed --world wasi:cli/command@0.2.0 \"$WORK_DIR/wit\" \"$CORE_WASM\" -o \"$EMBEDDED\"",
        "\"$WASM_TOOLS\" component new \"$EMBEDDED\" -o \"$OUTPUT_WASM\"",
        "",
        "echo 'MoonBit CLI binary built successfully'",
    ]

    ctx.actions.write(
        output = build_script,
        content = "\n".join(script_lines),
        is_executable = True,
    )

    # Run the build script
    ctx.actions.run(
        executable = build_script,
        arguments = [
            wasm_tools.path,
            core_wasm.path,
            component_wasm.path,
        ],
        inputs = [core_wasm, wasm_tools],
        outputs = [component_wasm],
        mnemonic = "MoonbitCliBinary",
        progress_message = "Building MoonBit CLI binary %s" % ctx.label,
        use_default_shell_env = True,
    )

    # Create WasmComponentInfo provider
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = struct(
            wit_file = None,
            package_name = "wasi:cli@0.2.0",
        ),
        component_type = "command",
        imports = [
            "wasi:cli/environment@0.2.0",
            "wasi:cli/exit@0.2.0",
            "wasi:cli/stdin@0.2.0",
            "wasi:cli/stdout@0.2.0",
            "wasi:cli/stderr@0.2.0",
        ],
        exports = ["wasi:cli/run@0.2.0"],
        metadata = {
            "name": ctx.label.name,
            "language": "moonbit",
            "target": "wasm32-wasi",
            "exec_model": "command",
        },
        profile = "release",
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(
            files = depset([component_wasm]),
            executable = component_wasm,
        ),
    ]

moonbit_wasm_binary = rule(
    implementation = _moonbit_wasm_binary_impl,
    executable = True,
    attrs = {
        "lib": attr.label(
            mandatory = True,
            doc = "MoonBit WASM library target (moonbit_wasm output with core WASM)",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
    ],
    doc = """Builds a WebAssembly CLI binary from MoonBit WASM output.

    Creates a WASI CLI command component that can be executed directly with
    `wasmtime run`. This is the MoonBit equivalent of rust_wasm_binary,
    cpp_wasm_binary, and python_wasm_binary.

    Example:
        moonbit_wasm(
            name = "hello_core",
            srcs = ["hello.mbt"],
            is_main = True,
        )

        moonbit_wasm_binary(
            name = "hello",
            lib = ":hello_core",
        )

        # Run with: wasmtime run bazel-bin/path/to/hello.wasm
    """,
)
