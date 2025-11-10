"""Stardoc with Astro frontmatter - Pure Bazel, no shell commands"""

load("@stardoc//stardoc:stardoc.bzl", "stardoc")

def _add_frontmatter_impl(ctx):
    """Add Astro frontmatter to Stardoc output using pure Bazel actions"""

    stardoc_file = ctx.file.src
    output = ctx.outputs.out

    # Step 1: Create frontmatter file using ctx.actions.write (pure Bazel!)
    frontmatter_content = """---
title: {}
description: {}
---

""".format(ctx.attr.title, ctx.attr.description)

    frontmatter_file = ctx.actions.declare_file(ctx.label.name + "_frontmatter.md")
    ctx.actions.write(
        output = frontmatter_file,
        content = frontmatter_content,
    )

    # Step 2: Concatenate using ctx.actions.run with file_ops_component
    file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
    file_ops = file_ops_toolchain.file_ops_component

    ctx.actions.run(
        executable = file_ops,
        arguments = [
            "concatenate-files",
            "--inputs",
            frontmatter_file.path,
            stardoc_file.path,
            "--output",
            output.path,
        ],
        inputs = [frontmatter_file, stardoc_file],
        outputs = [output],
        mnemonic = "AddFrontmatter",
        progress_message = "Adding Astro frontmatter to %s" % stardoc_file.short_path,
    )

    return [DefaultInfo(files = depset([output]))]

add_frontmatter = rule(
    implementation = _add_frontmatter_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = [".md"],
            mandatory = True,
            doc = "Stardoc-generated markdown file",
        ),
        "title": attr.string(
            mandatory = True,
            doc = "Astro page title",
        ),
        "description": attr.string(
            mandatory = True,
            doc = "Astro page description",
        ),
        "out": attr.output(
            mandatory = True,
            doc = "Output file with frontmatter",
        ),
    },
    toolchains = ["@rules_wasm_component//toolchains:file_ops_toolchain_type"],
    doc = "Add Astro frontmatter to Stardoc output using file_ops_component",
)

def stardoc_with_frontmatter(name, input, title, description, deps = []):
    """Generate Stardoc output with Astro frontmatter.

    Pure Bazel implementation - no shell commands!

    Args:
        name: Target name (e.g., "cpp_component_stardoc")
        input: Input .bzl file (e.g., "//cpp:defs.bzl")
        title: Astro page title
        description: Astro page description
        deps: bzl_library dependencies
    """

    # Generate raw Stardoc
    stardoc(
        name = name + "_raw",
        input = input,
        out = name + "_raw.md",
        deps = deps,
    )

    # Add frontmatter using pure Bazel + file_ops_component
    add_frontmatter(
        name = name,
        src = ":" + name + "_raw",
        title = title,
        description = description,
        out = name + ".md",
    )
