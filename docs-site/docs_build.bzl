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

    # Create documentation build script for better cross-platform support
    build_script = ctx.actions.declare_file(ctx.label.name + "_build_docs.py")
    script_content = '''#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

def main():
    if len(sys.argv) < 5:
        print("Usage: build_docs.py <output_tar> <package_json> <npm_binary> <src_files...>")
        sys.exit(1)

    output_tar = sys.argv[1]
    package_json = sys.argv[2]
    npm_binary = sys.argv[3]
    src_files = sys.argv[4:]

    # Create temporary workspace
    with tempfile.TemporaryDirectory() as work_dir:
        print(f"Working in: {work_dir}")

        # Copy package.json
        shutil.copy2(package_json, os.path.join(work_dir, "package.json"))
        print(f"Copied package.json")

        # Copy all source files, maintaining docs-site structure
        copied_files = 0
        for src_file in src_files:
            if src_file.startswith("docs-site/"):
                # Remove docs-site/ prefix to get relative path
                rel_path = src_file[10:]  # len("docs-site/") = 10
                dest_file = os.path.join(work_dir, rel_path)
                dest_dir = os.path.dirname(dest_file)

                # Ensure parent directory exists
                os.makedirs(dest_dir, exist_ok=True)

                # Copy file
                shutil.copy2(src_file, dest_file)
                copied_files += 1

        print(f"Copied {copied_files} source files")

        # Resolve npm binary to absolute path before changing directory
        npm_abs_path = os.path.abspath(npm_binary)
        
        # Change to workspace for npm operations
        original_cwd = os.getcwd()
        os.chdir(work_dir)

        try:
            # Install dependencies using hermetic npm
            print(f"Installing npm dependencies using: {npm_abs_path}")
            result = subprocess.run(
                [npm_abs_path, "install", "--no-audit", "--no-fund"],
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            if result.returncode != 0:
                print(f"npm install failed: {result.stderr}")
                sys.exit(1)

            print("npm install completed successfully")

            # Build documentation site
            print("Building documentation site...")
            result = subprocess.run(
                [npm_abs_path, "run", "build"],
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            if result.returncode != 0:
                print(f"npm run build failed: {result.stderr}")
                sys.exit(1)

            print("Documentation build completed successfully")

            # Return to original directory and create output archive
            os.chdir(original_cwd)

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_tar), exist_ok=True)

            # Create tar archive from dist directory
            dist_dir = os.path.join(work_dir, "dist")
            if not os.path.exists(dist_dir):
                print(f"Error: dist directory not found at {dist_dir}")
                sys.exit(1)

            # Use tar command for compression
            result = subprocess.run(
                ["tar", "-czf", output_tar, "-C", dist_dir, "."],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                print(f"tar creation failed: {result.stderr}")
                sys.exit(1)

            print(f"Documentation build complete: {output_tar}")

        except subprocess.TimeoutExpired as e:
            print(f"Build process timed out: {e}")
            sys.exit(1)
        except Exception as e:
            print(f"Build process failed: {e}")
            sys.exit(1)

if __name__ == "__main__":
    main()
'''

    ctx.actions.write(
        output = build_script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        executable = build_script,
        arguments = [docs_archive.path, package_json.path, npm.path] + input_file_args,
        inputs = source_files + [package_json, build_script],
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
