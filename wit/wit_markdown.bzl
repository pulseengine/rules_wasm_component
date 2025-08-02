"""WIT documentation generation rules

Provides rules for generating markdown documentation from WIT files using wit-bindgen.
This enables automatic documentation generation for all WIT interfaces in examples.
"""

load("//providers:providers.bzl", "WitInfo")

def _wit_markdown_impl(ctx):
    """Implementation of wit_markdown rule for generating documentation"""

    # Get wit-bindgen from toolchain
    toolchain = ctx.toolchains["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"]
    wit_bindgen = toolchain.wit_bindgen

    # Get WIT info from input
    wit_info = ctx.attr.wit[WitInfo]

    # Output directory for markdown generation (wit-bindgen uses --out-dir)
    output_dir = ctx.actions.declare_directory(ctx.attr.name + "_markdown")

    # Get the WIT library directory for dependency resolution
    wit_library_dir = None
    if hasattr(ctx.attr.wit[DefaultInfo], "files"):
        for file in ctx.attr.wit[DefaultInfo].files.to_list():
            if file.is_directory:
                wit_library_dir = file
                break

    if not wit_library_dir:
        fail("No WIT library directory found for markdown generation")

    # Build wit-bindgen markdown command
    cmd_args = ["markdown"]

    # Add world if specified
    if wit_info.world_name:
        cmd_args.extend(["--world", wit_info.world_name])

    # Add output directory
    cmd_args.extend(["--out-dir", output_dir.path])

    # Add WIT library directory as input
    cmd_args.append(wit_library_dir.path)

    ctx.actions.run(
        executable = wit_bindgen,
        arguments = cmd_args,
        inputs = depset(
            direct = [wit_library_dir],
            transitive = [wit_info.wit_files, wit_info.wit_deps],
        ),
        outputs = [output_dir],
        mnemonic = "WitMarkdown",
        progress_message = "Generating markdown documentation for %s" % ctx.attr.name,
    )

    return [
        DefaultInfo(files = depset([output_dir])),
    ]

# WIT markdown documentation generation rule
wit_markdown = rule(
    implementation = _wit_markdown_impl,
    attrs = {
        "wit": attr.label(
            doc = "WIT library target to generate documentation for",
            providers = [WitInfo],
            mandatory = True,
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:wasm_tools_toolchain_type"],
    doc = """Generates markdown documentation from WIT files using wit-bindgen.

This rule uses wit-bindgen's markdown output to generate comprehensive
documentation for WIT interfaces, including types, functions, and worlds.

Example:
    wit_markdown(
        name = "calculator_docs",
        wit = ":calculator_wit",
    )
""",
)

def _wit_docs_collection_impl(ctx):
    """Implementation for collecting multiple WIT documentation files"""

    # Collect all documentation directories from dependencies
    doc_dirs = []
    for target in ctx.attr.docs:
        doc_dirs.extend(target[DefaultInfo].files.to_list())

    # Create a consolidated documentation directory
    docs_dir = ctx.actions.declare_directory(ctx.attr.name)

    # Modern approach: Generate index content and copy files in a single action

    # Generate index.md content
    index_content = """# WIT Interface Documentation

This directory contains automatically generated documentation for all WIT interfaces in the examples.

## Available Interfaces

"""

    # Create list of available docs based on input directories
    for doc_dir in doc_dirs:
        doc_name = doc_dir.basename.replace("_markdown", "").replace("_", " ").title()
        index_content += "- [{}](./{}.md)\n".format(doc_name, doc_dir.basename)

    # Create pre-generated index file
    index_file = ctx.actions.declare_file(ctx.attr.name + "_index.md")
    ctx.actions.write(
        output = index_file,
        content = index_content,
    )

    # Copy all files and create index in one cleaner action
    ctx.actions.run_shell(
        command = """
        mkdir -p {output_dir}

        # Copy documentation files using find (more reliable than glob)
        for doc_dir in {docs}; do
            if [ -d "$doc_dir" ]; then
                find "$doc_dir" -name "*.md" -exec cp {{}} {output_dir}/ \\; 2>/dev/null || true
                find "$doc_dir" -name "*.html" -exec cp {{}} {output_dir}/ \\; 2>/dev/null || true
            fi
        done

        # Copy pre-generated index
        cp {index_file} {output_dir}/index.md
        """.format(
            output_dir = docs_dir.path,
            docs = " ".join([f.path for f in doc_dirs]),
            index_file = index_file.path,
        ),
        inputs = doc_dirs + [index_file],
        outputs = [docs_dir],
        mnemonic = "WitDocsCollection",
        progress_message = "Collecting WIT documentation for %s" % ctx.attr.name,
    )

    return [
        DefaultInfo(files = depset([docs_dir])),
    ]

# Rule for collecting multiple WIT documentation files
wit_docs_collection = rule(
    implementation = _wit_docs_collection_impl,
    attrs = {
        "docs": attr.label_list(
            doc = "List of wit_markdown targets to collect",
            providers = [DefaultInfo],
            mandatory = True,
        ),
    },
    doc = """Collects multiple WIT markdown documentation files into a single directory.

This rule creates a documentation directory containing all generated WIT
documentation files along with an index.md file linking to each document.

Example:
    wit_docs_collection(
        name = "all_docs",
        docs = [
            "//examples/go_component:calculator_docs",
            "//examples/js_component:hello_docs",
        ],
    )
""",
)
