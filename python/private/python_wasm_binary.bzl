"""Python WebAssembly CLI binary rule implementation.

Builds Python code as WebAssembly CLI binaries that export wasi:cli/command,
suitable for execution with wasmtime. This is the Python equivalent of
cpp_wasm_binary and rust_wasm_binary.

Example usage:

    python_wasm_binary(
        name = "hello",
        srcs = ["app.py"],
    )

    # Run with: wasmtime run bazel-bin/examples/hello.wasm

The Python code must implement the Run.run() pattern:

    from wit_world import exports

    class Run(exports.Run):
        def run(self) -> None:
            print("Hello, world!")
"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _python_wasm_binary_impl(ctx):
    """Implementation of python_wasm_binary rule.

    Compiles Python source code into a WebAssembly CLI binary using componentize-py
    targeting the wasi:cli/command world.

    Args:
        ctx: The rule context containing:
            - ctx.files.srcs: Python source files
            - ctx.attr.entry_point: Main Python module (default: first .py file or app.py)

    Returns:
        List of providers:
        - WasmComponentInfo: Binary metadata
        - DefaultInfo: WASM binary file
    """

    # Get componentize-py toolchain
    py_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:componentize_py_toolchain_type"]
    componentize_py = py_toolchain.componentize_py

    # Output component file
    wasm_binary = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Input source files
    source_files = ctx.files.srcs

    # Find the entry point file
    entry_point = ctx.attr.entry_point
    entry_point_file = None

    if entry_point:
        for src in source_files:
            if src.basename == entry_point or src.path.endswith(entry_point):
                entry_point_file = src
                break
    else:
        # Auto-detect: use app.py, main.py, or first .py file
        priority_names = ["app.py", "main.py", "__init__.py"]
        for name in priority_names:
            for src in source_files:
                if src.basename == name:
                    entry_point_file = src
                    break
            if entry_point_file:
                break

        if not entry_point_file and source_files:
            for src in source_files:
                if src.extension == "py":
                    entry_point_file = src
                    break

    if not entry_point_file:
        fail("No Python entry point found. Specify entry_point or add a .py file to srcs.")

    # Create build script
    build_script = ctx.actions.declare_file(ctx.attr.name + "_build.sh")

    # Get module name (without .py extension)
    module_name = entry_point_file.basename
    if module_name.endswith(".py"):
        module_name = module_name[:-3]

    # Embed minimal WASI CLI WIT files matching componentize-py's expected format
    # This avoids complex WIT package assembly from external deps
    script_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "# Save original directory for absolute paths",
        "ORIGINAL_DIR=\"$(pwd)\"",
        "",
        "# Create temporary workspace",
        "WORK_DIR=$(mktemp -d)",
        "trap 'rm -rf \"$WORK_DIR\"' EXIT",
        "",
        "# Create WIT directory structure matching componentize-py format",
        "mkdir -p \"$WORK_DIR/wit/deps/cli\"",
        "mkdir -p \"$WORK_DIR/wit/deps/io\"",
        "",
        "# Create root world that references wasi:cli/command",
        "cat > \"$WORK_DIR/wit/world.wit\" << 'WITEOF'",
        "package local:app@0.1.0;",
        "",
        "world app {",
        "  include wasi:cli/command@0.2.0;",
        "}",
        "WITEOF",
        "",
        "# Create WASI CLI package WIT files",
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
        "# Create WASI IO package WIT files",
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
        "# Copy Python source files",
    ]

    for src in source_files:
        script_lines.append("cp \"$ORIGINAL_DIR/{}\" \"$WORK_DIR/{}\"".format(
            src.path, src.basename))

    script_lines.extend([
        "",
        "# Change to workspace",
        "cd \"$WORK_DIR\"",
        "",
        "# Run componentize-py targeting wasi:cli/command",
        "\"$ORIGINAL_DIR/{}\" \\".format(componentize_py.path),
        "  -d \"$WORK_DIR/wit\" \\",
        "  -w wasi:cli/command@0.2.0 \\",
        "  componentize \"{}\" \\".format(module_name),
        "  -p . \\",
        "  -o \"$ORIGINAL_DIR/{}\"".format(wasm_binary.path),
        "",
        "echo 'Python CLI binary built successfully'",
    ])

    ctx.actions.write(
        output = build_script,
        content = "\n".join(script_lines),
        is_executable = True,
    )

    # Collect all inputs (WIT files are embedded in the script)
    all_inputs = list(source_files) + [componentize_py]

    # Run the build script
    ctx.actions.run(
        executable = build_script,
        inputs = all_inputs,
        outputs = [wasm_binary],
        mnemonic = "ComponentizePyCLI",
        progress_message = "Building Python CLI binary %s with componentize-py" % ctx.label,
        use_default_shell_env = True,
    )

    # Create WasmComponentInfo provider
    component_info = WasmComponentInfo(
        wasm_file = wasm_binary,
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
            "language": "python",
            "target": "wasm32-wasi",
            "componentize_py": True,
            "entry_point": entry_point_file.basename,
            "exec_model": "command",
        },
        profile = "release",
        profile_variants = {},
    )

    return [
        component_info,
        DefaultInfo(
            files = depset([wasm_binary]),
            executable = wasm_binary,
        ),
    ]

python_wasm_binary = rule(
    implementation = _python_wasm_binary_impl,
    executable = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".py"],
            mandatory = True,
            doc = "Python source files. Must include a module with Run.run() implementation.",
        ),
        "entry_point": attr.string(
            doc = "Main Python module file (auto-detected if not specified, prefers app.py)",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:componentize_py_toolchain_type",
    ],
    doc = """Builds a WebAssembly CLI binary from Python source code.

    Uses componentize-py to create a WASI CLI command component that can be
    executed directly with wasmtime. This is the Python equivalent of
    cpp_wasm_binary and rust_wasm_binary.

    The Python code must implement the Run.run() pattern:

        from wit_world import exports

        class Run(exports.Run):
            def run(self) -> None:
                print("Hello, world!")

    Example:
        python_wasm_binary(
            name = "hello",
            srcs = ["app.py"],
        )

        # Run with: wasmtime run bazel-bin/path/to/hello.wasm
    """,
)
