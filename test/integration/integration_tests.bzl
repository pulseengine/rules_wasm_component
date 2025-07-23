"""Custom test rules for WebAssembly component integration testing."""

def _component_validation_test_impl(ctx):
    """Implementation for component validation test."""
    
    component_file = ctx.file.component
    test_script = ctx.actions.declare_file(ctx.label.name + "_test.sh")
    
    # Create test script content
    script_content = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "COMPONENT=\"$1\"",
        "echo \"Validating component: $COMPONENT\"",
        "",
        "# Check file exists and has reasonable size",
        "if [[ ! -f \"$COMPONENT\" ]]; then",
        "    echo \"ERROR: Component file not found\"",
        "    exit 1",
        "fi",
        "",
        "SIZE=$(stat -c%s \"$COMPONENT\" 2>/dev/null || stat -f%z \"$COMPONENT\" 2>/dev/null)",
        "if [[ $SIZE -lt 100 ]]; then",
        "    echo \"ERROR: Component too small ($SIZE bytes)\"",
        "    exit 1",
        "fi",
        "",
        "echo \"Component size: $SIZE bytes\"",
        "",
        "# Validate with wasm-tools if available",
        "if command -v wasm-tools >/dev/null 2>&1; then",
        "    echo \"Validating with wasm-tools...\"",
        "    wasm-tools validate \"$COMPONENT\"",
        "    echo \"✓ Component is valid WASM\"",
        "    ",
        "    # Extract WIT interface if it's a component",
        "    if wasm-tools component wit \"$COMPONENT\" > /tmp/component.wit 2>/dev/null; then",
        "        echo \"Component WIT interface:\"",
    ]
    
    # Add export validation
    for export in ctx.attr.expected_exports:
        script_content.extend([
            "        if grep -q '{}' /tmp/component.wit; then".format(export),
            "            echo \"✓ Found expected export: {}\"".format(export),
            "        else",
            "            echo \"✗ Missing expected export: {}\"".format(export),
            "            exit 1",
            "        fi",
        ])
    
    # Add import validation
    for import_name in ctx.attr.expected_imports:
        script_content.extend([
            "        if grep -q '{}' /tmp/component.wit; then".format(import_name),
            "            echo \"✓ Found expected import: {}\"".format(import_name),
            "        else",
            "            echo \"✗ Missing expected import: {}\"".format(import_name),
            "            exit 1",
            "        fi",
        ])
    
    script_content.extend([
        "    else",
        "        echo \"Could not extract WIT interface (might be core module)\"",
        "    fi",
        "else",
        "    echo \"wasm-tools not available, basic validation only\"",
        "fi",
        "",
        "echo \"✓ Component validation passed!\"",
    ])
    
    ctx.actions.write(
        output = test_script,
        content = "\n".join(script_content),
        is_executable = True,
    )
    
    # Create test runner that passes the component path
    runner = ctx.actions.declare_file(ctx.label.name + "_runner.sh")
    ctx.actions.write(
        output = runner,
        content = """#!/bin/bash
exec "{}" "{}"
""".format(test_script.short_path, component_file.short_path),
        is_executable = True,
    )
    
    return DefaultInfo(
        executable = runner,
        runfiles = ctx.runfiles(files = [component_file, test_script]),
    )

component_validation_test = rule(
    implementation = _component_validation_test_impl,
    test = True,
    attrs = {
        "component": attr.label(
            allow_single_file = [".wasm"],
            mandatory = True,
            doc = "The WASM component to validate",
        ),
        "expected_exports": attr.string_list(
            default = [],
            doc = "List of expected export names to validate",
        ),
        "expected_imports": attr.string_list(
            default = [],
            doc = "List of expected import names to validate",
        ),
    },
    doc = "Test rule that validates a WASM component structure and interfaces",
)