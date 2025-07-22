"""WAC plug rule for automatic component connection"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")

def _wac_plug_impl(ctx):
    """Implementation of wac_plug rule"""
    
    # Get toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wac = toolchain.wac
    
    # Output file
    composed_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")
    
    # Collect plug components - just use files from DefaultInfo
    plug_files = []
    for plug_target in ctx.attr.plugs:
        files = plug_target[DefaultInfo].files.to_list()
        wasm_files = [f for f in files if f.path.endswith(".wasm")]
        if not wasm_files:
            fail("Plug target %s must provide .wasm files" % plug_target.label)
        plug_files.extend(wasm_files)
    
    # Get socket component  
    socket_files = ctx.attr.socket[DefaultInfo].files.to_list()
    socket_wasm_files = [f for f in socket_files if f.path.endswith(".wasm")]
    if not socket_wasm_files:
        fail("Socket target %s must provide .wasm files" % ctx.attr.socket.label)
    socket_file = socket_wasm_files[0]  # Use first .wasm file
    
    # Run wac plug
    args = ctx.actions.args()
    args.add("plug")
    args.add("--output", composed_wasm)
    for plug_file in plug_files:
        args.add("--plug", plug_file)
    args.add(socket_file)
    
    ctx.actions.run(
        executable = wac,
        arguments = [args],
        inputs = plug_files + [socket_file],
        outputs = [composed_wasm],
        mnemonic = "WacPlug",
        progress_message = "Plugging WASM components for %s" % ctx.label,
    )
    
    # Return provider
    return [
        DefaultInfo(files = depset([composed_wasm])),
    ]

wac_plug = rule(
    implementation = _wac_plug_impl,
    attrs = {
        "socket": attr.label(
            doc = "The socket component that imports functions",
            mandatory = True,
        ),
        "plugs": attr.label_list(
            doc = "The plug components that export functions",
            mandatory = True,
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = "Plug component exports into component imports using WAC",
)