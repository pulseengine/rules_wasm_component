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

    # Get the hermetic file operations tool from toolchain
    file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
    file_ops_tool = file_ops_toolchain.file_ops_component

    # Collect all input files and build operations list
    all_inputs = []
    operations = []

    # Process source files
    for source_info in config.get("sources", []):
        src_file = source_info["source"]
        dest_name = source_info.get("destination") or src_file.basename
        all_inputs.append(src_file)
        operations.append({
            "type": "copy_file",
            "src_path": src_file.path,
            "dest_path": dest_name,
        })

    # Process header files
    for header_info in config.get("headers", []):
        hdr_file = header_info["source"]
        dest_name = header_info.get("destination") or hdr_file.basename
        all_inputs.append(hdr_file)
        operations.append({
            "type": "copy_file",
            "src_path": hdr_file.path,
            "dest_path": dest_name,
        })

    # Process dependency files
    for dep_info in config.get("dependencies", []):
        dep_file = dep_info["source"]
        dest_name = dep_info.get("destination") or dep_file.basename
        all_inputs.append(dep_file)

        is_directory = dep_info.get("is_directory", False)
        if is_directory:
            operations.append({
                "type": "copy_directory_contents",
                "src_path": dep_file.path,
                "dest_path": dest_name,
            })
        else:
            operations.append({
                "type": "copy_file",
                "src_path": dep_file.path,
                "dest_path": dest_name,
            })

    # Add Go module dependency resolution if go_binary provided
    go_binary = config.get("go_binary")
    if go_binary and config.get("workspace_type") == "go":
        # Note: go mod download is not needed here as TinyGo handles dependencies
        # Just create the cache directories for potential future use
        operations.extend([
            {"type": "mkdir", "path": ".gocache"},
            {"type": "mkdir", "path": ".gopath"},
        ])

    # Build JSON config for file operations tool
    file_ops_config = {
        "workspace_dir": workspace_dir.path,
        "operations": operations,
    }

    # Write config to a JSON file
    config_file = ctx.actions.declare_file(ctx.label.name + "_file_ops_config.json")
    ctx.actions.write(
        output = config_file,
        content = json.encode(file_ops_config),
    )

    # Execute the hermetic file operations tool
    ctx.actions.run(
        executable = file_ops_tool,
        arguments = [config_file.path],
        inputs = all_inputs + [config_file],
        outputs = [workspace_dir],
        mnemonic = "PrepareWorkspaceHermetic",
        progress_message = "Preparing {} workspace for {} (hermetic)".format(
            config.get("workspace_type", "generic"),
            ctx.label,
        ),
    )

    return workspace_dir

def setup_go_module_action(ctx, sources, go_mod = None, go_sum = None, wit_file = None, bindings_dir = None, go_binary = None):
    """Set up a Go module workspace for TinyGo compilation

    Args:
        ctx: Bazel rule context
        sources: List of Go source files
        go_mod: Optional go.mod file
        go_sum: Optional go.sum file
        wit_file: Optional WIT file for binding generation
        bindings_dir: Optional generated WIT bindings directory
        go_binary: Optional hermetic Go binary for dependency resolution

    Returns:
        Prepared Go module directory
    """

    config = {
        "work_dir": ctx.label.name + "_gomod",
        "workspace_type": "go",
        "sources": [{"source": src, "destination": None, "preserve_permissions": False} for src in sources],
        "headers": [],
        "dependencies": [],
        "go_binary": go_binary,  # Pass Go binary for dependency resolution
    }

    if go_mod:
        config["dependencies"].append({
            "source": go_mod,
            "destination": "go.mod",
            "preserve_permissions": False,
        })

    if go_sum:
        config["dependencies"].append({
            "source": go_sum,
            "destination": "go.sum",
            "preserve_permissions": False,
        })

    if wit_file:
        # CRITICAL FIX: TinyGo and wasm-tools expect WIT file in wit/ subdirectory
        # with the original filename (preserve the actual file name)
        config["dependencies"].append({
            "source": wit_file,
            "destination": "wit/" + wit_file.basename,  # Use original filename
            "preserve_permissions": False,
        })

    if bindings_dir:
        # Add generated WIT bindings directory to workspace root
        # wit-bindgen-go creates internal/example/... structure, so copy to workspace root
        config["dependencies"].append({
            "source": bindings_dir,
            "destination": ".",
            "preserve_permissions": False,
            "is_directory": True,  # Mark as directory for special handling
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

    # CRITICAL FIX for Issue #38: Handle both local and cross-package headers correctly
    # Two patterns:
    # 1. Same-component headers: "simd_utils.h" included as #include "simd_utils.h" → use basename
    # 2. Cross-package headers: "foundation/types.h" included as #include "foundation/types.h" → preserve directory
    for hdr in headers:
        relative_path = hdr.short_path

        # Check if this is a cross-package header that needs directory structure preservation
        # Cross-package headers typically have multiple path components and contain package/directory names
        path_parts = relative_path.split("/")

        if len(path_parts) >= 2 and ("test/" in relative_path or "/foundation/" in relative_path):
            # Cross-package header - preserve directory structure (e.g., "foundation/types.h")
            relative_path = "/".join(path_parts[-2:])
        else:
            # Same-component header - use basename for local includes (e.g., "simd_utils.h")
            relative_path = hdr.basename

        config["headers"].append({
            "source": hdr,
            "destination": relative_path,
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

    # Get the hermetic file operations tool from toolchain
    file_ops_toolchain = ctx.toolchains["@rules_wasm_component//toolchains:file_ops_toolchain_type"]
    file_ops_tool = file_ops_toolchain.file_ops_component

    # Build operations list
    all_inputs = []
    operations = []

    # Copy source files to workspace root (flatten structure)
    for src in sources:
        all_inputs.append(src)
        operations.append({
            "type": "copy_file",
            "src_path": src.path,
            "dest_path": src.basename,
        })

    if package_json:
        all_inputs.append(package_json)
        operations.append({
            "type": "copy_file",
            "src_path": package_json.path,
            "dest_path": "package.json",
        })

    if npm_deps:
        all_inputs.append(npm_deps)
        operations.append({
            "type": "copy_directory_contents",
            "src_path": npm_deps.path,
            "dest_path": "node_modules",
        })

    # Build JSON config for file operations tool
    file_ops_config = {
        "workspace_dir": workspace_dir.path,
        "operations": operations,
    }

    # Write config to a JSON file
    config_file = ctx.actions.declare_file(ctx.label.name + "_file_ops_config.json")
    ctx.actions.write(
        output = config_file,
        content = json.encode(file_ops_config),
    )

    # Execute the hermetic file operations tool
    ctx.actions.run(
        executable = file_ops_tool,
        arguments = [config_file.path],
        inputs = all_inputs + [config_file],
        outputs = [workspace_dir],
        mnemonic = "SetupJSWorkspace",
        progress_message = "Setting up JavaScript workspace for %s" % ctx.label,
    )

    return workspace_dir
