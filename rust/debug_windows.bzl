"""Debug rules for investigating Windows Rust toolchain issues"""

def _debug_rust_toolchain_impl(ctx):
    """Debug rule that dumps information about the Rust toolchain on Windows"""

    output = ctx.actions.declare_file(ctx.label.name + "_debug.txt")

    # Get rustc from the toolchain
    rust_toolchain = ctx.toolchains["@rules_rust//rust:toolchain_type"]
    rustc = rust_toolchain.rustc

    # Create a debug script
    if ctx.attr.is_windows:
        # Windows PowerShell script
        script = """
@echo off
echo === Rust Toolchain Debug Info === > {output}
echo. >> {output}
echo Rustc path: {rustc} >> {output}
echo. >> {output}

REM Get rustc's sysroot
{rustc} --print sysroot >> {output} 2>&1

REM Check if lib directory exists relative to rustc
FOR %%I IN ("{rustc}") DO SET "rustc_dir=%%~dpI"
echo. >> {output}
echo Rustc directory: %rustc_dir% >> {output}
echo. >> {output}

REM Try to find wasm-component-ld.exe
echo Searching for wasm-component-ld.exe: >> {output}
where wasm-component-ld.exe >> {output} 2>&1 || echo Not found in PATH >> {output}
echo. >> {output}

REM List what's in the rustc bin directory
echo Contents of rustc bin directory: >> {output}
dir /B "%rustc_dir%" >> {output} 2>&1

REM Check if lib/rustlib exists
echo. >> {output}
echo Checking lib/rustlib structure: >> {output}
dir /B "%rustc_dir%..\\lib\\rustlib" >> {output} 2>&1

REM Check x86_64-pc-windows-msvc bin directory
echo. >> {output}
echo Checking x86_64-pc-windows-msvc bin directory: >> {output}
dir /B "%rustc_dir%..\\lib\\rustlib\\x86_64-pc-windows-msvc\\bin" >> {output} 2>&1
""".format(
            output = output.path,
            rustc = rustc.path,
        )

        ctx.actions.run_shell(
            outputs = [output],
            inputs = [rustc],
            command = script,
            mnemonic = "DebugRustToolchain",
            execution_requirements = {
                "no-sandbox": "1",  # Disable sandbox to see actual file system
            },
        )
    else:
        # Linux/Mac bash script
        script = """
#!/bin/bash
{{
    echo "=== Rust Toolchain Debug Info ==="
    echo
    echo "Rustc path: {rustc}"
    echo

    # Get rustc's sysroot
    {rustc} --print sysroot

    # Get rustc directory
    rustc_dir=$(dirname "{rustc}")
    echo
    echo "Rustc directory: $rustc_dir"
    echo

    # Try to find wasm-component-ld
    echo "Searching for wasm-component-ld:"
    which wasm-component-ld || echo "Not found in PATH"
    echo

    # List what's in the rustc bin directory
    echo "Contents of rustc bin directory:"
    ls -la "$rustc_dir" || echo "Directory not accessible"

    # Check if lib/rustlib exists
    echo
    echo "Checking lib/rustlib structure:"
    ls -la "$rustc_dir/../lib/rustlib" || echo "Directory not accessible"

}} > {output} 2>&1
""".format(
            output = output.path,
            rustc = rustc.path,
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
