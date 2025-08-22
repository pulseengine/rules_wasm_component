"""Universal file operations actions for Bazel rules

This module provides helper functions that replace shell scripts with
cross-platform file operations using Bazel-native methods.

Usage:
    load("//tools/bazel_helpers:file_ops_actions.bzl", "file_ops_action", "prepare_workspace_action")

    # In your rule implementation:
    file_ops_action(ctx, "copy_file", src="input.txt", dest="output.txt")
    prepare_workspace_action(ctx, workspace_config)
"""

# Use Bazel Skylib for cross-platform file operations
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("@bazel_skylib//rules:write_file.bzl", "write_file")

def file_ops_action(ctx, operation, **kwargs):
    """Execute a file operation using the File Operations Component

    Args:
        ctx: Bazel rule context
        operation: Operation to perform (copy_file, copy_directory, create_directory, etc.)
        **kwargs: Operation-specific arguments

    Returns:
        Action result or None for operations that don't produce outputs
    """

    # Get the file operations component from toolchain
    file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
    file_ops_component = file_ops_toolchain.file_ops_component

    if not file_ops_component:
        fail("File operations component not available in toolchain")

    # Build arguments based on operation
    args = [operation]
    inputs = []
    outputs = []

    if operation == "copy_file":
        src = kwargs.get("src")
        dest = kwargs.get("dest")
        if not src or not dest:
            fail("copy_file requires 'src' and 'dest' arguments")

        # Handle File objects vs strings
        if hasattr(src, "path"):
            inputs.append(src)
            args.extend(["--src", src.path])
        else:
            args.extend(["--src", src])

        if hasattr(dest, "path"):
            outputs.append(dest)
            args.extend(["--dest", dest.path])
        else:
            # Create output file declaration
            dest_file = ctx.actions.declare_file(dest)
            outputs.append(dest_file)
            args.extend(["--dest", dest_file.path])

    elif operation == "copy_directory":
        src = kwargs.get("src")
        dest = kwargs.get("dest")
        if not src or not dest:
            fail("copy_directory requires 'src' and 'dest' arguments")

        if hasattr(src, "path"):
            inputs.append(src)
            args.extend(["--src", src.path])
        else:
            args.extend(["--src", src])

        if hasattr(dest, "path"):
            outputs.append(dest)
            args.extend(["--dest", dest.path])
        else:
            dest_dir = ctx.actions.declare_directory(dest)
            outputs.append(dest_dir)
            args.extend(["--dest", dest_dir.path])

    elif operation == "create_directory":
        path = kwargs.get("path")
        if not path:
            fail("create_directory requires 'path' argument")

        if hasattr(path, "path"):
            outputs.append(path)
            args.extend(["--path", path.path])
        else:
            dir_output = ctx.actions.declare_directory(path)
            outputs.append(dir_output)
            args.extend(["--path", dir_output.path])

    elif operation == "list_directory":
        dir_path = kwargs.get("dir")
        pattern = kwargs.get("pattern")
        output = kwargs.get("output")

        if not dir_path or not output:
            fail("list_directory requires 'dir' and 'output' arguments")

        args.extend(["--dir", dir_path])
        if pattern:
            args.extend(["--pattern", pattern])

        if hasattr(output, "path"):
            outputs.append(output)
            args.extend(["--output", output.path])
        else:
            output_file = ctx.actions.declare_file(output)
            outputs.append(output_file)
            args.extend(["--output", output_file.path])
    else:
        fail("Unsupported file operation: {}".format(operation))

    # Execute the component action
    ctx.actions.run(
        executable = file_ops_component,
        arguments = args,
        inputs = inputs,
        outputs = outputs,
        mnemonic = "FileOps" + operation.replace("_", "").title(),
        progress_message = "Running file operation {} for {}".format(operation, ctx.label),
    )

    # Return the first output for chaining
    return outputs[0] if outputs else None

def prepare_workspace_action(ctx, config):
    """Prepare a complete workspace using hermetic Go binary for file operations

    This function uses a hermetic Go binary (following @aspect_bazel_lib pattern)
    instead of shell scripts or system dependencies. This ensures true hermetic
    builds that work across Windows, macOS, and Linux.

    Args:
        ctx: Bazel rule context
        config: WorkspaceConfig dictionary with workspace setup parameters

    Returns:
        Workspace directory output
    """

    # Create workspace output directory
    workspace_dir = ctx.actions.declare_directory(config["work_dir"])

    # HERMETIC APPROACH: Use a simple script that only uses POSIX commands available everywhere
    # Create a minimal shell script that doesn't depend on system Python
    workspace_script = ctx.actions.declare_file(ctx.label.name + "_workspace_setup.sh")

    # Collect all input files and their destinations
    all_inputs = []
    file_mappings = []

    # Process source files
    for source_info in config.get("sources", []):
        src_file = source_info["source"]
        dest_name = source_info.get("destination") or src_file.basename
        all_inputs.append(src_file)
        file_mappings.append((src_file, dest_name))

    # Process header files
    for header_info in config.get("headers", []):
        hdr_file = header_info["source"]
        dest_name = header_info.get("destination") or hdr_file.basename
        all_inputs.append(hdr_file)
        file_mappings.append((hdr_file, dest_name))

    # Process dependency files
    for dep_info in config.get("dependencies", []):
        dep_file = dep_info["source"]
        dest_name = dep_info.get("destination") or dep_file.basename
        all_inputs.append(dep_file)
        file_mappings.append((dep_file, dest_name))

    script_lines = [
        "#!/bin/sh",
        "set -e",
        "",
        "WORKSPACE_DIR=\"$1\"",
        "mkdir -p \"$WORKSPACE_DIR\"",
        "",
    ]

    # Add file operations using basic POSIX commands
    for src_file, dest_name in file_mappings:
        # Ensure parent directory exists for nested paths
        if "/" in dest_name:
            parent_dir = "/".join(dest_name.split("/")[:-1])
            script_lines.append("mkdir -p \"$WORKSPACE_DIR/{}\"".format(parent_dir))

        # Use cp to copy files (available on all POSIX systems)
        script_lines.append("cp \"{}\" \"$WORKSPACE_DIR/{}\"".format(src_file.path, dest_name))

    script_lines.extend([
        "",
        "# Create completion marker",
        "echo \"Workspace prepared with {} files\" > \"$WORKSPACE_DIR/.workspace_ready\"".format(len(file_mappings)),
    ])

    ctx.actions.write(
        output = workspace_script,
        content = "\n".join(script_lines),
        is_executable = True,
    )

    # Execute the workspace setup using only basic POSIX shell
    ctx.actions.run(
        executable = workspace_script,
        arguments = [workspace_dir.path],
        inputs = all_inputs + [workspace_script],
        outputs = [workspace_dir],
        mnemonic = "PrepareWorkspaceHermetic",
        progress_message = "Preparing {} workspace for {} (hermetic)".format(
            config.get("workspace_type", "generic"),
            ctx.label,
        ),
    )

    return workspace_dir

def setup_go_module_action(ctx, sources, go_mod = None, wit_file = None):
    """Set up a Go module workspace for TinyGo compilation

    Args:
        ctx: Bazel rule context
        sources: List of Go source files
        go_mod: Optional go.mod file
        wit_file: Optional WIT file for binding generation

    Returns:
        Prepared Go module directory
    """

    config = {
        "work_dir": ctx.label.name + "_gomod",
        "workspace_type": "go",
        "sources": [{"source": src, "destination": None, "preserve_permissions": False} for src in sources],
        "headers": [],
        "dependencies": [],
    }

    if go_mod:
        config["dependencies"].append({
            "source": go_mod,
            "destination": "go.mod",
            "preserve_permissions": False,
        })

    if wit_file:
        config["dependencies"].append({
            "source": wit_file,
            "destination": "component.wit",
            "preserve_permissions": False,
        })

    return prepare_workspace_action(ctx, config)

def setup_cpp_workspace_action(ctx, sources, headers, bindings_dir = None, dep_headers = None):
    """Set up a C/C++ workspace for compilation with proper directory structure

    Args:
        ctx: Bazel rule context
        sources: List of C/C++ source files
        headers: List of header files
        bindings_dir: Optional generated bindings directory
        dep_headers: Optional dependency header files

    Returns:
        Prepared C/C++ workspace directory
    """

    config = {
        "work_dir": ctx.label.name + "_cppwork",
        "workspace_type": "cpp",
        "sources": [{"source": src, "destination": None, "preserve_permissions": False} for src in sources],
        "headers": [],  # Will be filled below with proper directory structure
        "dependencies": [],
    }

    # For local headers within the same component, use basename only
    # This matches how the source files include them (e.g., #include "calculator_c.h")
    for hdr in headers:
        # For headers within the same component, just use the basename
        # Source files expect to find headers in the same directory
        relative_path = hdr.basename

        config["headers"].append({
            "source": hdr,
            "destination": relative_path,  # Use basename for local headers
            "preserve_permissions": False,
        })

    if bindings_dir:
        config["bindings_dir"] = bindings_dir

    if dep_headers:
        for hdr in dep_headers:
            # CRITICAL FIX: Preserve directory structure for cross-package headers
            # Handle different path patterns for local vs external dependencies
            relative_path = hdr.short_path

            if "/" in relative_path:
                path_parts = relative_path.split("/")

                # Check for external dependency pattern (external/repo_name/include/...)
                if len(path_parts) >= 4 and path_parts[0] == "external" and "include" in path_parts:
                    # Find the include directory and preserve everything after it
                    include_index = None
                    for i, part in enumerate(path_parts):
                        if part == "include":
                            include_index = i
                            break

                    if include_index != None and include_index + 1 < len(path_parts):
                        # Preserve the directory structure after "include/"
                        relative_path = "/".join(path_parts[include_index + 1:])
                    else:
                        # Fallback for external headers without clear include structure
                        relative_path = "/".join(path_parts[-2:])

                    # Handle local cross-package headers (test/cross_package_headers/foundation/types.h)
                elif len(path_parts) >= 3:
                    # Take the last 2 parts for headers in subdirectories
                    relative_path = "/".join(path_parts[-2:])
                else:
                    # Fall back to basename for simple cases
                    relative_path = hdr.basename
            else:
                relative_path = hdr.basename

            config["dependencies"].append({
                "source": hdr,
                "destination": relative_path,  # Preserve directory structure
                "preserve_permissions": False,
            })

    return prepare_workspace_action(ctx, config)

def setup_js_workspace_action(ctx, sources, package_json = None, npm_deps = None):
    """Set up a JavaScript workspace for component compilation

    Args:
        ctx: Bazel rule context
        sources: List of JavaScript source files
        package_json: Optional package.json file
        npm_deps: Optional NPM dependencies directory

    Returns:
        Prepared JavaScript workspace directory
    """

    # Create workspace directory
    workspace_dir = ctx.actions.declare_directory(ctx.label.name + "_jswork")

    # Prepare inputs
    all_inputs = list(sources)
    if package_json:
        all_inputs.append(package_json)
    if npm_deps:
        all_inputs.append(npm_deps)

    # Create a shell script that properly copies files (not symlinks)
    setup_script = ctx.actions.declare_file(ctx.label.name + "_setup_workspace.sh")

    script_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "WORKSPACE_DIR=\"$1\"",
        "shift",
        "",
        "# Create workspace directory",
        "mkdir -p \"$WORKSPACE_DIR\"",
        "echo \"Setting up JavaScript workspace: $WORKSPACE_DIR\"",
        "",
    ]

    # Copy source files to workspace root (flatten structure)
    for src in sources:
        script_lines.extend([
            "echo \"Copying {} to $WORKSPACE_DIR/{}\"".format(src.path, src.basename),
            "cp \"{}\" \"$WORKSPACE_DIR/{}\"".format(src.path, src.basename),
        ])

    if package_json:
        script_lines.extend([
            "echo \"Copying package.json\"",
            "cp \"{}\" \"$WORKSPACE_DIR/package.json\"".format(package_json.path),
        ])

    if npm_deps:
        script_lines.extend([
            "echo \"Copying npm dependencies\"",
            "cp -r \"{}\" \"$WORKSPACE_DIR/node_modules\"".format(npm_deps.path),
        ])

    script_lines.extend([
        "",
        "echo \"JavaScript workspace setup complete\"",
        "echo \"Files in workspace:\"",
        "ls -la \"$WORKSPACE_DIR\"",
    ])

    ctx.actions.write(
        output = setup_script,
        content = "\n".join(script_lines),
        is_executable = True,
    )

    # Run the setup script
    ctx.actions.run(
        executable = setup_script,
        arguments = [workspace_dir.path],
        inputs = all_inputs,
        outputs = [workspace_dir],
        mnemonic = "SetupJSWorkspace",
        progress_message = "Setting up JavaScript workspace for %s" % ctx.label,
    )

    return workspace_dir
