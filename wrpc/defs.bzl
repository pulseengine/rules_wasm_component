"""Bazel rules for wrpc (WebAssembly Component RPC)"""

def _wrpc_bindgen_impl(ctx):
    """Implementation of wrpc_bindgen rule"""
    
    # Get the wasm toolchain (which includes wrpc)
    wasm_toolchain = ctx.toolchains["//toolchains:wasm_tools_toolchain_type"]
    wrpc = wasm_toolchain.wrpc
    
    # Output files
    output_dir = ctx.actions.declare_directory(ctx.attr.name + "_bindings")
    
    # Input WIT file
    wit_file = ctx.file.wit
    
    # Build command arguments
    args = ctx.actions.args()
    args.add("generate")
    args.add("--world", ctx.attr.world)
    args.add("--wit", wit_file.path)
    args.add("--output", output_dir.path)
    
    if ctx.attr.language:
        args.add("--language", ctx.attr.language)
    
    # Run wrpc generate
    ctx.actions.run(
        executable = wrpc,
        arguments = [args],
        inputs = [wit_file],
        outputs = [output_dir],
        mnemonic = "WrpcBindgen",
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
            doc = "Target language for bindings (rust, go, etc.)",
            default = "rust",
            values = ["rust", "go"],
        ),
    },
    toolchains = ["//toolchains:wasm_tools_toolchain_type"],
    doc = "Generate language bindings for wrpc from WIT interfaces",
)

def _wrpc_serve_impl(ctx):
    """Implementation of wrpc_serve rule"""
    
    # Get the wasm toolchain (which includes wrpc)
    wasm_toolchain = ctx.toolchains["//toolchains:wasm_tools_toolchain_type"]
    wrpc = wasm_toolchain.wrpc
    
    # Component to serve
    component = ctx.file.component
    
    # Create serve script
    serve_script = ctx.actions.declare_file(ctx.attr.name + "_serve.sh")
    
    script_content = '''#!/bin/bash
set -e

COMPONENT="{component}"
TRANSPORT="{transport}"
ADDRESS="{address}"

echo "Starting wrpc server..."
echo "Component: $COMPONENT"
echo "Transport: $TRANSPORT"  
echo "Address: $ADDRESS"

# Run wrpc serve
{wrpc_path} serve --component "$COMPONENT" --transport "$TRANSPORT" --address "$ADDRESS"
'''.format(
        component = component.path,
        transport = ctx.attr.transport,
        address = ctx.attr.address,
        wrpc_path = wrpc.path,
    )
    
    ctx.actions.write(
        output = serve_script,
        content = script_content,
        is_executable = True,
    )
    
    return [
        DefaultInfo(
            files = depset([serve_script]),
            executable = serve_script,
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
        "transport": attr.string(
            doc = "Transport protocol (tcp, nats, etc.)",
            default = "tcp",
            values = ["tcp", "nats"],
        ),
        "address": attr.string(
            doc = "Address to bind server to",
            default = "0.0.0.0:8080",
        ),
    },
    toolchains = ["//toolchains:wasm_tools_toolchain_type"],
    executable = True,
    doc = "Serve a WebAssembly component via wrpc",
)

def _wrpc_invoke_impl(ctx):
    """Implementation of wrpc_invoke rule"""
    
    # Get the wasm toolchain (which includes wrpc)
    wasm_toolchain = ctx.toolchains["//toolchains:wasm_tools_toolchain_type"]
    wrpc = wasm_toolchain.wrpc
    
    # Create invoke script
    invoke_script = ctx.actions.declare_file(ctx.attr.name + "_invoke.sh")
    
    script_content = '''#!/bin/bash
set -e

FUNCTION="{function}"
TRANSPORT="{transport}"
ADDRESS="{address}"

echo "Invoking wrpc function..."
echo "Function: $FUNCTION"
echo "Transport: $TRANSPORT"
echo "Address: $ADDRESS"

# Build arguments
ARGS=""
for arg in "$@"; do
    ARGS="$ARGS --arg \\"$arg\\""
done

# Run wrpc invoke
eval {wrpc_path} invoke --function "$FUNCTION" --transport "$TRANSPORT" --address "$ADDRESS" $ARGS
'''.format(
        function = ctx.attr.function,
        transport = ctx.attr.transport,
        address = ctx.attr.address,
        wrpc_path = wrpc.path,
    )
    
    ctx.actions.write(
        output = invoke_script,
        content = script_content,
        is_executable = True,
    )
    
    return [
        DefaultInfo(
            files = depset([invoke_script]),
            executable = invoke_script,
        ),
    ]

wrpc_invoke = rule(
    implementation = _wrpc_invoke_impl,
    attrs = {
        "function": attr.string(
            doc = "Function to invoke on remote component",
            mandatory = True,
        ),
        "transport": attr.string(
            doc = "Transport protocol (tcp, nats, etc.)",
            default = "tcp",
            values = ["tcp", "nats"],
        ),
        "address": attr.string(
            doc = "Address of the remote component",
            default = "localhost:8080",
        ),
    },
    toolchains = ["//toolchains:wasm_tools_toolchain_type"],
    executable = True,
    doc = "Invoke a function on a remote WebAssembly component via wrpc",
)