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


    # Prepare input files list
    input_file_args = []
    for src in source_files:
        if src.path.startswith("docs-site/"):
            input_file_args.append(src.path)

    ctx.actions.run_shell(
        command = """
        set -euo pipefail
        
        # Store execution root and output path
        EXEC_ROOT="$(pwd)"
        OUTPUT_TAR="$1"
        PACKAGE_JSON="$2"
        shift 2

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

        # Change to workspace for npm operations
        cd "$WORK_DIR"

        # Install dependencies using hermetic npm (from PATH via tools)
        npm install --no-audit --no-fund

        # Build documentation site
        npm run build

        # Return to execution root and create output file there
        cd "$EXEC_ROOT"
        mkdir -p "$(dirname "$OUTPUT_TAR")"
        tar -czf "$OUTPUT_TAR" -C "$WORK_DIR/dist" .

        echo "Documentation build complete: $OUTPUT_TAR"
        """,
        arguments = [docs_archive.path, package_json.path] + input_file_args,
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
