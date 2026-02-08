"""Bazel rules for wrpc (WebAssembly Component RPC)

Modernized to follow Bazel best practices (Phase 1-4 WRPC modernization):
- Uses ctx.actions.run() for build-time actions
- Cross-platform Python launchers for executable rules
- Transport abstraction via WrpcTransportInfo provider (Phase 3)
- Language-specific binding rules (Phase 4)
- No shell script generation
"""

load("//providers:providers.bzl", "WrpcTransportInfo")

# =============================================================================
# Binding Generation Rules
# =============================================================================

def _wrpc_bindgen_impl(ctx):
    """Implementation of wrpc_bindgen rule

    Generates language bindings for wrpc from WIT interfaces.
    Uses ctx.actions.run() for direct tool invocation (Bazel best practice).

    Note: This rule uses wit-bindgen-wrpc (the binding generator), not wrpc-wasmtime
    (the RPC runtime). wrpc-wasmtime is used by wrpc_serve and wrpc_invoke rules.
    """

    # Get the wasm toolchain (which includes wit-bindgen-wrpc)
    wasm_toolchain = ctx.toolchains["//toolchains:wasm_tools_toolchain_type"]
    wit_bindgen_wrpc = wasm_toolchain.wit_bindgen_wrpc

    # Output files
    output_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")

    # Input WIT file
    wit_file = ctx.file.wit

    # Build command arguments for wit-bindgen-wrpc
    args = ctx.actions.args()
    args.add(ctx.attr.language)  # wit-bindgen-wrpc <language> <options>
    args.add("--world", ctx.attr.world)
    args.add("--out-dir", output_dir.path)
    args.add(wit_file.path)

    # Run wit-bindgen-wrpc - uses ctx.actions.run() (Bazel best practice)
    ctx.actions.run(
        executable = wit_bindgen_wrpc,
        arguments = [args],
        inputs = [wit_file],
        outputs = [output_dir],
        mnemonic = "WitBindgenWrpc",
        progress_message = "Generating wrpc bindings for {}".format(ctx.attr.name),
    )

    return [
        DefaultInfo(files = depset([output_dir])),
        OutputGroupInfo(
            bindings = depset([output_dir]),
        ),
    ]

wrpc_bindgen = rule(
    implementation = _wrpc_bindgen_impl,
    attrs = {
        "wit": attr.label(
            doc = "WIT file defining the interface",
            allow_single_file = [".wit"],
            mandatory = True,
        ),
        "world": attr.string(
            doc = "WIT world to generate bindings for",
            mandatory = True,
        ),
        "language": attr.string(
            doc = "Target language for bindings (rust, go)",
            default = "rust",
            values = ["rust", "go"],
        ),
    },
    toolchains = ["//toolchains:wasm_tools_toolchain_type"],
    doc = "Generate language bindings for wrpc from WIT interfaces",
)

# =============================================================================
# Language-Specific Binding Macros (Phase 4)
# =============================================================================

def wrpc_rust_bindings(name, wit, world, **kwargs):
    """Generate Rust bindings for wrpc from WIT interface.

    This is the idiomatic way to generate wrpc client/server bindings in Rust.
    The output contains Rust source files implementing wrpc traits.

    Args:
        name: Target name
        wit: WIT file label defining the interface
        world: WIT world to generate bindings for
        **kwargs: Additional arguments passed to wrpc_bindgen

    Example:
        wrpc_rust_bindings(
            name = "calculator_client",
            wit = "//wit:calculator",
            world = "calculator-client",
        )

        rust_library(
            name = "calculator_lib",
            srcs = [":calculator_client"],
            deps = ["@crates//wrpc:wrpc"],
        )
    """
    wrpc_bindgen(
        name = name,
        wit = wit,
        world = world,
        language = "rust",
        **kwargs
    )

def wrpc_go_bindings(name, wit, world, **kwargs):
    """Generate Go bindings for wrpc from WIT interface.

    This is the idiomatic way to generate wrpc client/server bindings in Go.
    The output contains Go source files implementing wrpc interfaces.

    Args:
        name: Target name
        wit: WIT file label defining the interface
        world: WIT world to generate bindings for
        **kwargs: Additional arguments passed to wrpc_bindgen

    Example:
        wrpc_go_bindings(
            name = "calculator_client",
            wit = "//wit:calculator",
            world = "calculator-client",
        )

        go_library(
            name = "calculator_lib",
            srcs = [":calculator_client"],
            deps = ["@wrpc//go:wrpc"],
        )
    """
    wrpc_bindgen(
        name = name,
        wit = wit,
        world = world,
        language = "go",
        **kwargs
    )

# =============================================================================
# Serve Rule with Transport Abstraction
# =============================================================================

# Cross-platform Python launcher template for wrpc_serve
_SERVE_LAUNCHER_TEMPLATE = '''#!/usr/bin/env python3
"""Cross-platform wrpc serve launcher

Generated by rules_wasm_component wrpc_serve rule.
This launcher works on Windows, macOS, and Linux.
"""
import os
import subprocess
import sys

def main():
    # Configuration (substituted at generation time)
    wrpc_path = {wrpc_path!r}
    component_path = {component_path!r}
    cli_args = {cli_args!r}
    address = {address!r}

    # Resolve paths relative to runfiles
    if "RUNFILES_DIR" in os.environ:
        runfiles = os.environ["RUNFILES_DIR"]
    else:
        # Fallback: assume we're in the workspace root
        runfiles = os.path.dirname(os.path.abspath(__file__))

    # Build full paths
    full_wrpc = os.path.join(runfiles, wrpc_path)
    full_component = os.path.join(runfiles, component_path)

    # Check if files exist
    if not os.path.exists(full_wrpc):
        # Try without runfiles prefix
        full_wrpc = wrpc_path
    if not os.path.exists(full_component):
        full_component = component_path

    print(f"Starting wrpc server...")
    print(f"Component: {{full_component}}")
    print(f"Address: {{address}}")

    # Build command using CLI args from transport provider
    cmd = [full_wrpc] + cli_args + [full_component, address]

    # Execute wrpc
    try:
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    except FileNotFoundError:
        print(f"Error: wrpc not found at {{full_wrpc}}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\\nServer stopped")
        sys.exit(0)

if __name__ == "__main__":
    main()
'''

# Legacy launcher template for backward compatibility
_SERVE_LAUNCHER_LEGACY_TEMPLATE = '''#!/usr/bin/env python3
"""Cross-platform wrpc serve launcher (legacy mode)

Generated by rules_wasm_component wrpc_serve rule.
This launcher works on Windows, macOS, and Linux.
"""
import os
import subprocess
import sys

def main():
    # Configuration (substituted at generation time)
    wrpc_path = {wrpc_path!r}
    component_path = {component_path!r}
    transport = {transport!r}
    address = {address!r}

    # Resolve paths relative to runfiles
    if "RUNFILES_DIR" in os.environ:
        runfiles = os.environ["RUNFILES_DIR"]
    else:
        # Fallback: assume we're in the workspace root
        runfiles = os.path.dirname(os.path.abspath(__file__))

    # Build full paths
    full_wrpc = os.path.join(runfiles, wrpc_path)
    full_component = os.path.join(runfiles, component_path)

    # Check if files exist
    if not os.path.exists(full_wrpc):
        # Try without runfiles prefix
        full_wrpc = wrpc_path
    if not os.path.exists(full_component):
        full_component = component_path

    print(f"Starting wrpc server...")
    print(f"Component: {{full_component}}")
    print(f"Transport: {{transport}}")
    print(f"Address: {{address}}")

    # Build command (legacy: wrpc <transport> serve <component> <address>)
    cmd = [full_wrpc, transport, "serve", full_component, address]

    # Execute wrpc
    try:
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    except FileNotFoundError:
        print(f"Error: wrpc not found at {{full_wrpc}}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\\nServer stopped")
        sys.exit(0)

if __name__ == "__main__":
    main()
'''

def _wrpc_serve_impl(ctx):
    """Implementation of wrpc_serve rule

    Creates a cross-platform Python launcher to serve a WebAssembly component via wrpc.
    Supports both:
    - Modern: transport_config attribute (WrpcTransportInfo provider)
    - Legacy: transport + address string attributes (deprecated but supported)
    """

    # Get the wasm toolchain (which includes wrpc)
    wasm_toolchain = ctx.toolchains["//toolchains:wasm_tools_toolchain_type"]
    wrpc = wasm_toolchain.wrpc

    # Component to serve
    component = ctx.file.component

    # Create cross-platform Python launcher
    launcher = ctx.actions.declare_file(ctx.attr.name + "_serve.py")

    # Check if using new transport provider or legacy string attributes
    if ctx.attr.transport_config:
        # Modern: use transport provider
        transport_info = ctx.attr.transport_config[WrpcTransportInfo]
        cli_args = transport_info.cli_args + transport_info.extra_args
        address = transport_info.address

        launcher_content = _SERVE_LAUNCHER_TEMPLATE.format(
            wrpc_path = wrpc.short_path,
            component_path = component.short_path,
            cli_args = cli_args,
            address = address,
        )
    else:
        # Legacy: use string attributes (deprecated)
        launcher_content = _SERVE_LAUNCHER_LEGACY_TEMPLATE.format(
            wrpc_path = wrpc.short_path,
            component_path = component.short_path,
            transport = ctx.attr.transport,
            address = ctx.attr.address,
        )

    ctx.actions.write(
        output = launcher,
        content = launcher_content,
        is_executable = True,
    )

    # Create runfiles with wrpc and component
    runfiles = ctx.runfiles(files = [wrpc, component])

    return [
        DefaultInfo(
            files = depset([launcher]),
            executable = launcher,
            runfiles = runfiles,
        ),
    ]

wrpc_serve = rule(
    implementation = _wrpc_serve_impl,
    attrs = {
        "component": attr.label(
            doc = "WebAssembly component to serve",
            allow_single_file = [".wasm"],
            mandatory = True,
        ),
        "transport_config": attr.label(
            doc = "Transport configuration (from tcp_transport, nats_transport, etc.)",
            providers = [WrpcTransportInfo],
        ),
        # Legacy attributes (deprecated, use transport_config instead)
        "transport": attr.string(
            doc = "[Deprecated: use transport_config] Transport protocol (tcp, nats, unix, quic)",
            default = "tcp",
            values = ["tcp", "nats", "unix", "quic"],
        ),
        "address": attr.string(
            doc = "[Deprecated: use transport_config] Address to bind server to",
            default = "0.0.0.0:8080",
        ),
    },
    toolchains = ["//toolchains:wasm_tools_toolchain_type"],
    executable = True,
    doc = """Serve a WebAssembly component via wrpc (cross-platform).

    Two ways to configure transport:

    Modern (recommended):
        tcp_transport(name = "tcp_dev", address = "localhost:8080")
        wrpc_serve(
            name = "serve",
            component = ":my_component",
            transport_config = ":tcp_dev",
        )

    Legacy (deprecated):
        wrpc_serve(
            name = "serve",
            component = ":my_component",
            transport = "tcp",
            address = "localhost:8080",
        )
    """,
)

# =============================================================================
# Invoke Rule with Transport Abstraction
# =============================================================================

# Cross-platform Python launcher template for wrpc_invoke
_INVOKE_LAUNCHER_TEMPLATE = '''#!/usr/bin/env python3
"""Cross-platform wrpc invoke launcher

Generated by rules_wasm_component wrpc_invoke rule.
This launcher works on Windows, macOS, and Linux.
"""
import os
import subprocess
import sys

def main():
    # Configuration (substituted at generation time)
    wrpc_path = {wrpc_path!r}
    function = {function!r}
    cli_args = {cli_args!r}
    address = {address!r}

    # Resolve paths relative to runfiles
    if "RUNFILES_DIR" in os.environ:
        runfiles = os.environ["RUNFILES_DIR"]
    else:
        runfiles = os.path.dirname(os.path.abspath(__file__))

    # Build full path to wrpc
    full_wrpc = os.path.join(runfiles, wrpc_path)
    if not os.path.exists(full_wrpc):
        full_wrpc = wrpc_path

    print(f"Invoking wrpc function...")
    print(f"Function: {{function}}")
    print(f"Address: {{address}}")

    # Build command using CLI args from transport provider
    # wrpc <transport> run --invoke <function> <address>
    cmd = [full_wrpc] + cli_args[:1] + ["run", "--invoke", function, address]

    # Add any additional arguments passed to the launcher
    cmd.extend(sys.argv[1:])

    # Execute wrpc
    try:
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    except FileNotFoundError:
        print(f"Error: wrpc not found at {{full_wrpc}}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
'''

# Legacy launcher template for backward compatibility
_INVOKE_LAUNCHER_LEGACY_TEMPLATE = '''#!/usr/bin/env python3
"""Cross-platform wrpc invoke launcher (legacy mode)

Generated by rules_wasm_component wrpc_invoke rule.
This launcher works on Windows, macOS, and Linux.
"""
import os
import subprocess
import sys

def main():
    # Configuration (substituted at generation time)
    wrpc_path = {wrpc_path!r}
    function = {function!r}
    transport = {transport!r}
    address = {address!r}

    # Resolve paths relative to runfiles
    if "RUNFILES_DIR" in os.environ:
        runfiles = os.environ["RUNFILES_DIR"]
    else:
        runfiles = os.path.dirname(os.path.abspath(__file__))

    # Build full path to wrpc
    full_wrpc = os.path.join(runfiles, wrpc_path)
    if not os.path.exists(full_wrpc):
        full_wrpc = wrpc_path

    print(f"Invoking wrpc function...")
    print(f"Function: {{function}}")
    print(f"Transport: {{transport}}")
    print(f"Address: {{address}}")

    # Build command (legacy: wrpc <transport> run --invoke <function> <address>)
    cmd = [full_wrpc, transport, "run", "--invoke", function, address]

    # Add any additional arguments passed to the launcher
    cmd.extend(sys.argv[1:])

    # Execute wrpc
    try:
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    except FileNotFoundError:
        print(f"Error: wrpc not found at {{full_wrpc}}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
'''

def _wrpc_invoke_impl(ctx):
    """Implementation of wrpc_invoke rule

    Creates a cross-platform Python launcher to invoke a function on a remote
    WebAssembly component via wrpc.
    Supports both transport_config (modern) and transport+address (legacy).
    """

    # Get the wasm toolchain (which includes wrpc)
    wasm_toolchain = ctx.toolchains["//toolchains:wasm_tools_toolchain_type"]
    wrpc = wasm_toolchain.wrpc

    # Create cross-platform Python launcher
    launcher = ctx.actions.declare_file(ctx.attr.name + "_invoke.py")

    # Check if using new transport provider or legacy string attributes
    if ctx.attr.transport_config:
        # Modern: use transport provider
        transport_info = ctx.attr.transport_config[WrpcTransportInfo]
        cli_args = transport_info.cli_args + transport_info.extra_args
        address = transport_info.address

        launcher_content = _INVOKE_LAUNCHER_TEMPLATE.format(
            wrpc_path = wrpc.short_path,
            function = ctx.attr.function,
            cli_args = cli_args,
            address = address,
        )
    else:
        # Legacy: use string attributes (deprecated)
        launcher_content = _INVOKE_LAUNCHER_LEGACY_TEMPLATE.format(
            wrpc_path = wrpc.short_path,
            function = ctx.attr.function,
            transport = ctx.attr.transport,
            address = ctx.attr.address,
        )

    ctx.actions.write(
        output = launcher,
        content = launcher_content,
        is_executable = True,
    )

    # Create runfiles with wrpc
    runfiles = ctx.runfiles(files = [wrpc])

    return [
        DefaultInfo(
            files = depset([launcher]),
            executable = launcher,
            runfiles = runfiles,
        ),
    ]

wrpc_invoke = rule(
    implementation = _wrpc_invoke_impl,
    attrs = {
        "function": attr.string(
            doc = "Function to invoke on remote component",
            mandatory = True,
        ),
        "transport_config": attr.label(
            doc = "Transport configuration (from tcp_transport, nats_transport, etc.)",
            providers = [WrpcTransportInfo],
        ),
        # Legacy attributes (deprecated, use transport_config instead)
        "transport": attr.string(
            doc = "[Deprecated: use transport_config] Transport protocol (tcp, nats, unix, quic)",
            default = "tcp",
            values = ["tcp", "nats", "unix", "quic"],
        ),
        "address": attr.string(
            doc = "[Deprecated: use transport_config] Address of the remote component",
            default = "localhost:8080",
        ),
    },
    toolchains = ["//toolchains:wasm_tools_toolchain_type"],
    executable = True,
    doc = """Invoke a function on a remote WebAssembly component via wrpc (cross-platform).

    Two ways to configure transport:

    Modern (recommended):
        tcp_transport(name = "tcp_server", address = "localhost:8080")
        wrpc_invoke(
            name = "invoke",
            function = "calculator:add",
            transport_config = ":tcp_server",
        )

    Legacy (deprecated):
        wrpc_invoke(
            name = "invoke",
            function = "calculator:add",
            transport = "tcp",
            address = "localhost:8080",
        )
    """,
)
