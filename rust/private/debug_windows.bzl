"""Debug rules for investigating Windows Rust toolchain issues"""

def _debug_rust_toolchain_impl(ctx):
    """Debug rule that dumps information about the Rust toolchain on Windows"""

    output = ctx.actions.declare_file(ctx.label.name + "_debug.txt")

    # Get rustc from the toolchain
    rust_toolchain = ctx.toolchains["@rules_rust//rust:toolchain_type"]
    rustc = rust_toolchain.rustc

    # run_shell always uses bash (even on Windows via Git Bash),
    # so use bash-compatible syntax for all platforms
    script = """
#!/bin/bash
{{
    echo "=== Rust Toolchain Debug Info ==="
    echo "Platform: {platform}"
    echo
    echo "Rustc path: {rustc}"
    echo

    # Get rustc's sysroot
    "{rustc}" --print sysroot 2>&1 || echo "Failed to get sysroot"

    # Get rustc directory
    rustc_dir=$(dirname "{rustc}")
    echo
    echo "Rustc directory: $rustc_dir"
    echo

    # Try to find wasm-component-ld
    echo "Searching for wasm-component-ld:"
    which wasm-component-ld 2>/dev/null || echo "Not found in PATH"
    echo

    # List what's in the rustc bin directory
    echo "Contents of rustc bin directory:"
    ls "$rustc_dir" 2>&1 || echo "Directory not accessible"

    # Check if lib/rustlib exists
    echo
    echo "Checking lib/rustlib structure:"
    ls "$rustc_dir/../lib/rustlib" 2>&1 || echo "Directory not accessible"

}} > {output} 2>&1
""".format(
        output = output.path,
        rustc = rustc.path,
        platform = "windows" if ctx.attr.is_windows else "unix",
    )

    ctx.actions.run_shell(
        outputs = [output],
        inputs = [rustc],
        command = script,
        mnemonic = "DebugRustToolchain",
    )

    return [DefaultInfo(files = depset([output]))]

debug_rust_toolchain = rule(
    implementation = _debug_rust_toolchain_impl,
    attrs = {
        "is_windows": attr.bool(
            default = False,
            doc = "Whether this is running on Windows",
        ),
    },
    toolchains = [
        "@rules_rust//rust:toolchain_type",
    ],
    doc = """
    Debug rule that dumps information about the Rust toolchain.

    On Windows, this will show:
    - Where rustc is located
    - What rustc's sysroot is
    - Whether wasm-component-ld.exe can be found
    - What files are visible in the rustlib directory

    Example:
        debug_rust_toolchain(
            name = "debug_windows",
            is_windows = select({
                "@platforms//os:windows": True,
                "//conditions:default": False,
            }),
        )
    """,
)
