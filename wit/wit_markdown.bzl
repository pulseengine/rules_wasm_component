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

    # Create documentation collection script for cross-platform file operations
    collection_script = ctx.actions.declare_file(ctx.attr.name + "_collect_docs.py")
    script_content = '''#!/usr/bin/env python3
import os
import shutil
import sys
from pathlib import Path

def main():
    output_dir = sys.argv[1]
    index_file = sys.argv[2]
    doc_dirs = sys.argv[3:]

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Collect documentation files from all input directories
    collected_files = []

    for doc_dir in doc_dirs:
        if os.path.isdir(doc_dir):
            doc_path = Path(doc_dir)

            # Find all markdown and HTML files
            for pattern in ["*.md", "*.html"]:
                for file_path in doc_path.glob(pattern):
                    if file_path.is_file():
                        dest_name = file_path.name
                        dest_path = os.path.join(output_dir, dest_name)

                        try:
                            shutil.copy2(str(file_path), dest_path)
                            collected_files.append(dest_name)
                            print(f"Copied: {file_path} -> {dest_name}")
                        except Exception as e:
                            print(f"Warning: Failed to copy {file_path}: {e}")

    # Copy the pre-generated index file
    try:
        shutil.copy2(index_file, os.path.join(output_dir, "index.md"))
        collected_files.append("index.md")
        print(f"Copied index: {index_file}")
    except Exception as e:
        print(f"Error copying index: {e}")
        sys.exit(1)

    print(f"Documentation collection complete: {len(collected_files)} files")

    # Create a manifest of collected files for debugging
    manifest_path = os.path.join(output_dir, ".collection_manifest")
    with open(manifest_path, 'w') as f:
        f.write("\\n".join(sorted(collected_files)))

if __name__ == "__main__":
    main()
'''

    ctx.actions.write(
        output = collection_script,
        content = script_content,
        is_executable = True,
    )

    # Run documentation collection using structured script
    ctx.actions.run(
        executable = collection_script,
        arguments = [docs_dir.path, index_file.path] + [f.path for f in doc_dirs],
        inputs = doc_dirs + [index_file, collection_script],
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
