"""MoonBit WebAssembly CLI rule with full WASI support.

This rule generates WASI bindings with wit-bindgen moonbit, allowing MoonBit code
to use proper WASI interfaces (stdout, stderr, environment, etc.) instead of
MoonBit's built-in spectest-based I/O.

The key difference from moonbit_wasm_binary:
- moonbit_wasm_binary: Wraps existing moonbit_wasm output (fails if it uses spectest)
- moonbit_wasm_cli: Generates WASI bindings first, then compiles (no spectest dependency)

Example usage:

    moonbit_wasm_cli(
        name = "my_cli",
        srcs = ["main.mbt"],
        # Uses wasi:cli/command world by default
    )

    # Run with: wasmtime run bazel-bin/path/to/my_cli.wasm

The user's MoonBit source file must implement the run() function:

    pub fn run() -> Result[Unit, Unit] {
      let stdout = @stdout.get_stdout()
      let bytes = string_to_bytes("Hello, World!\\n")
      match stdout.blocking_write_and_flush(bytes) {
        Ok(_) => Ok(())
        Err(_) => Err(())
      }
    }
"""

load("//providers:providers.bzl", "WasmComponentInfo", "WitInfo")

def _moonbit_wasm_cli_impl(ctx):
    """Implementation of moonbit_wasm_cli rule.

    Full pipeline:
    1. Use the cli_wit directory which has complete WASI WIT with deps
    2. Run wit-bindgen moonbit to generate WASI bindings for 'command' world
    3. Replace the generated stub with user source code
    4. Add proper imports to the run package
    5. Compile with moon build
    6. Run wasm-tools component embed/new to create final component

    Args:
        ctx: The rule context

    Returns:
        List of providers:
        - WasmComponentInfo: CLI binary metadata
        - DefaultInfo: WASM component file
    """

    # Get toolchains
    wasm_tools_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = wasm_tools_toolchain.wasm_tools
    wit_bindgen = wasm_tools_toolchain.wit_bindgen

    moonbit_toolchain = ctx.toolchains["@rules_moonbit//moonbit:moonbit_toolchain_type"]
    moon = moonbit_toolchain.moonbit.moon_executable
    moonbit_all_files = moonbit_toolchain.moonbit.all_files

    srcs = ctx.files.srcs
    if len(srcs) != 1:
        fail("moonbit_wasm_cli requires exactly one source file that implements run()")

    user_src = srcs[0]

    # Get the cli_wit directory - it has complete WIT with nested deps
    cli_wit_dep = ctx.attr.cli_wit
    cli_wit_files = cli_wit_dep[DefaultInfo].files.to_list()

    # Output files
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Determine project name (used by wit-bindgen for MoonBit package paths)
    project_name = ctx.attr.package_name or "cli/{}".format(ctx.attr.name)

    # Build script that creates WASI CLI bindings and compiles
    script = """
set -e

# Capture absolute paths before any directory changes
WIT_BINDGEN="$(pwd)/{wit_bindgen}"
MOON="$(pwd)/{moon}"
WASM_TOOLS="$(pwd)/{wasm_tools}"
OUTPUT="$(pwd)/{output}"
USER_SRC="$(pwd)/{user_src}"
ORIG_DIR="$(pwd)"

# Set MOON_HOME to point to the toolchain's .moon directory
# This is where the hermetic toolchain places the core library
# MOON path is like /path/to/external/moonbit_toolchain/bin/moon
# MOON_HOME should be /path/to/external/moonbit_toolchain/.moon
TOOLCHAIN_ROOT=$(dirname $(dirname "$MOON"))
export MOON_HOME="$TOOLCHAIN_ROOT/.moon"

echo "=== Debug: MOON_HOME setup ==="
echo "MOON=$MOON"
echo "TOOLCHAIN_ROOT=$TOOLCHAIN_ROOT"
echo "MOON_HOME=$MOON_HOME"
echo "PWD=$(pwd)"
echo "=== Checking MOON_HOME structure ==="
ls -la "$MOON_HOME/" 2>/dev/null || echo "MOON_HOME does not exist"
ls -la "$MOON_HOME/lib/" 2>/dev/null || echo "MOON_HOME/lib does not exist"
ls -la "$MOON_HOME/lib/core/" 2>/dev/null | head -5 || echo "Core library NOT found at $MOON_HOME/lib/core/"
echo "=== Checking relative to MOON path ==="
ls -la "$(dirname $(dirname $MOON))/.moon/" 2>/dev/null || echo "No .moon relative to MOON"
echo "=== End debug ==="

# Create temporary project directory
PROJECT_DIR=$(mktemp -d)
cleanup() {{ rm -rf "$PROJECT_DIR"; }}
trap cleanup EXIT

cd "$PROJECT_DIR"

# Step 1: Copy cli_wit directory as wit/
# The cli_wit has the complete structure with nested deps/
{copy_cli_wit}

echo "=== WIT directory structure ==="
find wit -type f -name "*.wit" | head -20

# Step 2: Generate MoonBit bindings from WIT using 'command' world
"$WIT_BINDGEN" moonbit \\
    --project-name "{project_name}" \\
    --world command \\
    --derive-show \\
    --derive-eq \\
    --out-dir . \\
    wit 2>&1

echo "=== Generated project structure ==="
find . -name "*.mbt" -o -name "moon.pkg.json" | sort | head -30

# Step 3: Replace the stub with user source code
# The stub is at gen/interface/wasi/cli/run/stub.mbt
cp "$USER_SRC" gen/interface/wasi/cli/run/stub.mbt
echo "Replaced stub with user source"

# Step 4: Add imports to the run package's moon.pkg.json
# The user code needs access to stdout, streams, and environment packages
cat > gen/interface/wasi/cli/run/moon.pkg.json << 'PKGJSON'
{{
  "import": [
    {{ "path": "{project_name}/interface/wasi/cli/stdout", "alias": "stdout" }},
    {{ "path": "{project_name}/interface/wasi/cli/environment", "alias": "environment" }},
    {{ "path": "{project_name}/interface/wasi/io/streams", "alias": "streams" }}
  ]
}}
PKGJSON

echo "=== Updated run package config ==="
cat gen/interface/wasi/cli/run/moon.pkg.json

# Step 5: Compile with MoonBit
"$MOON" build --target wasm 2>&1 || {{
    echo "MoonBit compilation failed" >&2
    echo "=== moon.mod.json ==="
    cat moon.mod.json 2>/dev/null || echo "No moon.mod.json found"
    echo "=== User source ==="
    cat gen/interface/wasi/cli/run/stub.mbt
    exit 1
}}

# Find the generated WASM
CORE_WASM=$(find _build -name "*.wasm" -type f | head -1)
if [ -z "$CORE_WASM" ]; then
    echo "No WASM file found after moon build" >&2
    find _build -type f 2>/dev/null || true
    exit 1
fi

echo "Core WASM: $CORE_WASM"

# Step 6: Embed WIT and create component
# Use --encoding utf16 for MoonBit string encoding
"$WASM_TOOLS" component embed \\
    --encoding utf16 \\
    --world command \\
    wit \\
    "$CORE_WASM" \\
    -o embedded.wasm 2>&1

# Step 7: Create final component
"$WASM_TOOLS" component new \\
    embedded.wasm \\
    -o "$OUTPUT" 2>&1

echo "Created CLI component: $OUTPUT"
""".format(
        wit_bindgen = wit_bindgen.path,
        moon = moon.path,
        wasm_tools = wasm_tools.path,
        output = component_wasm.path,
        user_src = user_src.path,
        project_name = project_name,
        copy_cli_wit = _generate_cli_wit_copy(cli_wit_files),
    )

    ctx.actions.run_shell(
        command = script,
        inputs = [wit_bindgen, moon, wasm_tools, user_src] + cli_wit_files + moonbit_all_files.to_list(),
        outputs = [component_wasm],
        mnemonic = "MoonbitWasmCli",
        progress_message = "Building MoonBit CLI component %s" % ctx.label,
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
            "wasi:io/streams@0.2.0",
            "wasi:io/poll@0.2.0",
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

def _generate_cli_wit_copy(cli_wit_files):
    """Generate shell command to copy cli_wit directory contents as wit/.

    The cli_wit directory from @wasi_cli_v020//:cli has:
        cli_wit/
            command.wit, imports.wit, run.wit, ...
            deps/
                wasi-io/, wasi-clocks/, wasi-filesystem/, ...

    Note: The wit_library target outputs a DIRECTORY (cli_wit), not individual files.
    We need to copy the CONTENTS of that directory as wit/ for wit-bindgen.
    """
    if not cli_wit_files:
        return "# No cli_wit files"

    # The wit_library outputs a directory (e.g., path = "bazel-out/.../cli_wit")
    # We need to copy the CONTENTS of that directory into wit/
    cli_wit_dir = cli_wit_files[0].path

    # Copy CONTENTS of cli_wit directory as wit/ (not cli_wit itself)
    # Use the directory path directly - it's the cli_wit directory
    return 'mkdir -p wit && cp -r "$ORIG_DIR/{}/"* wit/'.format(cli_wit_dir)

moonbit_wasm_cli = rule(
    implementation = _moonbit_wasm_cli_impl,
    executable = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".mbt"],
            mandatory = True,
            doc = "MoonBit source file implementing run() -> Result[Unit, Unit]",
        ),
        "package_name": attr.string(
            doc = "MoonBit package name for wit-bindgen (default: cli/{name})",
        ),
        "cli_wit": attr.label(
            default = "@wasi_cli_v020//:cli",
            doc = "WASI CLI WIT package (wit_library target with complete deps)",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
        "@rules_moonbit//moonbit:moonbit_toolchain_type",
    ],
    doc = """Builds a MoonBit WebAssembly CLI binary with full WASI support.

    This rule generates WASI bindings using wit-bindgen moonbit, enabling
    MoonBit code to use proper WASI interfaces for I/O instead of spectest.

    Unlike moonbit_wasm_binary (which wraps existing moonbit_wasm output),
    this rule generates WASI bindings first, ensuring no spectest dependency.

    Your source file must implement the run() function:

        pub fn run() -> Result[Unit, Unit] {
          // Get stdout handle from generated bindings
          let stdout = @stdout.get_stdout()

          // Convert string to bytes (helper function you provide)
          let bytes = string_to_bytes("Hello, World!\\n")

          // Write to stdout using WASI streams
          match stdout.blocking_write_and_flush(bytes) {
            Ok(_) => Ok(())
            Err(_) => Err(())
          }
        }

        fn string_to_bytes(s : String) -> FixedArray[Byte] {
          let len = s.length()
          let bytes = FixedArray::make(len, b'\\x00')
          for i = 0; i < len; i = i + 1 {
            bytes[i] = s[i].to_int().to_byte()
          }
          bytes
        }

    Example BUILD.bazel:

        moonbit_wasm_cli(
            name = "my_cli",
            srcs = ["main.mbt"],
        )

        # Run with: wasmtime run bazel-bin/path/to/my_cli.wasm
    """,
)
