"""Bazel rules for building documentation using hermetic Node.js toolchain"""

def _docs_build_impl(ctx):
    """Implementation of docs_build rule using jco_toolchain"""

    # Get jco toolchain for hermetic Node.js access
    jco_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:jco_toolchain_type"]
    node = jco_toolchain.node
    npm = jco_toolchain.npm

    # Output documentation archive
    docs_archive = ctx.actions.declare_file(ctx.attr.name + "_site.tar.gz")

    # Input source files and package.json
    source_files = ctx.files.srcs
    package_json = ctx.file.package_json

    # Create a comprehensive build script that handles everything
    build_script = ctx.actions.declare_file(ctx.attr.name + "_build_docs.sh")
    ctx.actions.write(
        output = build_script,
        content = """
#!/bin/bash
set -euo pipefail

NODE="$1"
NPM="$2"
OUTPUT_TAR="$3"
PACKAGE_JSON="$4"
shift 4

# Create temporary workspace
WORK_DIR="$(mktemp -d)"
echo "Working in: $WORK_DIR"

# Copy package.json
cp "$PACKAGE_JSON" "$WORK_DIR/package.json"

# Copy all source files, maintaining docs-site structure
for src_file in "$@"; do
    if [[ "$src_file" == docs-site/* ]]; then
        # Remove docs-site/ prefix to get relative path  
        rel_path="${src_file#docs-site/}"
        dest_file="$WORK_DIR/$rel_path"
        dest_dir="$(dirname "$dest_file")"
        mkdir -p "$dest_dir"
        cp "$src_file" "$dest_file"
    fi
done

# Change to workspace
cd "$WORK_DIR"

# Install dependencies using hermetic npm
"$NPM" install --no-audit --no-fund

# Build documentation site
"$NPM" run build

# Package the built site
tar -czf "$OUTPUT_TAR" -C dist .

echo "Documentation build complete: $OUTPUT_TAR"
        """,
        is_executable = True,
    )

    # Run the comprehensive build script
    build_args = [node.path, npm.path, docs_archive.path, package_json.path]
    for src in source_files:
        if src.path.startswith("docs-site/"):
            build_args.append(src.path)

    ctx.actions.run(
        executable = build_script,
        arguments = build_args,
        inputs = source_files + [package_json],
        outputs = [docs_archive],
        tools = [node, npm],
        mnemonic = "BuildDocs",
        progress_message = "Building documentation site %s with hermetic Node.js" % ctx.label,
        execution_requirements = {
            "local": "1",  # npm install needs network
        },
        use_default_shell_env = True,
    )

    return [
        DefaultInfo(files = depset([docs_archive])),
        OutputGroupInfo(
            docs_archive = depset([docs_archive]),
        ),
    ]

docs_build = rule(
    implementation = _docs_build_impl,
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
    doc = """
    Builds documentation site using hermetic Node.js and npm from jco_toolchain.
    
    This rule follows the Bazel Way by properly using toolchains instead of 
    direct file references in genrules.
    
    Example:
        docs_build(
            name = "site",
            srcs = glob(["src/**/*", "public/**/*"]),
            package_json = "package.json",
        )
    """,
)
