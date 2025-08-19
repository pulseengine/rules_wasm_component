"""Bazel rule for running documentation development server with live reload"""

def _docs_dev_server_impl(ctx):
    """Implementation of docs_dev_server rule for local development"""
    
    # Get jco toolchain for hermetic Node.js access  
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    node = jco_toolchain.node
    npm = jco_toolchain.npm
    
    # Create runner script
    runner = ctx.actions.declare_file(ctx.attr.name + "_runner.sh")
    
    # Input source files and package.json
    source_files = ctx.files.srcs
    package_json = ctx.file.package_json
    
    # Prepare source file list
    source_paths = []
    for src in source_files:
        if src.path.startswith("docs-site/"):
            source_paths.append(src.path)
    
    ctx.actions.write(
        output = runner,
        content = """#!/bin/bash
set -euo pipefail

# Store paths
EXEC_ROOT="$(pwd)"
PACKAGE_JSON="{package_json}"
NODE="{node}"
NPM="{npm}"

# Create temporary workspace
WORK_DIR="$(mktemp -d)"
echo "🚀 Setting up documentation development server in: $WORK_DIR"

# Cleanup on exit
trap "echo '🛑 Shutting down dev server...'; rm -rf $WORK_DIR" EXIT

# Copy package.json
cp "$PACKAGE_JSON" "$WORK_DIR/package.json"

# Copy all source files
echo "📦 Copying source files..."
{copy_commands}

# Change to workspace
cd "$WORK_DIR"

# Install dependencies
echo "📥 Installing dependencies..."
$NPM install --no-audit --no-fund

# Start development server
echo "🌐 Starting Astro development server..."
echo "📍 Documentation will be available at: http://localhost:4321"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Run dev server
$NPM run dev
""".format(
            package_json = package_json.path,
            node = node.path,
            npm = npm.path,
            copy_commands = "\n".join([
                'if [[ "{src}" == docs-site/* ]]; then\n' +
                '    rel_path="${{src#docs-site/}}"\n'.format(src=src) +
                '    dest_file="$WORK_DIR/$rel_path"\n' +
                '    dest_dir="$(dirname "$dest_file")"\n' +
                '    mkdir -p "$dest_dir"\n' +
                '    cp "{src}" "$dest_file"\n'.format(src=src) +
                'fi'
                for src in source_paths
            ])
        ),
        is_executable = True,
    )
    
    return [
        DefaultInfo(
            files = depset([runner]),
            runfiles = ctx.runfiles(
                files = source_files + [package_json, node, npm],
            ),
            executable = runner,
        ),
    ]

docs_dev_server = rule(
    implementation = _docs_dev_server_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "Documentation source files",
        ),
        "package_json": attr.label(
            allow_single_file = ["package.json"],
            mandatory = True,
            doc = "package.json file with dependencies",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:jco_toolchain_type"],
    executable = True,
    doc = """
    Runs a development server for the documentation site with live reload.
    
    This rule starts an Astro dev server on http://localhost:4321 with hot module
    replacement for rapid documentation development.
    
    Example:
        docs_dev_server(
            name = "docs_dev",
            srcs = glob(["src/**/*", "public/**/*", "*.json", "*.mjs"]),
            package_json = "package.json",
        )
        
    Run with:
        bazel run //docs-site:docs_dev
    """,
)