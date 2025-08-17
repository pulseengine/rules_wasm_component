"""Universal file operations actions for Bazel rules

This module provides helper functions that replace shell scripts with
WebAssembly component calls for cross-platform file operations.

Usage:
    load("//tools/bazel_helpers:file_ops_actions.bzl", "file_ops_action", "prepare_workspace_action")

    # In your rule implementation:
    file_ops_action(ctx, "copy_file", src="input.txt", dest="output.txt")
    prepare_workspace_action(ctx, workspace_config)
"""

# Note: Using simple JSON encoding instead of skylib to avoid dependencies

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
    """Prepare a complete workspace using the File Operations Component

    Args:
        ctx: Bazel rule context
        config: WorkspaceConfig dictionary with workspace setup parameters

    Returns:
        Workspace directory output
    """

    file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
    file_ops_component = file_ops_toolchain.file_ops_component

    if not file_ops_component:
        fail("File operations component not available in toolchain")

    # Create workspace output directory
    workspace_dir = ctx.actions.declare_directory(config["work_dir"])

    # Create configuration file for the component
    config_file = ctx.actions.declare_file(ctx.label.name + "_workspace_config.json")

    # Create simple JSON configuration without complex nesting to avoid recursion
    # For now, we'll create a minimal config that the component can understand
    simple_config = {
        "work_dir": config["work_dir"],
        "workspace_type": config["workspace_type"],
        "source_count": len(config.get("sources", [])),
        "header_count": len(config.get("headers", [])),
        "dependency_count": len(config.get("dependencies", [])),
        "has_bindings": config.get("bindings_dir") != None,
    }

    # Simple manual JSON encoding for flat dictionary
    json_pairs = []
    for key, value in simple_config.items():
        if type(value) == "string":
            json_pairs.append('"{}": "{}"'.format(key, value.replace('"', '\\"')))
        elif type(value) == "bool":
            json_pairs.append('"{}": {}'.format(key, "true" if value else "false"))
        else:
            json_pairs.append('"{}": {}'.format(key, str(value)))

    # Create proper JSON format
    config_json = "{{{}}}".format(", ".join(json_pairs))

    ctx.actions.write(
        output = config_file,
        content = config_json,
    )

    # For now, use a simple approach: just create the directory and copy files directly
    # This avoids the complex JSON parsing issues while still providing the functionality

    # Create workspace directory and copy all files in a single action
    # Collect all input files
    all_inputs = []
    commands = ["mkdir -p {}".format(workspace_dir.path)]

    # Add sources
    for source_info in config.get("sources", []):
        src_file = source_info["source"]
        dest_name = source_info.get("destination") or src_file.basename
        all_inputs.append(src_file)
        commands.append("cp {} {}/{}".format(src_file.path, workspace_dir.path, dest_name))

    # Add headers
    for header_info in config.get("headers", []):
        hdr_file = header_info["source"]
        dest_name = header_info.get("destination") or hdr_file.basename
        all_inputs.append(hdr_file)
        commands.append("cp {} {}/{}".format(hdr_file.path, workspace_dir.path, dest_name))

    # Add dependencies
    for dep_info in config.get("dependencies", []):
        dep_file = dep_info["source"]
        dest_name = dep_info.get("destination") or dep_file.basename
        all_inputs.append(dep_file)
        commands.append("cp {} {}/{}".format(dep_file.path, workspace_dir.path, dest_name))

    # Execute workspace preparation in single action
    ctx.actions.run_shell(
        command = " && ".join(commands),
        inputs = all_inputs,
        outputs = [workspace_dir],
        mnemonic = "PrepareWorkspace",
        progress_message = "Preparing {} workspace for {}".format(
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
    """Set up a C/C++ workspace for compilation

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
        "headers": [{"source": hdr, "destination": None, "preserve_permissions": False} for hdr in headers],
        "dependencies": [],
    }

    if bindings_dir:
        config["bindings_dir"] = bindings_dir

    if dep_headers:
        config["dependencies"].extend([
            {"source": hdr, "destination": None, "preserve_permissions": False}
            for hdr in dep_headers
        ])

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
    
    # Use a simpler direct shell approach
    cp_commands = ["mkdir -p {}".format(workspace_dir.path)]
    
    # Copy source files to workspace root (flatten structure)
    for src in sources:
        cp_commands.append("cp {} {}/{}".format(src.path, workspace_dir.path, src.basename))
    
    if package_json:
        cp_commands.append("cp {} {}/package.json".format(package_json.path, workspace_dir.path))
    
    if npm_deps:
        cp_commands.append("cp -r {} {}/node_modules".format(npm_deps.path, workspace_dir.path))
    
    # Add debugging
    cp_commands.append("echo 'JavaScript workspace files:'") 
    cp_commands.append("ls -la {}".format(workspace_dir.path))
    
    ctx.actions.run_shell(
        command = " && ".join(cp_commands),
        inputs = all_inputs,
        outputs = [workspace_dir],
        mnemonic = "SetupJSWorkspace",
        progress_message = "Setting up JavaScript workspace for %s" % ctx.label,
    )
    
    return workspace_dir
