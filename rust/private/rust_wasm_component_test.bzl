"""Rust WASM component test rule"""

load("//providers:providers.bzl", "WasmComponentInfo")

def _rust_wasm_component_test_impl(ctx):
    """Implementation of rust_wasm_component_test rule"""

    # Get component info
    component_info = ctx.attr.component[WasmComponentInfo]

    # Create test script
    test_script = ctx.actions.declare_file(ctx.label.name + "_test.sh")

    # Get wasmtime from toolchain (if available)
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wasm_tools = toolchain.wasm_tools

    # Generate test script that uses runfiles
    script_content = """#!/bin/bash
set -e

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
  echo "ERROR: Cannot find wasm-tools binary" >&2
  echo "Searched in:" >&2
  echo "  ${{RUNFILES}}/{wasm_tools_workspace}/{wasm_tools_path}" >&2
  echo "  ${{RUNFILES}}/{wasm_tools_path}" >&2
  echo "  ${{RUNFILES}}/_main/{wasm_tools_path}" >&2
  echo "  ${{RUNFILES}}/../{wasm_tools_workspace}/{wasm_tools_path}" >&2
  echo "  ${{RUNFILES}}/../{wasm_tools_path}" >&2
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
  echo "ERROR: Cannot find component WASM file" >&2
  echo "Searched in:" >&2
  echo "  ${{RUNFILES}}/{component_workspace}/{component_path}" >&2
  echo "  ${{RUNFILES}}/{component_path}" >&2
  echo "  ${{RUNFILES}}/_main/{component_path}" >&2
  exit 1
fi

# Validate component
echo "Validating WASM component..."
"${{WASM_TOOLS}}" validate "${{COMPONENT_WASM}}"

# TODO: Run component with wasmtime if available
echo "✅ Component validation passed"
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

rust_wasm_component_test = rule(
    implementation = _rust_wasm_component_test_impl,
    attrs = {
        "component": attr.label(
            providers = [WasmComponentInfo],
            mandatory = True,
            doc = "WASM component to test",
        ),
    },
    test = True,
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """
    Test rule for Rust WASM components.

    This rule validates WASM components and can run basic tests.

    Example:
        rust_wasm_component_test(
            name = "my_component_test",
            component = ":my_component",
        )
    """,
)
