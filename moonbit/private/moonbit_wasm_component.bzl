"""MoonBit WebAssembly Component rule implementation.

Builds MoonBit code into WebAssembly components using the full wit-bindgen pipeline:
1. wit-bindgen moonbit - Generate MoonBit bindings from WIT
2. moon build - Compile MoonBit to core WASM with proper exports
3. wasm-tools component embed/new - Create final component

Example usage:

    moonbit_wasm_component(
        name = "calculator",
        srcs = ["calculator.mbt"],
        wit = "calculator.wit",
        world = "calculator",
    )

The user's source files should implement the functions declared in the WIT world.
wit-bindgen generates the FFI glue code that maps MoonBit functions to component exports.
"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _moonbit_wasm_component_impl(ctx):
    """Implementation of moonbit_wasm_component rule.

    Full pipeline:
    1. Run wit-bindgen moonbit to generate MoonBit bindings
    2. Copy user sources to implement stub functions
    3. Run moon build to compile to WASM with proper exports
    4. Run wasm-tools component embed to add WIT metadata
    5. Run wasm-tools component new to create final component

    Args:
        ctx: The rule context

    Returns:
        List of providers:
        - WasmComponentInfo: Component metadata
        - DefaultInfo: Component .wasm file
    """

    # Get toolchains
    wasm_tools_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = wasm_tools_toolchain.wasm_tools
    wit_bindgen = wasm_tools_toolchain.wit_bindgen

    moonbit_toolchain = ctx.toolchains["@rules_moonbit//moonbit:moonbit_toolchain_type"]
    moon = moonbit_toolchain.moonbit.moon_executable
    moonbit_all_files = moonbit_toolchain.moonbit.all_files

    wit_file = ctx.file.wit
    srcs = ctx.files.srcs

    # Output files
    component_wasm = ctx.actions.declare_file(ctx.attr.name + ".wasm")

    # Determine project name for wit-bindgen
    project_name = ctx.attr.package_name or "component/{}".format(ctx.attr.name)

    # Build script that runs the full pipeline
    # This is necessary because wit-bindgen creates a complex project structure
    # that moon build expects, and we need to integrate user sources
    script = """
set -e

# Capture absolute paths before any directory changes
WIT_BINDGEN="$(pwd)/{wit_bindgen}"
MOON="$(pwd)/{moon}"
WASM_TOOLS="$(pwd)/{wasm_tools}"
WIT_FILE="$(pwd)/{wit_file}"
OUTPUT="$(pwd)/{output}"
ORIG_DIR="$(pwd)"

# Set MOON_HOME so moon build can find the core library
# MOON path: /path/to/external/moonbit_toolchain/bin/moon
# MOON_HOME: /path/to/external/moonbit_toolchain/.moon
TOOLCHAIN_ROOT=$(dirname $(dirname "$MOON"))
export MOON_HOME="$TOOLCHAIN_ROOT/.moon"

# Create temporary project directory
PROJECT_DIR=$(mktemp -d)
cleanup() {{ rm -rf "$PROJECT_DIR"; }}
trap cleanup EXIT

cd "$PROJECT_DIR"

# Step 1: Generate MoonBit bindings from WIT
"$WIT_BINDGEN" moonbit \\
    --project-name "{project_name}" \\
    --world {world} \\
    --derive-show \\
    --derive-eq \\
    --out-dir . \\
    "$WIT_FILE" 2>&1

# Step 2: Copy user source files to implement the stub functions
# User sources replace the generated stubs in gen/world/{world}/stub.mbt
STUB_DIR="gen/world/{world}"
if [ -d "$STUB_DIR" ]; then
    {copy_sources}
fi

# Step 3: Compile with MoonBit
"$MOON" build --target wasm 2>&1 || {{
    echo "MoonBit compilation failed" >&2
    exit 1
}}

# Find the generated WASM
CORE_WASM=$(find _build -name "*.wasm" -type f | head -1)
if [ -z "$CORE_WASM" ]; then
    echo "No WASM file found after moon build" >&2
    exit 1
fi

# Step 4: Embed WIT metadata
# Use --encoding utf16 for MoonBit string encoding
"$WASM_TOOLS" component embed \\
    --encoding utf16 \\
    --world {world} \\
    "$WIT_FILE" \\
    "$CORE_WASM" \\
    -o embedded.wasm 2>&1

# Step 5: Create final component
"$WASM_TOOLS" component new \\
    embedded.wasm \\
    -o "$OUTPUT" 2>&1

echo "Created component: $OUTPUT"
""".format(
        wit_bindgen = wit_bindgen.path,
        moon = moon.path,
        wasm_tools = wasm_tools.path,
        wit_file = wit_file.path,
        output = component_wasm.path,
        project_name = project_name,
        world = ctx.attr.world,
        copy_sources = "\n    ".join([
            'cp "$ORIG_DIR/{}" "$STUB_DIR/stub.mbt"'.format(src.path)
            for src in srcs
        ]) if srcs else "# No user sources to copy",
    )

    ctx.actions.run_shell(
        command = script,
        inputs = [wit_file, wit_bindgen, moon, wasm_tools] + srcs + moonbit_all_files.to_list(),
        outputs = [component_wasm],
        mnemonic = "MoonbitWasmComponent",
        progress_message = "Building MoonBit WASM component %s" % ctx.label,
        use_default_shell_env = True,
    )

    # Create WasmComponentInfo provider
    component_info = WasmComponentInfo(
        wasm_file = component_wasm,
        wit_info = struct(
            wit_file = wit_file,
            package_name = ctx.attr.package_name or "component:{}@1.0.0".format(ctx.attr.name),
        ),
        component_type = "reactor",  # Library component
        imports = [],  # TODO: Parse from WIT
        exports = [ctx.attr.world] if ctx.attr.world else [],
        metadata = {
            "name": ctx.label.name,
            "language": "moonbit",
            "target": "wasm32-wasi",
            "exec_model": "reactor",
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

moonbit_wasm_component = rule(
    implementation = _moonbit_wasm_component_impl,
    executable = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".mbt"],
            doc = "MoonBit source files implementing the WIT interface functions",
        ),
        "wit": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT interface definition file",
        ),
        "world": attr.string(
            mandatory = True,
            doc = "WIT world name to target",
        ),
        "package_name": attr.string(
            doc = "WIT package name for generated bindings (default: component/{name})",
        ),
    },
    toolchains = [
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
        "@rules_moonbit//moonbit:moonbit_toolchain_type",
    ],
    doc = """Builds a WebAssembly component from MoonBit source code.

    This rule implements the full wit-bindgen pipeline:
    1. Generates MoonBit FFI bindings from WIT using wit-bindgen
    2. Compiles user MoonBit source with generated bindings
    3. Creates a WebAssembly component with proper exports

    Example:
        moonbit_wasm_component(
            name = "calculator",
            srcs = ["calculator.mbt"],
            wit = "calculator.wit",
            world = "calculator",
        )

    The user's .mbt files should implement the functions declared in the WIT world.
    Function signatures must match the WIT interface (e.g., add(a: s32, b: s32) -> s32
    maps to fn add(a: Int, b: Int) -> Int in MoonBit).

    Inspect the result with: wasm-tools component wit bazel-bin/.../calculator.wasm
    """,
)
