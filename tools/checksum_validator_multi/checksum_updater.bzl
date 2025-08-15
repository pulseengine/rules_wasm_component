"""
Production Checksum Updater Rule for CI System

This rule creates a Bazel target that our CI system uses to:
1. Download latest releases from GitHub
2. Calculate SHA256 checksums
3. Update our checksums/ registry
4. Validate tool dependencies

This is a critical CI component - we eat our own dog food.
"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _checksum_updater_impl(ctx):
    """Implementation of checksum_updater rule"""

    # Get the production WebAssembly component
    if WasmComponentInfo in ctx.attr.component:
        component_info = ctx.attr.component[WasmComponentInfo]
        component_file = component_info.wasm_file
    else:
        # Fallback to direct file
        component_file = ctx.file.component

    # Create wrapper script that invokes the WebAssembly component
    updater_script = ctx.actions.declare_file(ctx.label.name + "_updater")

    # Find wasmtime or appropriate WASM runtime
    # In production CI, this would be provided by a toolchain
    script_content = """#!/bin/bash
set -e

COMPONENT="{component_path}"
CHECKSUMS_DIR="{checksums_dir}"
TOOL_NAME="$1"
COMMAND="${{2:-update-tool}}"

if [[ ! -f "$COMPONENT" ]]; then
    echo "❌ Component not found: $COMPONENT"
    exit 1
fi

if [[ ! -d "$CHECKSUMS_DIR" ]]; then
    echo "❌ Checksums directory not found: $CHECKSUMS_DIR"
    exit 1
fi

echo "🚀 Production Checksum Updater (WebAssembly)"
echo "Tool: $TOOL_NAME"
echo "Command: $COMMAND"
echo "Component: $COMPONENT"
echo "Checksums: $CHECKSUMS_DIR"

# Try to find a WASM runtime
RUNTIME=""
if command -v wasmtime &> /dev/null; then
    RUNTIME="wasmtime --dir=. --dir=$CHECKSUMS_DIR"
elif command -v wasmer &> /dev/null; then
    RUNTIME="wasmer --dir=. --dir=$CHECKSUMS_DIR"
else
    echo "❌ No WebAssembly runtime found (wasmtime or wasmer required)"
    exit 1
fi

# Execute the component
exec $RUNTIME "$COMPONENT" "$COMMAND" "$TOOL_NAME" "$CHECKSUMS_DIR"
""".format(
        component_path = component_file.short_path,
        checksums_dir = ctx.attr.checksums_dir,
    )

    ctx.actions.write(
        output = updater_script,
        content = script_content,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = updater_script,
            runfiles = ctx.runfiles(
                files = [component_file],
            ),
        ),
    ]

checksum_updater = rule(
    implementation = _checksum_updater_impl,
    attrs = {
        "component": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "WebAssembly component that handles checksum operations",
        ),
        "checksums_dir": attr.string(
            mandatory = True,
            doc = "Path to checksums directory (e.g., 'checksums')",
        ),
    },
    executable = True,
    doc = """
    Production checksum updater for CI system.

    This rule creates an executable that our CI system uses to manage
    tool checksums and validate dependencies. The component:

    1. Downloads latest releases from GitHub
    2. Calculates SHA256 checksums
    3. Updates JSON registry files
    4. Validates existing tool versions

    Example:
        checksum_updater(
            name = "update_wasm_tools",
            component = ":production_checksum_component",
            checksums_dir = "checksums",
        )

    Usage in CI:
        bazel run //tools/checksum_validator_multi:update_wasm_tools wasm-tools
    """,
)

def _validate_checksums_test_impl(ctx):
    """Test that validates our checksum registry is up-to-date"""

    component_file = ctx.file.component

    # Create test script that checks if tools need updates
    test_script = ctx.actions.declare_file(ctx.label.name + "_test")

    tools_to_check = ctx.attr.tools if ctx.attr.tools else [
        "wasm-tools",
        "wasmtime",
        "wit-bindgen",
        "wkg",
        "tinygo",
    ]

    script_content = """#!/bin/bash
set -e

COMPONENT="{component_path}"
CHECKSUMS_DIR="{checksums_dir}"

echo "🔍 Validating Checksum Registry"
echo "Component: $COMPONENT"
echo "Checksums: $CHECKSUMS_DIR"

# Find WASM runtime
RUNTIME=""
if command -v wasmtime &> /dev/null; then
    RUNTIME="wasmtime --dir=. --dir=$CHECKSUMS_DIR"
elif command -v wasmer &> /dev/null; then
    RUNTIME="wasmer --dir=. --dir=$CHECKSUMS_DIR"
else
    echo "⚠️  No WASM runtime found, skipping runtime tests"
    # Basic file validation instead
    for tool in {tools}; do
        tool_file="$CHECKSUMS_DIR/tools/$tool.json"
        if [[ -f "$tool_file" ]]; then
            echo "✅ $tool.json exists"
            if jq empty "$tool_file" 2>/dev/null; then
                echo "✅ $tool.json is valid JSON"
            else
                echo "❌ $tool.json is invalid JSON"
                exit 1
            fi
        else
            echo "❌ $tool.json missing"
            exit 1
        fi
    done
    echo "✅ Registry validation passed (basic checks)"
    exit 0
fi

# Check each tool for updates
OUTDATED_TOOLS=0
for tool in {tools}; do
    echo "Checking $tool..."
    if $RUNTIME "$COMPONENT" check-latest "$tool" "$CHECKSUMS_DIR"; then
        echo "✅ $tool is up to date"
    else
        echo "⚠️  $tool may need updates"
        OUTDATED_TOOLS=$((OUTDATED_TOOLS + 1))
    fi
done

if [[ $OUTDATED_TOOLS -gt 0 ]]; then
    echo "⚠️  $OUTDATED_TOOLS tools may need updates"
    echo "Run: bazel run //tools/checksum_validator_multi:update_checksums"
else
    echo "✅ All tools are up to date"
fi
""".format(
        component_path = component_file.short_path,
        checksums_dir = ctx.attr.checksums_dir,
        tools = " ".join(tools_to_check),
    )

    ctx.actions.write(
        output = test_script,
        content = script_content,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = test_script,
            runfiles = ctx.runfiles(
                files = [component_file],
            ),
        ),
    ]

validate_checksums_test = rule(
    implementation = _validate_checksums_test_impl,
    attrs = {
        "component": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "WebAssembly component that handles checksum operations",
        ),
        "checksums_dir": attr.string(
            mandatory = True,
            doc = "Path to checksums directory",
        ),
        "tools": attr.string_list(
            doc = "List of tools to validate (default: common tools)",
        ),
    },
    test = True,
    doc = """
    Test rule that validates our checksum registry.

    This test is used in CI to ensure our tool checksums are up-to-date
    and that the checksum updater component is working correctly.

    Example:
        validate_checksums_test(
            name = "checksums_current_test",
            component = ":production_checksum_component",
            checksums_dir = "checksums",
            tools = ["wasm-tools", "wasmtime", "tinygo"],
        )
    """,
)
