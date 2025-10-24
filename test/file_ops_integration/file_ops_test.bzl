"""Integration test rule for file operations components"""

load("//tools/bazel_helpers:file_ops_actions.bzl", "prepare_workspace_action")

def _file_ops_integration_test_impl(ctx):
    """Test that file operations work correctly"""

    # Create a test workspace using file_ops_actions
    config = {
        "work_dir": ctx.label.name + "_workspace",
        "workspace_type": "generic",
        "sources": [
            {"source": ctx.file.test_input, "destination": "input.txt", "preserve_permissions": False},
        ],
        "headers": [],
        "dependencies": [],
    }

    workspace_dir = prepare_workspace_action(ctx, config)

    # Create a wrapper script that passes the workspace path to the test
    test_script = ctx.actions.declare_file(ctx.label.name + "_test.sh")

    # Get the workspace directory short path for the test
    workspace_path = workspace_dir.short_path

    ctx.actions.write(
        output = test_script,
        content = """#!/bin/bash
set -e

# Find the workspace directory in runfiles
if [ -n "$TEST_SRCDIR" ]; then
    WORKSPACE_DIR="$TEST_SRCDIR/_main/{workspace_path}"
else
    WORKSPACE_DIR="{workspace_path}"
fi

echo "Testing file operations workspace: $WORKSPACE_DIR"

# Verify workspace directory exists
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "FAIL: Workspace directory not created"
    exit 1
fi

# Verify input file was copied
if [ ! -f "$WORKSPACE_DIR/input.txt" ]; then
    echo "FAIL: Input file not found in workspace"
    exit 1
fi

# Verify file content
EXPECTED_CONTENT="{expected_content}"
ACTUAL_CONTENT=$(cat "$WORKSPACE_DIR/input.txt")
if [ "$ACTUAL_CONTENT" != "$EXPECTED_CONTENT" ]; then
    echo "FAIL: File content mismatch"
    echo "Expected: $EXPECTED_CONTENT"
    echo "Actual: $ACTUAL_CONTENT"
    exit 1
fi

echo "PASS: All file operations tests passed"
echo "Implementation used: {implementation}"
""".format(
            workspace_path = workspace_path,
            expected_content = ctx.attr.expected_content,
            implementation = ctx.attr.implementation,
        ),
        is_executable = True,
    )

    # Create runfiles that include the workspace
    runfiles = ctx.runfiles(files = [workspace_dir, test_script])

    return [
        DefaultInfo(
            executable = test_script,
            runfiles = runfiles,
        ),
    ]

file_ops_integration_test = rule(
    implementation = _file_ops_integration_test_impl,
    attrs = {
        "test_input": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Test input file to copy",
        ),
        "expected_content": attr.string(
            mandatory = True,
            doc = "Expected content of the input file",
        ),
        "implementation": attr.string(
            default = "default",
            doc = "Which implementation is being tested",
        ),
        "_file_ops_component": attr.label(
            default = "//tools/file_ops:file_ops",
            executable = True,
            cfg = "exec",
        ),
    },
    test = True,
    toolchains = ["@rules_wasm_component//toolchains:file_ops_toolchain_type"],
)
