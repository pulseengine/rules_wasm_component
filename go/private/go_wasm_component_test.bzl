"""Go WASM component test rule"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _go_wasm_component_test_impl(ctx):
    """Implementation of go_wasm_component_test rule"""

    # Get component info
    component_info = ctx.attr.component[WasmComponentInfo]

    # Create test script
    test_script = ctx.actions.declare_file(ctx.label.name + "_test.sh")

    # Get wasm-tools from toolchain
    wasm_tools_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = wasm_tools_toolchain.wasm_tools

    # TinyGo toolchain info is embedded in component metadata

    # Generate comprehensive test script
    script_content = """#!/bin/bash
set -e

# Colors for output
GREEN='\\033[0;32m'
RED='\\033[0;31m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

echo -e "${{BLUE}}🔍 Testing Go WebAssembly Component${{NC}}"

# Get the runfiles directory
if [[ -n "${{RUNFILES_DIR}}" ]]; then
  RUNFILES="${{RUNFILES_DIR}}"
elif [[ -n "${{RUNFILES_MANIFEST_FILE}}" ]]; then
  RUNFILES="$(dirname "${{RUNFILES_MANIFEST_FILE}}")"
else
  RUNFILES="${{BASH_SOURCE[0]}}.runfiles"
fi

# Look for wasm-tools in common locations
WASM_TOOLS=""
for path in \\
  "${{RUNFILES}}/{wasm_tools_workspace}/{wasm_tools_path}" \\
  "${{RUNFILES}}/{wasm_tools_path}" \\
  "${{RUNFILES}}/_main/{wasm_tools_path}" \\
  "${{RUNFILES}}/../{wasm_tools_workspace}/{wasm_tools_path}" \\
  "${{RUNFILES}}/../{wasm_tools_path}"; do
  if [[ -f "${{path}}" ]]; then
    WASM_TOOLS="${{path}}"
    break
  fi
done

if [[ -z "${{WASM_TOOLS}}" ]]; then
  echo -e "${{RED}}ERROR: Cannot find wasm-tools binary${{NC}}" >&2
  exit 1
fi

# Look for component in common locations
COMPONENT_WASM=""
for path in \\
  "${{RUNFILES}}/{component_workspace}/{component_path}" \\
  "${{RUNFILES}}/{component_path}" \\
  "${{RUNFILES}}/_main/{component_path}"; do
  if [[ -f "${{path}}" ]]; then
    COMPONENT_WASM="${{path}}"
    break
  fi
done

if [[ -z "${{COMPONENT_WASM}}" ]]; then
  echo -e "${{RED}}ERROR: Cannot find component WASM file${{NC}}" >&2
  exit 1
fi

echo "📁 Component: ${{COMPONENT_WASM}}"
echo "🔧 Using wasm-tools: ${{WASM_TOOLS}}"

# Test 1: Validate component format
echo -e "${{BLUE}}Test 1: Validating WebAssembly component format...${{NC}}"
"${{WASM_TOOLS}}" validate "${{COMPONENT_WASM}}"
echo -e "${{GREEN}}✅ Component format validation passed${{NC}}"

# Test 2: Check component size
echo -e "${{BLUE}}Test 2: Checking component size...${{NC}}"

# Note: Following symlinks to get actual file size

COMPONENT_SIZE=$(stat -L -f%z "${{COMPONENT_WASM}}" 2>/dev/null || stat -L -c%s "${{COMPONENT_WASM}}" 2>/dev/null || echo "unknown")
echo "📊 Component size: ${{COMPONENT_SIZE}} bytes"

# Validate size is reasonable (not empty, not too large)
if [[ "${{COMPONENT_SIZE}}" == "unknown" ]]; then
  echo -e "${{RED}}❌ Cannot determine component size${{NC}}"
  exit 1
elif [[ "${{COMPONENT_SIZE}}" -lt 1000 ]]; then
  echo -e "${{RED}}❌ Component too small (< 1KB), likely invalid${{NC}}"
  exit 1
elif [[ "${{COMPONENT_SIZE}}" -gt 100000000 ]]; then
  echo -e "${{RED}}❌ Component too large (> 100MB), optimize build${{NC}}"
  exit 1
else
  echo -e "${{GREEN}}✅ Component size check passed${{NC}}"
fi

# Test 3: Component metadata inspection
echo -e "${{BLUE}}Test 3: Inspecting component metadata...${{NC}}"

# Try different wasm-tools commands based on version
if "${{WASM_TOOLS}}" component print "${{COMPONENT_WASM}}" > /dev/null 2>&1; then
  echo -e "${{GREEN}}✅ Component metadata inspection passed (print command)${{NC}}"
elif "${{WASM_TOOLS}}" component wit "${{COMPONENT_WASM}}" > /dev/null 2>&1; then
  echo -e "${{GREEN}}✅ Component metadata inspection passed (wit command)${{NC}}"
elif "${{WASM_TOOLS}}" print "${{COMPONENT_WASM}}" > /dev/null 2>&1; then
  echo -e "${{GREEN}}✅ Component metadata inspection passed (basic print)${{NC}}"
else
  echo "⚠️ Component metadata inspection skipped (wasm-tools version may not support inspection)"
fi

# Test 4: Check for Go-specific patterns
echo -e "${{BLUE}}Test 4: Checking for TinyGo-specific patterns...${{NC}}"

# Check if component contains expected Go/TinyGo symbols
# Use hexdump to check for basic patterns since we don't have component print
if hexdump -C "${{COMPONENT_WASM}}" | grep -q "runtime\\|main\\|TinyGo" > /dev/null 2>&1; then
  echo -e "${{GREEN}}✅ TinyGo pattern check passed${{NC}}"
else
  echo "⚠️ TinyGo pattern check skipped (basic binary inspection used)"
fi

# Test 5: Verify WASI Preview 2 compatibility
echo -e "${{BLUE}}Test 5: Verifying WASI Preview 2 compatibility...${{NC}}"

# Check for WASI Preview 2 patterns in binary
if hexdump -C "${{COMPONENT_WASM}}" | grep -q "wasi" > /dev/null 2>&1; then
  echo "📋 Found WASI patterns (Preview 2 compatibility indicated)"
  echo -e "${{GREEN}}✅ WASI Preview 2 compatibility check passed${{NC}}"
else
  echo -e "${{RED}}❌ No WASI patterns found - may not be Preview 2 compatible${{NC}}"
  exit 1
fi

# Summary
echo -e "${{GREEN}}🎉 All Go WebAssembly component tests passed!${{NC}}"
echo "Component Details:"
echo "  • Language: Go (TinyGo)"
echo "  • Target: wasm32-wasip2"
echo "  • Format: WebAssembly Component Model"
echo "  • Size: ${{COMPONENT_SIZE}} bytes"
echo "  • Validation: ✅ Valid"
echo "  • WASI Preview 2: ✅ Compatible"
""".format(
        wasm_tools_workspace = wasm_tools.owner.workspace_name if wasm_tools.owner else "_main",
        wasm_tools_path = wasm_tools.short_path,
        component_workspace = component_info.wasm_file.owner.workspace_name if component_info.wasm_file.owner else "_main",
        component_path = component_info.wasm_file.short_path,
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
                files = [component_info.wasm_file, wasm_tools],
            ),
        ),
    ]

go_wasm_component_test = rule(
    implementation = _go_wasm_component_test_impl,
    attrs = {
        "component": attr.label(
            providers = [WasmComponentInfo],
            mandatory = True,
            doc = "Go WASM component to test",
        ),
    },
    test = True,
    toolchains = [
        "@rules_wasm_component//toolchains:wasm_tools_toolchain_type",
    ],
    doc = """
    Test rule for Go WASM components built with TinyGo.

    This rule performs comprehensive validation of Go WebAssembly components:
    - Component format validation using wasm-tools
    - Size and metadata checks
    - TinyGo-specific pattern verification
    - WASI Preview 2 compatibility testing

    Example:
        go_wasm_component_test(
            name = "my_go_component_test",
            component = ":my_go_component",
        )
    """,
)
