"""Python WebAssembly Component rule implementation.

Builds Python code into WebAssembly components using componentize-py.
componentize-py bundles Python source with a WASM interpreter and generates
WASI Preview 2 components.

Example usage:

    python_wasm_component(
        name = "hello",
        srcs = ["hello.py"],
        wit = "//wit:hello",
        world = "hello",
    )
"""

load("//providers:providers.bzl", "WasmComponentInfo")
load("//rust:transitions.bzl", "wasm_transition")

def _python_wasm_component_impl(ctx):
    """Implementation of python_wasm_component rule.

    Compiles Python source code into WebAssembly components using componentize-py.

    Args:
        ctx: The rule context containing:
            - ctx.files.srcs: Python source files
            - ctx.file.wit: WIT interface definition file
            - ctx.attr.entry_point: Main Python module (default: first .py file)
            - ctx.attr.world: WIT world to target
            - ctx.attr.stub_wasi: Generate WASI stubs

    Returns:
        List of providers:
        - WasmComponentInfo: Component metadata for Python
        - DefaultInfo: Component .wasm file
    """

    # Get componentize-py toolchain
    py_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:componentize_py_toolchain_type"]
    componentize_py = py_toolchain.componentize_py

    # Output component file
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Input source files
    source_files = ctx.files.srcs
    wit_file = ctx.file.wit

    # Find the entry point file
    entry_point = ctx.attr.entry_point
    entry_point_file = None

    if entry_point:
        # User specified an entry point
        for src in source_files:
            if src.basename == entry_point or src.path.endswith(entry_point):
                entry_point_file = src
                break
    else:
        # Auto-detect: use first .py file or app.py or main.py
        priority_names = ["app.py", "main.py", "__init__.py"]
        for name in priority_names:
            for src in source_files:
                if src.basename == name:
                    entry_point_file = src
                    break
            if entry_point_file:
                break

        if not entry_point_file and source_files:
            # Fall back to first .py file
            for src in source_files:
                if src.extension == "py":
                    entry_point_file = src
                    break

    if not entry_point_file:
        fail("No Python entry point found. Specify entry_point or add a .py file to srcs.")

    # Create build script to run componentize-py
    build_script = ctx.actions.declare_file(ctx.attr.name + "_build.sh")

    script_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "# Create temporary workspace",
        "WORK_DIR=$(mktemp -d)",
        "",
        "# Copy all source files to workspace",
    ]

    # Copy source files preserving relative paths within package
    for src in source_files:
        script_lines.append("cp \"{}\" \"$WORK_DIR/{}\"".format(src.path, src.basename))

    # Build componentize-py command
    script_lines.extend([
        "",
        "# Save original directory for absolute paths",
        "ORIGINAL_DIR=\"$(pwd)\"",
        "",
        "# Change to workspace directory",
        "cd \"$WORK_DIR\"",
        "",
        "# Run componentize-py",
    ])

    # componentize-py command structure:
    # componentize-py [GLOBAL_OPTIONS] componentize <APP_NAME> [SUBCOMMAND_OPTIONS]
    #
    # Global options: -d/--wit-path, -w/--world
    # Subcommand options: -o/--output, -p/--python-path, -s/--stub-wasi

    # Get module name from entry point (without .py extension)
    module_name = entry_point_file.basename
    if module_name.endswith(".py"):
        module_name = module_name[:-3]

    cmd_parts = [
        "\"$ORIGINAL_DIR/{}\"".format(componentize_py.path),
        # Global options (before subcommand)
        "-d \"$ORIGINAL_DIR/{}\"".format(wit_file.path),  # WIT file path
        "-w \"{}\"".format(ctx.attr.world),  # World name
        # Subcommand
        "componentize",
        # Module name (positional argument)
        "\"{}\"".format(module_name),
        # Subcommand options (after subcommand)
        "-p .",  # Python path (current directory where we copied sources)
        "-o \"$ORIGINAL_DIR/{}\"".format(component_wasm.path),  # Output path
    ]

    # Add stub-wasi flag if enabled (subcommand option)
    if ctx.attr.stub_wasi:
        cmd_parts.append("-s")

    script_lines.extend([
        " ".join(cmd_parts),
        "",
        "# Cleanup",
        "rm -rf \"$WORK_DIR\"",
        "",
        "echo \"Python component build complete\"",
    ])

    ctx.actions.write(
        output = build_script,
        content = "\n".join(script_lines),
        is_executable = True,
    )

    # Collect all inputs
    all_inputs = source_files + [wit_file, componentize_py]

    # Run the build script
    ctx.actions.run(
        executable = build_script,
        inputs = all_inputs,
        outputs = [component_wasm],
        mnemonic = "ComponentizePy",
        progress_message = "Building Python component %s with componentize-py" % ctx.label,
        use_default_shell_env = True,
    )

    # Create WasmComponentInfo provider
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = struct(
            wit_file = wit_file,
            package_name = ctx.attr.package_name or "component:{}@1.0.0".format(ctx.attr.name),
        ),
        component_type = "component",
        imports = [],  # componentize-py handles imports automatically
        exports = [ctx.attr.world] if ctx.attr.world else [],
        metadata = {
            "name": ctx.label.name,
            "language": "python",
            "target": "wasm32-wasi",
            "componentize_py": True,
            "entry_point": entry_point_file.basename,
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

python_wasm_component = rule(
    implementation = _python_wasm_component_impl,
    cfg = wasm_transition,
    executable = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".py"],
            mandatory = True,
            doc = "Python source files",
        ),
        "wit": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT interface definition file",
        ),
        "entry_point": attr.string(
            doc = "Main Python module file (auto-detected if not specified)",
        ),
        "world": attr.string(
            mandatory = True,
            doc = "WIT world name to target",
        ),
        "package_name": attr.string(
            doc = "WIT package name (default: component:{name}@1.0.0)",
        ),
        "stub_wasi": attr.bool(
            default = False,
            doc = "Generate WASI stub implementations",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:componentize_py_toolchain_type",
    ],
    doc = """Builds a WebAssembly component from Python source code.

    Uses componentize-py to bundle Python source with a WASM interpreter
    and generate WASI Preview 2 components.

    Example:
        python_wasm_component(
            name = "hello",
            srcs = ["hello.py"],
            wit = "//wit:hello",
            world = "hello",
        )

        # Run with: wasmtime run bazel-bin/path/to/hello.wasm
    """,
)
